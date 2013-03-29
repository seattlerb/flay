#!/usr/bin/env ruby -w

require 'optparse'
require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'
require 'timeout'

class File
  RUBY19 = "<3".respond_to? :encoding unless defined? RUBY19

  class << self
    alias :binread :read unless RUBY19
  end
end

class Flay
  VERSION = '2.1.0'

  def self.default_options
    {
      :diff    => false,
      :mass    => 16,
      :summary => false,
      :verbose => false,
      :number  => true,
      :timeout => 10,
      :liberal => false,
      :fuzzy   => false,
    }
  end

  def self.parse_options args = ARGV
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

      opts.on('-f', '--fuzzy [DIFF]', Integer,
              "Detect fuzzy (copy & paste) duplication (default 1).") do |n|
        options[:fuzzy] = n || 1
      end

      opts.on('-l', '--liberal', "Use a more liberal detection method.") do
        options[:liberal] = true
      end

      opts.on('-m', '--mass MASS', Integer,
              "Sets mass threshold (default = #{options[:mass]})") do |m|
        options[:mass] = m.to_i
      end

      opts.on('-#', "Don't number output (helps with diffs)") do |m|
        options[:number] = false
      end

      opts.on('-v', '--verbose', "Verbose. Show progress processing files.") do
        options[:verbose] = true
      end

      opts.on('-d', '--diff', "Diff Mode. Display N-Way diff for ruby.") do
        options[:diff] = true
      end

      opts.on('-s', '--summary', "Summarize. Show flay score per file only.") do
        options[:summary] = true
      end

      opts.on('-t', '--timeout TIME', Integer,
              "Set the timeout. (default = #{options[:timeout]})") do |t|
        options[:timeout] = t.to_i
      end

      extensions = ['rb'] + Flay.load_plugins

      opts.separator ""
      opts.separator "Known extensions: #{extensions.join(', ')}"

      extensions.each do |meth|
        msg = "options_#{meth}"
        send msg, opts, options if self.respond_to?(msg)
      end

      begin
        opts.parse! args
      rescue => e
        abort "#{e}\n\n#{opts}"
      end
    end

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
      @@plugins = []

      plugins = Gem.find_files("flay_*.rb").reject { |p| p =~ /flay_task/ }

      plugins.each do |plugin|
        plugin_name = File.basename(plugin, '.rb').sub(/^flay_/, '')
        next if @@plugins.include? plugin_name
        begin
          load plugin
          @@plugins << plugin_name
        rescue LoadError => e
          warn "error loading #{plugin.inspect}: #{e.message}. skipping..."
        end
      end
    end
    @@plugins
  rescue
    # ignore
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

    require 'ruby2ruby' if @option[:diff]
  end

  def process(*files) # TODO: rename from process - should act as SexpProcessor
    files.each do |file|
      warn "Processing #{file}" if option[:verbose]

      ext = File.extname(file).sub(/^\./, '')
      ext = "rb" if ext.nil? || ext.empty?
      msg = "process_#{ext}"

      unless respond_to? msg then
        warn "  Unknown file type: #{ext}, defaulting to ruby"
        msg = "process_rb"
      end

      begin
        sexp = begin
                 send msg, file
               rescue => e
                 warn "  #{e.message.strip}"
                 warn "  skipping #{file}"
                 nil
               end

        next unless sexp

        process_sexp sexp
      rescue SyntaxError => e
        warn "  skipping #{file}: #{e.message}"
      end
    end
  end

  def analyze
    self.prune

    self.hashes.each do |hash,nodes|
      identical[hash] = nodes[1..-1].all? { |n| n == nodes.first }
    end

    update_masses
  end

  def update_masses
    self.total = 0
    masses.clear
    self.hashes.each do |hash, nodes|
      masses[hash] = nodes.first.mass * nodes.size
      masses[hash] *= (nodes.size) if identical[hash]
      self.total += masses[hash]
    end
  end

  def process_rb file
    begin
      RubyParser.new.process(File.binread(file), file, option[:timeout])
    rescue Timeout::Error
      warn "TIMEOUT parsing #{file}. Skipping."
    end
  end

  def process_sexp pt
    pt.deep_each do |node|
      next unless node.any? { |sub| Sexp === sub }
      next if node.mass < self.mass_threshold

      self.hashes[node.structural_hash] << node

      process_fuzzy node, option[:fuzzy] if option[:fuzzy]
    end
  end

  MAX_NODE_SIZE = 10 # prevents exponential blowout
  MAX_AVG_MASS  = 12 # prevents exponential blowout

  def process_fuzzy node, difference
    return unless node.has_code?

    avg_mass = node.mass / node.size
    return if node.size > MAX_NODE_SIZE or avg_mass > MAX_AVG_MASS

    tmpl, code = node.split_code
    tmpl.modified = true

    (code.size - 1).downto(code.size - difference) do |n|
      code.combination(n).each do |subcode|
        new_node = tmpl + subcode

        next unless new_node.any? { |sub| Sexp === sub }
        next if new_node.mass < self.mass_threshold

        # they're already structurally similar, don't bother adding another
        next if self.hashes[new_node.structural_hash].any? { |sub|
          sub.file == new_node.file and sub.line == new_node.line
        }

        self.hashes[new_node.structural_hash] << new_node
      end
    end
  end

  def prune
    # prune trees that aren't duped at all, or are too small
    self.hashes.delete_if { |_,nodes| nodes.size == 1 }
    self.hashes.delete_if { |_,nodes| nodes.all?(&:modified?) }

    return prune_liberally if option[:liberal]

    prune_conservatively
  end

  def prune_conservatively
    all_hashes = {}

    # extract all subtree hashes from all nodes
    self.hashes.values.each do |nodes|
      nodes.first.all_structural_subhashes.each do |h|
        all_hashes[h] = true
      end
    end

    # nuke subtrees so we show the biggest matching tree possible
    self.hashes.delete_if { |h,_| all_hashes[h] }
  end

  def prune_liberally
    update_masses

    all_hashes = Hash.new { |h,k| h[k] = [] }

    # record each subtree by subhash, but skip if subtree mass > parent mass
    self.hashes.values.each do |nodes|
      nodes.each do |node|
        tophash  = node.structural_hash
        topscore = self.masses[tophash]

        node.deep_each do |subnode|
          subhash  = subnode.structural_hash
          subscore = self.masses[subhash]

          next if subscore and subscore > topscore

          all_hashes[subhash] << subnode
        end
      end
    end

    # nuke only individual items by object identity
    self.hashes.each do |h,v|
      v.delete_eql all_hashes[h]
    end

    # nuke buckets we happened to fully empty
    self.hashes.delete_if { |k,v| v.size <= 1 }
  end

  def n_way_diff *data
    data.each_with_index do |s, i|
      c = (?A.ord + i).chr
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

  def summary
    score = Hash.new 0

    masses.each do |hash, mass|
      sexps = hashes[hash]
      mass_per_file = mass.to_f / sexps.size
      sexps.each do |sexp|
        score[sexp.file] += mass_per_file
      end
    end

    score
  end

  def report prune = nil
    analyze

    puts "Total score (lower is better) = #{self.total}"

    if option[:summary] then
      puts

      self.summary.sort_by { |_,v| -v }.each do |file, score|
        puts "%8.2f: %s" % [score, file]
      end

      return
    end

    count = 0
    sorted = masses.sort_by { |h,m|
      [-m,
       hashes[h].first.file,
       hashes[h].first.line,
       hashes[h].first.first.to_s]
    }
    sorted.each do |hash, mass|
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

      if option[:number] then
        count += 1

        puts "%d) %s code found in %p (mass%s = %d)" %
         [count, match, node.first, bonus, mass]
      else
        puts "%s code found in %p (mass%s = %d)" %
         [match, node.first, bonus, mass]
      end

      nodes.sort_by { |x| [x.file, x.line] }.each_with_index do |x, i|
        if option[:diff] then
          c = (?A.ord + i).chr
          puts "  #{c}: #{x.file}:#{x.line}"
        else
          extra = " (FUZZY)" if x.modified?
          puts "  #{x.file}:#{x.line}#{extra}"
        end
      end

      if option[:diff] then
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
  attr_accessor :modified
  alias :modified? :modified

  def structural_hash
    @structural_hash ||= self.structure.hash
  end

  def all_structural_subhashes
    hashes = []
    self.deep_each do |node|
      hashes << node.structural_hash
    end
    hashes
  end

  def initialize_copy o
    s = super
    s.file = o.file
    s.line = o.line
    s.modified = o.modified
    s
  end

  def [] a
    s = super
    if Sexp === s then
      s.file = self.file
      s.line = self.line
      s.modified = self.modified
    end
    s
  end

  def + o
    self.dup.concat o
  end

  def split_at n
    return self[0..n], self[n+1..-1]
  end

  def code_index
    {
     :block  => 0,    # s(:block,                   *code)
     :class  => 2,    # s(:class,      name, super, *code)
     :module => 1,    # s(:module,     name,        *code)
     :defn   => 2,    # s(:defn,       name, args,  *code)
     :defs   => 3,    # s(:defs, recv, name, args,  *code)
     :iter   => 2,    # s(:iter, recv,       args,  *code)
    }[self.sexp_type]
  end

  alias has_code? code_index

  def split_code
    index = self.code_index
    self.split_at index if index
  end
end

class Array
  def delete_eql other
    self.delete_if { |o1| other.any? { |o2| o1.equal? o2 } }
  end
end
