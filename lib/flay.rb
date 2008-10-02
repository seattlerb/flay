#!/usr/bin/env ruby -w

$: << "../../sexp_processor/dev/lib" # TODO: remove
$: << "../../ruby_parser/dev/lib"

require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'
require 'pp' # TODO: remove

class Flay
  VERSION = '1.0.0'

  attr_reader :hashes

  def initialize(mass = 16)
    @hashes = Hash.new { |h,k| h[k] = [] }
    @mass_threshold = mass
  end

  def process(*files)
    files.each do |file|
      warn "Processing #{file}..."

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

  def report prune = nil
    self.prune

    self.hashes.each do |_,nodes|
      next unless nodes.first.first == prune if prune
      puts
      puts "Matches found in: #{nodes.first.first}"
      nodes.each do |node|
        puts "  #{node.file}:#{node.line} (mass = #{node.mass})"
      end
    end
  end
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

  alias :old_inspect :inspect
  def inspect
    old_inspect.sub(/\)\Z/, ":h_#{self.fuzzy_hash})")
  end

  alias :shut_up! :pretty_print
  def pretty_print(q) # shows the hash TODO: remove
    q.group(1, 'S(', ')') do
      q.seplist(self + [":h_#{self.fuzzy_hash}"]) {|v| q.pp v }
    end
  end
end
