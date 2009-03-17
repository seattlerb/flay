#!/usr/bin/env ruby -w

$: << "../../ruby_parser/dev/lib"
$: << "../../ruby2ruby/dev/lib"

require 'optparse'
require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'

abort "update rubygems to >= 1.3.1" unless  Gem.respond_to? :find_files

class Flay
  VERSION = '1.2.1'

  def self.default_options
    {
      :fuzzy   => false,
      :verbose => false,
      :mass    => 16,
    }
  end

  def self.parse_options
    options = self.default_options

    OptionParser.new do |opts|
      opts.banner  = 'flay [options] files_or_dirs'
      opts.version = Flay::VERSION

      opts.separator ""
      opts.separator "Specific options:"
      opts.separator ""

      opts.on('-h', '--help', 'Display this help.') do
        puts opts
        exit
      end

      opts.on('-f', '--fuzzy', "Attempt to do fuzzy similarities. (SLOW)") do
        options[:fuzzy] = true
      end

      opts.on('-m', '--mass MASS', Integer, "Sets mass threshold") do |m|
        options[:mass] = m.to_i
      end

      opts.on('-v', '--verbose', "Verbose. Display N-Way diff for ruby.") do
        options[:verbose] = true
      end

      extensions = ['rb'] + Flay.load_plugins

      opts.separator ""
      opts.separator "Known extensions: #{extensions.join(', ')}"
    end.parse!

    options
  end

  def self.expand_dirs_to_files *dirs
    extensions = ['rb'] + Flay.load_plugins

    dirs.flatten.map { |p|
      if File.directory? p then
        Dir[File.join(p, '**', "*.{#{extensions.join(',')}}")]
      else
        p
      end
    }.flatten
  end

  def self.load_plugins
    unless defined? @@plugins then
      plugins = Gem.find_files("flay_*.rb").reject { |p| p =~ /flay_task/ }

      plugins.each do |plugin|
        begin
          load plugin
        rescue LoadError => e
          warn "error loading #{plugin.inspect}: #{e.message}. skipping..."
        end
      end

      @@plugins = plugins.map { |f| File.basename(f, '.rb').sub(/^flay_/, '') }
    end
    @@plugins
  end

  attr_accessor :mass_threshold, :total, :identical, :masses
  attr_reader :hashes, :option

  def initialize option = nil
    @option = option || Flay.default_options
    @hashes = Hash.new { |h,k| h[k] = [] }

    self.identical      = {}
    self.masses         = {}
    self.total          = 0
    self.mass_threshold = @option[:mass]

    require 'ruby2ruby' if @option[:verbose]
  end

  def process(*files) # TODO: rename from process - should act as SexpProcessor
    files.each do |file|
      warn "Processing #{file}"

      ext = File.extname(file).sub(/^\./, '')
      ext = "rb" if ext.nil? || ext.empty?
      msg = "process_#{ext}"

      unless respond_to? msg then
        warn "  Unknown file type: #{ext}, defaulting to ruby"
        msg = "process_rb"
      end

      sexp = begin
               send msg, file
             rescue => e
               warn "  #{e.message.strip}"
               warn "  skipping #{file}"
               nil
             end

      next unless sexp

      process_sexp sexp
    end

    process_fuzzy_similarities if option[:fuzzy]

    analyze
  end

  def analyze
    self.prune

    self.hashes.each do |hash,nodes|
      identical[hash] = nodes[1..-1].all? { |n| n == nodes.first }
      masses[hash] = nodes.first.mass * nodes.size
      masses[hash] *= (nodes.size) if identical[hash]
      self.total += masses[hash]
    end
  end

  def process_rb file
    RubyParser.new.process(File.read(file), file)
  end

  def process_sexp pt
    pt.deep_each do |node|
      next unless node.any? { |sub| Sexp === sub }
      next if node.mass < self.mass_threshold

      self.hashes[node.fuzzy_hash] << node
    end
  end

  def process_fuzzy_similarities
    all_hashes, detected = {}, {}

    self.hashes.values.each do |nodes|
      nodes.each do |node|
        next if node.mass > 4 * self.mass_threshold
        # TODO: try out with fuzzy_hash
        # all_hashes[node] = node.grep(Sexp).map { |s| [s.hash] * s.mass }.flatten
        all_hashes[node] = node.grep(Sexp).map { |s| [s.hash] }.flatten
      end
    end

    # warn "looking for copy/paste/edit code across #{all_hashes.size} nodes"

    all_hashes = all_hashes.to_a
    all_hashes.each_with_index do |(s1, h1), i|
      similar = [s1]
      all_hashes[i+1..-1].each do |(s2, h2)|
        next if detected[h2]
        intersection = h1.intersection h2
        max = [h1.size, h2.size].max
        if intersection.size >= max * 0.60 then
          similarity = s1.similarity(s2)
          if similarity > 0.60 then
            similar << s2
            detected[h2] = true
          else
            p [similarity, s1, s2]
          end
        end
      end

      self.hashes[similar.first.hash].push(*similar) if similar.size > 1
    end
  end

  def prune
    # prune trees that aren't duped at all, or are too small
    self.hashes.delete_if { |_,nodes| nodes.size == 1 }

    # extract all subtree hashes from all nodes
    all_hashes = {}
    self.hashes.values.each do |nodes|
      nodes.each do |node|
        node.all_subhashes.each do |h|
          all_hashes[h] = true
        end
      end
    end

    # nuke subtrees so we show the biggest matching tree possible
    self.hashes.delete_if { |h,_| all_hashes[h] }
  end

  def n_way_diff *data
    data.each_with_index do |s, i|
      c = (?A + i).chr
      s.group = c
    end

    max = data.map { |s| s.scan(/^.*/).size }.max

    data.map! { |s| # FIX: this is tarded, but I'm out of brain
      c = s.group
      s = s.scan(/^.*/)
      s.push(*([""] * (max - s.size))) # pad
      s.each do |o|
        o.group = c
      end
      s
    }

    groups = data[0].zip(*data[1..-1])
    groups.map! { |lines|
      collapsed = lines.uniq
      if collapsed.size == 1 then
        "   #{lines.first}"
      else
        # TODO: make r2r have a canonical mode (doesn't make 1-liners)
        lines.reject { |l| l.empty? }.map { |l| "#{l.group}: #{l}" }
      end
    }
    groups.flatten.join("\n")
  end

  def report prune = nil
    puts "Total score (lower is better) = #{self.total}"
    puts

    count = 0
    masses.sort_by { |h,m| [-m, hashes[h].first.file] }.each do |hash, mass|
      nodes = hashes[hash]
      next unless nodes.first.first == prune if prune
      puts

      same = identical[hash]
      node = nodes.first
      n = nodes.size
      match, bonus = if same then
                       ["IDENTICAL", "*#{n}"]
                     else
                       ["Similar",   ""]
                     end

      count += 1
      puts "%d) %s code found in %p (mass%s = %d)" %
        [count, match, node.first, bonus, mass]

      nodes.each_with_index do |node, i|
        if option[:verbose] then
          c = (?A + i).chr
          puts "  #{c}: #{node.file}:#{node.line}"
        else
          puts "  #{node.file}:#{node.line}"
        end
      end

      if option[:verbose] then
        puts
        r2r = Ruby2Ruby.new
        puts n_way_diff(*nodes.map { |s| r2r.process(s.deep_clone) })
      end
    end
  end
