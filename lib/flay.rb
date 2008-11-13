#!/usr/bin/env ruby -w

$: << "../../ruby_parser/dev/lib"

require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'

if $v then
  $: << "../../ruby2ruby/dev/lib"
  require 'ruby2ruby'
  require 'tempfile'
end

class Flay
  VERSION = '1.1.0'

  attr_reader :hashes

  def initialize(mass = 16)
    @hashes = Hash.new { |h,k| h[k] = [] }
    @mass_threshold = mass
  end

  def process(*files)
    files.each do |file|
      warn "Processing #{file}"

      t = Time.now
      pt = RubyParser.new.process(File.read(file), file)

      next unless pt # empty files... hahaha, suck.

      t = Time.now
      pt.deep_each do |node|
        next unless node.any? { |sub| Sexp === sub }
        next if node.mass < @mass_threshold

        self.hashes[node.fuzzy_hash] << node
      end
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
      s.push(*(["\n"] * (max - s.size))) # pad
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
        lines.map { |l| "#{l.group}: #{l}" }
      end
    }
    groups.flatten.join("\n")
  end

  def report prune = nil
    self.prune

    identical = {}
    masses = {}

    self.hashes.each do |hash,nodes|
      identical[hash] = nodes[1..-1].all? { |n| n == nodes.first }
      masses[hash] = nodes.first.mass * nodes.size
      masses[hash] *= (nodes.size) if identical[hash]
    end

    masses.sort_by { |_,mass| -mass }.each do |hash,mass|
      nodes = hashes[hash]
      next unless nodes.first.first == prune if prune
      puts

      same = identical[hash]
      node = nodes.first
      n = nodes.size

      puts "%sMatches found in %p (mass%s = %d)" %
        [same ? "IDENTICAL " : "", node.first, same ? "*#{n}" : "", mass]

      nodes.each_with_index do |node, i|
        if $v then
          c = (?A + i).chr
          puts "  #{c}: #{node.file}:#{node.line}"
        else
          puts "  #{node.file}:#{node.line}"
        end
      end

      if $v then
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

class Symbol
  def hash
    @hash ||= self.to_s.hash
  end
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

#   alias :old_inspect :inspect
#   def inspect
#     old_inspect.sub(/\)\Z/, ":h_#{self.fuzzy_hash})")
#   end

  alias :shut_up! :pretty_print
  def pretty_print(q) # shows the hash TODO: remove
    q.group(1, 'S(', ')') do
      q.seplist(self + [":h_#{self.fuzzy_hash}"]) {|v| q.pp v }
    end
  end
end

#   def n_way_diff a, *others
#     r = []

#     Tempfile.open("a") do |ta|
#       ta.write a
#       ta.flush
#       pa = ta.path

#       others.each_with_index do |b, i|
#         c = (?B + i).chr
#         Tempfile.open("b") do |tb|
#           tb.write b
#           tb.flush
#           pb = tb.path
#           r<<`diff --old-line-format="A: %L" --new-line-format="#{c}: %L" #{pa} #{pb}`
# #           diff = `diff -U999 #{pa} #{pb}`
# #           r << diff.gsub(/^[^-+]/, '   ').gsub(/^-/, 'A: ').gsub(/^\+/, "#{c}: ")
#         end
#       end
#     end

#     r.map! { |s| s.split(/\n/)[0..-1] }
#     r[0].zip(*r[1..-1]).map { |lines| lines.uniq }.flatten.join("\n")
#   end

