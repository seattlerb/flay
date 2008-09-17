#!/usr/bin/env ruby -w

$: << "../../sexp_processor/dev/lib"
$: << "../../ruby_parser/dev/lib"

require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'
require 'pp' # TODO: remove

class Flay
  VERSION = '1.0.0'

  attr_reader :hashes

  def initialize
    @hashes = Hash.new { |h,k| h[k] = [] }
  end

  def process(*files)
    files.each do |file|
      warn "Processing #{file}..."
      pt = RubyParser.new.process(File.read(file), file)
      warn "... done parsing"

      last_line = 0
      p last_line


      pt.deep_each do |node|
        next unless node.any? { |sub| Sexp === sub }
        next unless node.complex_enough?

        l = node.line
        if l % 5 == 0 && last_line != l then
          last_line = l
          p last_line
        end

        self.hashes[node.hash] << node
      end
    end
  end

  def prune
    # prune trees that aren't duped at all.
    self.hashes.delete_if { |_,nodes| nodes.size == 1 }

    # extract all subtree hashes from all nodes
    all_hashes = self.hashes.values.map { |nodes|
      nodes.map { |node| node.all_subhashes }
    }.flatten.uniq

    # nuke subtrees so we show the biggest matching tree possible
    self.hashes.delete_if { |h,_| all_hashes.include? h }
  end

  def report prune = nil
    self.prune

    ds = []
    ns = []
    dns = []

    self.hashes.each do |_,nodes|
      next unless nodes.first.first == prune if prune
      puts "Matches found in: #{nodes.first.first}"
      nodes.each do |node|
        d, n = node.depth, node.number_of_nodes
        dn = d * n
        ds << d
        ns << n
        dns << dn
        puts "  #{node.file}:#{node.line} (d=#{d}, n=#{n}, dn = #{dn})"
      end
    end

    puts "number of nodes = #{ds.size}"
    puts "depth = #{ds.average} +/- #{ds.standard_deviation}"
    puts "nodes = #{ns.average} +/- #{ns.standard_deviation}"
    puts "prodt = #{dns.average} +/- #{dns.standard_deviation}"
  end
end

class Sexp
  def hash
    h = [self.first.hash]
    self.each do |e|
      next unless Sexp === e
      h << e.hash
    end
    h.hash
  end

  def each_sexp
    self.each do |sexp|
      next unless Sexp === sexp

      yield sexp
    end
  end

  def all_subhashes
    hashes = []
    self.deep_each do |node|
      hashes << node.hash
    end
    hashes[1..-1].uniq
  end

  def deep_each(&block)
    self.each_sexp do |sexp|
      block[sexp]
      sexp.deep_each(&block)
    end
  end

  def depth
    self.map { |sexp|
      next unless Sexp === sexp
      sexp.depth + 1
    }.compact.max || 0
  end

  def number_of_nodes
    nodes = 0
    self.deep_each do |n|
      nodes += 1
    end
    nodes
  end

  def complex_enough?
    d, n = self.depth, self.number_of_nodes

    d * n > 75 # my avg product + stddev. woot
  end

  alias :shut_up! :pretty_print
  def pretty_print(q) # shows the hash
    q.group(1, 'S(', ')') do
      q.seplist(self + ["#{self.file}:#{self.line}"]) {|v| q.pp v }
    end
  end
end

module Enumerable # TEMPORARY
  ##
  # Sum of all the elements of the Enumerable

  def sum
    return self.inject(0) { |acc, i| acc + i }
  end

  ##
  # Average of all the elements of the Enumerable
  #
  # The Enumerable must respond to #length

  def average
    return self.sum / self.length.to_f
  end

  ##
  # Sample variance of all the elements of the Enumerable
  #
  # The Enumerable must respond to #length

  def sample_variance
    avg = self.average
    sum = self.inject(0) { |acc, i| acc + (i - avg) ** 2 }
    return (1 / self.length.to_f * sum)
  end

  ##
  # Standard deviation of all the elements of the Enumerable
  #
  # The Enumerable must respond to #length

  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end

end

