#!/usr/bin/ruby -w

require 'minitest/autorun'
require 'flay'

$: << "../../sexp_processor/dev/lib"

class TestSexp < MiniTest::Unit::TestCase
  def setup
    # a(1) { |c| d }
    @s = s(:iter,
           s(:call, nil, :a, s(:arglist, s(:lit, 1))),
           s(:lasgn, :c),
           s(:call, nil, :d, s(:arglist)))
  end

  def test_structural_hash
    hash = s(:iter,
             s(:call, s(:arglist, s(:lit))),
             s(:lasgn),
             s(:call, s(:arglist))).hash

    assert_equal hash, @s.structural_hash
    assert_equal hash, @s.deep_clone.structural_hash
  end

  def test_all_structural_subhashes
    s = s(:iter,
          s(:call, s(:arglist, s(:lit))),
          s(:lasgn),
          s(:call, s(:arglist)))

    expected = [
                s[1]      .hash,
                s[1][1]   .hash,
                s[1][1][1].hash,
                s[2]      .hash,
                s[3]      .hash,
                s[3][1]   .hash,
               ].sort

    assert_equal expected, @s.all_structural_subhashes.sort.uniq

    x = []

    @s.deep_each do |o|
      x << o.structural_hash
    end

    assert_equal expected, x.sort.uniq
  end

  def test_process_sexp
    flay = Flay.new

    s = RubyParser.new.process <<-RUBY
      def x(n)
        if n % 2 == 0
          return n
        else
          return n + 1
        end
      end
    RUBY

    expected = [[:block],
                # HACK [:defn],
                [:scope]] # only ones big enough

    flay.process_sexp s

    actual = flay.hashes.values.map { |sexps| sexps.map { |sexp| sexp.first } }

    assert_equal expected, actual.sort_by { |a| a.first.to_s }
  end

  def test_process_sexp_full
    flay = Flay.new(:mass => 1)

    s = RubyParser.new.process <<-RUBY
      def x(n)
        if n % 2 == 0
          return n
        else
          return n + 1
        end
      end
    RUBY

    expected = [[:arglist, :arglist, :arglist],
                [:block],
                [:call, :call],
                [:call],
                [:if],
                [:return],
                [:return],
                [:scope]]

    flay.process_sexp s

    actual = flay.hashes.values.map { |sexps| sexps.map { |sexp| sexp.first } }

    assert_equal expected, actual.sort_by { |a| a.inspect }
  end

  def test_process_sexp_no_structure
    flay = Flay.new(:mass => 1)
    flay.process_sexp s(:lit, 1)

    assert flay.hashes.empty?
  end
end
