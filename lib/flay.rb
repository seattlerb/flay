#!/usr/bin/env ruby -w

require "optparse"
require "rubygems"
require "sexp_processor"
require "ruby_parser"
require "path_expander"
require "timeout"

class File
  RUBY19 = "<3".respond_to? :encoding unless defined? RUBY19 # :nodoc:

  class << self
    alias :binread :read unless RUBY19
  end
end

class Flay
  VERSION = "2.10.0" # :nodoc:

  class Item < Struct.new(:structural_hash, :name, :bonus, :mass, :locations)
    alias identical? bonus
  end

  class Location < Struct.new(:file, :line, :fuzzy)
    alias fuzzy? fuzzy
  end

  def self.run args = ARGV
    extensions = ["rb"] + Flay.load_plugins
    glob = "**/*.{#{extensions.join ","}}"

    expander = PathExpander.new args, glob
    files = expander.filter_files expander.process, DEFAULT_IGNORE

    flay = Flay.new Flay.parse_options args
    flay.process(*files)
    flay
  end

  ##
  # Returns the default options.

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
      :only   => nil,
    }
  end

  ##
  # Process options in +args+, defaulting to +ARGV+.

  def self.parse_options args = ARGV
    options = self.default_options

    OptionParser.new do |opts|
      opts.banner  = "flay [options] files_or_dirs"
      opts.version = Flay::VERSION

      opts.separator ""
      opts.separator "Specific options:"
      opts.separator ""

      opts.on("-h", "--help", "Display this help.") do
        puts opts
        exit
      end

      opts.on("-f", "--fuzzy [DIFF]", Integer,
              "Detect fuzzy (copy & paste) duplication (default 1).") do |n|
        options[:fuzzy] = n || 1
      end

      opts.on("-l", "--liberal", "Use a more liberal detection method.") do
        options[:liberal] = true
      end

      opts.on("-m", "--mass MASS", Integer,
              "Sets mass threshold (default = #{options[:mass]})") do |m|
        options[:mass] = m.to_i
      end

      opts.on("-#", "Don't number output (helps with diffs)") do |m|
        options[:number] = false
      end

      opts.on("-v", "--verbose", "Verbose. Show progress processing files.") do
        options[:verbose] = true
      end

      opts.on("-o", "--only NODE", String, "Only show matches on NODE type.") do |s|
        options[:only] = s.to_sym
      end

      opts.on("-d", "--diff", "Diff Mode. Display N-Way diff for ruby.") do
        options[:diff] = true
      end

      opts.on("-s", "--summary", "Summarize. Show flay score per file only.") do
        options[:summary] = true
      end

      opts.on("-t", "--timeout TIME", Integer,
              "Set the timeout. (default = #{options[:timeout]})") do |t|
        options[:timeout] = t.to_i
      end

      extensions = ["rb"] + Flay.load_plugins

      opts.separator ""
      opts.separator "Known extensions: #{extensions.join(", ")}"

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

  # so I can move this to flog wholesale
  DEFAULT_IGNORE = ".flayignore" # :nodoc:

  ##
  # Loads all flay plugins. Files must be named "flay_*.rb".

  def self.load_plugins
    unless defined? @@plugins then
      @@plugins = []

      plugins = Gem.find_files("flay_*.rb").reject { |p| p =~ /flay_task/ }

      plugins.each do |plugin|
        plugin_name = File.basename(plugin, ".rb").sub(/^flay_/, "")
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

  # :stopdoc:
  attr_accessor :mass_threshold, :total, :identical, :masses
  attr_reader :hashes, :option
  # :startdoc:

  ##
  # Create a new instance of Flay with +option+s.

  def initialize option = nil
    @option = option || Flay.default_options
    @hashes = Hash.new { |h,k| h[k] = [] }

    self.identical      = {}
    self.masses         = {}
    self.total          = 0
    self.mass_threshold = @option[:mass]
  end

  ##
  # Process any number of files.

  def process(*files) # TODO: rename from process - should act as SexpProcessor
    files.each do |file|
      warn "Processing #{file}" if option[:verbose]

      ext = File.extname(file).sub(/^\./, "")
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

  ##
  # Prune, find identical nodes, and update masses.

  def analyze filter = nil
    self.prune

    self.hashes.each do |hash,nodes|
      identical[hash] = nodes[1..-1].all? { |n| n == nodes.first }
    end

    update_masses

    sorted = masses.sort_by { |h,m|
      [-m,
       hashes[h].first.file,
       hashes[h].first.line,
       hashes[h].first.first.to_s]
    }

    sorted.map { |hash, mass|
      nodes = hashes[hash]

      next unless nodes.first.first == filter if filter

      same  = identical[hash]
      node  = nodes.first
      n     = nodes.size
      bonus = "*#{n}" if same

      locs = nodes.sort_by { |x| [x.file, x.line] }.each_with_index.map { |x, i|
        extra = :fuzzy if x.modified?
        Location[x.file, x.line, extra]
      }

      Item[hash, node.first, bonus, mass, locs]
    }.compact
  end

  ##
  # Reset total and recalculate the masses for all nodes in +hashes+.

  def update_masses
    self.total = 0
    masses.clear
    self.hashes.each do |hash, nodes|
      masses[hash] = nodes.first.mass * nodes.size
      masses[hash] *= (nodes.size) if identical[hash]
      self.total += masses[hash]
    end
  end

  ##
  # Parse a ruby +file+ and return the sexp.
  #
  # --
  # TODO: change the system and rename this to parse_rb.

  def process_rb file
    begin
      RubyParser.new.process(File.binread(file), file, option[:timeout])
    rescue Timeout::Error
      warn "TIMEOUT parsing #{file}. Skipping."
    end
  end

  ##
  # Process a sexp +pt+.

  def process_sexp pt
    pt.deep_each do |node|
      next unless node.any? { |sub| Sexp === sub }
      next if node.mass < self.mass_threshold

      self.hashes[node.structural_hash] << node

      process_fuzzy node, option[:fuzzy] if option[:fuzzy]
    end
  end

  # :stopdoc:
  MAX_NODE_SIZE = 10 # prevents exponential blowout
  MAX_AVG_MASS  = 12 # prevents exponential blowout
  # :startdoc:

  ##
  # Process "fuzzy" matches for +node+. A fuzzy match is a subset of
  # +node+ up to +difference+ elements less than the original.

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

        # they're already structurally similar, don"t bother adding another
        next if self.hashes[new_node.structural_hash].any? { |sub|
          sub.file == new_node.file and sub.line == new_node.line
        }

        self.hashes[new_node.structural_hash] << new_node
      end
    end
  end

  ##
  # Given an array of sexp patterns (see sexp_processor), delete any
  # buckets whose members match any of the patterns.

  def filter *patterns
    return if patterns.empty?

    self.hashes.delete_if { |_, sexps|
      sexps.any? { |sexp|
        patterns.any? { |pattern|
          pattern =~ sexp
        }
      }
    }
  end

  ##
  # Prunes nodes that aren't relevant to analysis or are already
  # covered by another node. Also deletes nodes based on the
  # +:filters+ option.

  def prune
    # prune trees that aren't duped at all, or are too small
    self.hashes.delete_if { |_,nodes| nodes.size == 1 }
    self.hashes.delete_if { |_,nodes| nodes.all?(&:modified?) }

    if option[:liberal] then
      prune_liberally
    else
      prune_conservatively
    end

    self.filter(*option[:filters])
  end

  ##
  # Conservative prune. Remove any bucket that is known to contain a
  # subnode element of a node in another bucket.

  def prune_conservatively
    hashes_to_prune = {}

    # extract all subtree hashes from all nodes
    self.hashes.values.each do |nodes|
      nodes.first.all_structural_subhashes.each do |h|
        hashes_to_prune[h] = true
      end
    end

    # nuke subtrees so we show the biggest matching tree possible
    self.hashes.delete_if { |h,_| hashes_to_prune[h] }
  end

  ##
  # Liberal prune. Remove any _element_ from a bucket that is known to
  # be a subnode of another node. Removed by identity.

  def prune_liberally
    update_masses

    hashes_to_prune = Hash.new { |h,k| h[k] = [] }

    # record each subtree by subhash, but skip if subtree mass > parent mass
    self.hashes.values.each do |nodes|
      nodes.each do |node|
        tophash  = node.structural_hash
        topscore = self.masses[tophash]

        node.deep_each do |subnode|
          subhash  = subnode.structural_hash
          subscore = self.masses[subhash]

          next if subscore and subscore > topscore

          hashes_to_prune[subhash] << subnode
        end
      end
    end

    # nuke only individual items by object identity
    self.hashes.each do |h,v|
      v.delete_eql hashes_to_prune[h]
    end

    # nuke buckets we happened to fully empty
    self.hashes.delete_if { |k,v| v.size <= 1 }
  end

  ##
  # Output an n-way diff from +data+. This is only used if --diff is
  # given.

  def n_way_diff *data
    comments = []
    codes    = []

    split_and_group(data).each do |subdata|
      n = subdata.find_index { |s| s !~ /^#/ }

      comment, code = subdata[0..n-1], subdata[n..-1]
      comment = [] if n == 0

      comments << comment
      codes    << code
    end

    comments = collapse_and_label pad_with_empty_strings comments
    codes    = collapse_and_label pad_with_empty_strings codes

    (comments + codes).flatten.join("\n")
  end

  def split_and_group ary # :nodoc:
    ary.each_with_index.map { |s, i|
      c = (?A.ord + i).chr
      s.scan(/^.*/).map { |s2|
        s2.group = c
        s2
      }
    }
  end

  def pad_with_empty_strings ary # :nodoc:
    max = ary.map { |s| s.size }.max

    ary.map { |a| a + ([""] * (max - a.size)) }
  end

  def collapse_and_label ary # :nodoc:
    ary[0].zip(*ary[1..-1]).map { |lines|
      if lines.uniq.size == 1 then
        "   #{lines.first}"
      else
        lines.reject { |l| l.empty? }.map { |l| "#{l.group}: #{l}" }
      end
    }
  end

  ##
  # Calculate summary scores on a per-file basis. For --summary.

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

  ##
  # Output the report. Duh.

  def report io = $stdout
    only = option[:only]

    data = analyze only

    io.puts "Total score (lower is better) = #{self.total}"

    if option[:summary] then
      io.puts

      self.summary.sort_by { |_,v| -v }.each do |file, score|
        io.puts "%8.2f: %s" % [score, file]
      end

      return
    end

    data.each_with_index do |item, count|
      prefix = "%d) " % (count + 1) if option[:number]

      match = item.identical? ? "IDENTICAL" : "Similar"

      io.puts
      io.puts "%s%s code found in %p (mass%s = %d)" %
        [prefix, match, item.name, item.bonus, item.mass]

      item.locations.each_with_index do |loc, i|
        loc_prefix = "%s: " % (?A.ord + i).chr if option[:diff]
        extra = " (FUZZY)" if loc.fuzzy?
        io.puts "  %s%s:%d%s" % [loc_prefix, loc.file, loc.line, extra]
      end

      if option[:diff] then
        io.puts

        nodes = hashes[item.structural_hash]

        sources = nodes.map do |s|
          msg = "sexp_to_#{File.extname(s.file).sub(/./, "")}"
          self.respond_to?(msg) ? self.send(msg, s) : sexp_to_rb(s)
        end

        io.puts n_way_diff(*sources)
      end
    end
  end

  def sexp_to_rb sexp
    begin
      require "ruby2ruby"
    rescue LoadError
      return "ruby2ruby is required for diff"
    end
    @r2r ||= Ruby2Ruby.new
    @r2r.process sexp.deep_clone
  end
end

class String
  attr_accessor :group # :nodoc:
end

class Sexp
  ##
  # Whether or not this sexp is a mutated/modified sexp.

  attr_accessor :modified
  alias :modified? :modified # Is this sexp modified?

  ##
  # Calculate the structural hash for this sexp. Cached, so don't
  # modify the sexp afterwards and expect it to be correct.

  def structural_hash
    @structural_hash ||= pure_ruby_hash
  end

  ##
  # Returns a list of structural hashes for all nodes (and sub-nodes)
  # of this sexp.

  def all_structural_subhashes
    hashes = []
    self.deep_each do |node|
      hashes << node.structural_hash
    end
    hashes
  end

  def initialize_copy o # :nodoc:
    s = super
    s.file = o.file
    s.line = o.line
    s.modified = o.modified
    s
  end

  def [] a # :nodoc:
    s = super
    if Sexp === s then
      s.file = self.file
      s.line = self.line
      s.modified = self.modified
    end
    s
  end

  def + o # :nodoc:
    self.dup.concat o
  end

  ##
  # Useful general array method that splits the array from 0..+n+ and
  # the rest. Returns both sections.

  def split_at n
    return self[0..n], self[n+1..-1]
  end

  ##
  # Return the index of the last non-code element, or nil if this sexp
  # is not a code-bearing node.

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

  alias has_code? code_index # Does this sexp have a +*code+ section?

  ##
  # Split the sexp into front-matter and code-matter, returning both.
  # See #code_index.

  def split_code
    index = self.code_index
    self.split_at index if index
  end
end

class Sexp # straight from flay-persistent
  names = %w(alias and arglist args array attrasgn attrset back_ref
             begin block block_pass break call case cdecl class colon2
             colon3 const cvar cvasgn cvdecl defined defn defs dot2
             dot3 dregx dregx_once dstr dsym dxstr ensure evstr false
             flip2 flip3 for gasgn gvar hash iasgn if iter ivar lasgn
             lit lvar masgn match match2 match3 module next nil not
             nth_ref op_asgn op_asgn1 op_asgn2 op_asgn_and op_asgn_or or
             postexe redo resbody rescue retry return sclass self
             splat str super svalue to_ary true undef until valias
             when while xstr yield zsuper kwarg kwsplat safe_call)

  ##
  # All ruby_parser nodes in an index hash. Used by jenkins algorithm.

  NODE_NAMES = Hash[names.each_with_index.map {|n, i| [n.to_sym, i] }]

  NODE_NAMES.default_proc = lambda { |h, k|
    $stderr.puts "ERROR: couldn't find node type #{k} in Sexp::NODE_NAMES."
    h[k] = NODE_NAMES.size
  }

  MAX_INT32 = 2 ** 32 - 1 # :nodoc:

  def pure_ruby_hash # :nodoc: see above
    hash = 0

    n = NODE_NAMES[first]

    raise "Bad lookup: #{first} in #{sexp.inspect}" unless n

    hash += n          & MAX_INT32
    hash += hash << 10 & MAX_INT32
    hash ^= hash >>  6 & MAX_INT32

    each do |o|
      next unless Sexp === o
      hash = hash + o.pure_ruby_hash  & MAX_INT32
      hash = (hash + (hash << 10)) & MAX_INT32
      hash = (hash ^ (hash >>  6)) & MAX_INT32
    end

    hash = (hash + (hash <<  3)) & MAX_INT32
    hash = (hash ^ (hash >> 11)) & MAX_INT32
    hash = (hash + (hash << 15)) & MAX_INT32

    hash
  end
end

class Array # :nodoc:

  ##
  # Delete anything in +self+ if they are identical to anything in +other+.

  def delete_eql other
    self.delete_if { |o1| other.any? { |o2| o1.equal? o2 } }
  end
end
