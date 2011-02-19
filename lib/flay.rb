#!/usr/bin/env ruby -w

$: << "../../ruby_parser/dev/lib"
$: << "../../ruby2ruby/dev/lib"

require 'optparse'
require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'

class Flay
  VERSION = '1.4.2'

  def self.default_options
    {
      :diff    => false,
      :mass    => 16,
      :summary => false,
      :verbose => false,
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

      opts.on('-f', '--fuzzy', "DEAD: fuzzy similarities.") do
        abort "--fuzzy is no longer supported. Sorry. It sucked."
      end

      opts.on('-m', '--mass MASS', Integer, "Sets mass threshold") do |m|
        options[:mass] = m.to_i
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

      extensions = ['rb'] + Flay.load_plugins

      opts.separator ""
      opts.separator "Known extensions: #{extensions.join(', ')}"

      begin
        opts.parse!
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

      self.hashes[node.structural_hash] << node
    end
  end

  def prune
    # prune trees that aren't duped at all, or are too small
    self.hashes.delete_if { |_,nodes| nodes.size == 1 }

    # extract all subtree hashes from all nodes
    all_hashes = {}
    self.hashes.values.each do |nodes|
      nodes.each do |node|
        node.all_structural_subhashes.each do |h|
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
    puts "Total score (lower is better) = #{self.total}"
    puts

    if option[:summary] then

      self.summary.sort_by { |_,v| -v }.each do |file, score|
        puts "%8.2f: %s" % [score, file]
      end

      return
    end

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

      nodes.each_with_index do |x, i|
        if option[:diff] then
          c = (?A + i).chr
          puts "  #{c}: #{x.file}:#{x.line}"
        else
          puts "  #{x.file}:#{x.line}"
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

  # REFACTOR: move to sexp.rb
  def deep_each(&block)
    self.each_sexp do |sexp|
      block[sexp]
      sexp.deep_each(&block)
    end
  end

  # REFACTOR: move to sexp.rb
  def each_sexp
    self.each do |sexp|
      next unless Sexp === sexp

      yield sexp
    end
  end
end