end

class String
  attr_accessor :group
end

class Sexp
  def mass
    @mass ||= self.structure.flatten.size
  end

  alias :uncached_structure :structure
  def structure
    @structure ||= self.uncached_structure
  end

  def similarity o
    l, s, r = self.compare_to o
    (2.0 * s) / (2.0 * s + l + r)
  end

  def compare_to they
    l = s = r = 0

    l_sexp, l_lits = self.partition { |o| Sexp === o }
    r_sexp, r_lits = they.partition { |o| Sexp === o }

    l += (l_lits - r_lits).size
    s += (l_lits & r_lits).size
    r += (r_lits - l_lits).size

    # TODO: I think this is wrong, since it isn't positional. What to do?
    l_sexp.zip(r_sexp).each do |l_sub, r_sub|
      next unless l_sub && r_sub # HACK
      l2, s2, r2 = l_sub.compare_to r_sub
      l += l2
      s += s2
      r += r2
    end

    return l, s, r
  end

  def fuzzy_hash
    @fuzzy_hash ||= self.structure.hash
  end

  def all_subhashes
    hashes = []
    self.deep_each do |node|
      hashes << node.fuzzy_hash
    end
    hashes
  end

  def deep_each(&block)
    self.each_sexp do |sexp|
      block[sexp]
      sexp.deep_each(&block)
    end
  end

  def each_sexp
    self.each do |sexp|
      next unless Sexp === sexp

      yield sexp
    end
  end
end

class Array
  def intersection other
    intersection, start = [], 0
    other_size = other.length
    self.each_with_index do |m, i|
      (start...other_size).each do |j|
        n = other.at j
        if m == n then
          intersection << m
          start = j + 1
          break
        end
      end
    end
    intersection
  end

  def triangle # TODO: use?
    max = self.size
    (0...max).each do |i|
      o1 = at(i)
      (i+1...max).each do |j|
        o2 = at(j)
        yield o1, o2
      end
    end
  end
end
