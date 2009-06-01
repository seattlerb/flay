#!/usr/bin/ruby -w

require 'test/unit'
require 'flay'

require 'pp' # TODO: remove

ON_1_9 = RUBY_VERSION =~ /1\.9/
SKIP_1_9 = true && ON_1_9 # HACK

class Symbol # for testing only, makes the tests concrete
  def hash
    to_s.hash
  end

  alias :crap :<=> if :blah.respond_to? :<=>
  def <=> o
    Symbol === o && self.to_s <=> o.to_s
  end
end

class TestSexp < Test::Unit::TestCase
  def setup
    # a(1) { |c| d }
    @s = s(:iter,
           s(:call, nil, :a, s(:arglist, s(:lit, 1))),
           s(:lasgn, :c),
           s(:call, nil, :d, s(:arglist)))
  end

  def test_mass
    assert_equal 1, s(:a).mass
    assert_equal 3, s(:a, s(:b), s(:c)).mass
    assert_equal 7, @s.mass
  end

  def test_compare_to
    s1 = s(:a, :b, :c)
    s2 = s(:d, :e, :f)
    assert_equal [3, 0, 3], s1.compare_to(s2), "100% different"

    s1 = s(:a, :b, :c)
    s2 = s(:a, :b, :c)
    assert_equal [0, 3, 0], s1.compare_to(s2), "100% same"

    s1 = s(:a, :b, :c, :d)
    s2 = s(:a, :b, :c, :e)
    assert_equal [1, 3, 1], s1.compare_to(s2), "1 element different on each"

    s1 = s(:a, :d, :b, :c)
    s2 = s(:a, :b, :c, :e)
    assert_equal [1, 3, 1], s1.compare_to(s2), "positionally different"


    s1 = s(:a, s(:d), :b, :c)
    s2 = s(:a, :b, :c, s(:e))
    assert_equal [1, 3, 1], s1.compare_to(s2), "simple subtree difference"
  end

  def test_fuzzy_hash
    s = s(:iter,
          s(:call, nil, :a, s(:arglist, s(:lit, 1))),
          s(:lasgn, :c),
          s(:call, nil, :d, s(:arglist)))

    hash = 955256285

    assert_equal hash, s.fuzzy_hash,             "hand copy"
    assert_equal hash, @s.fuzzy_hash,            "ivar from setup"
    assert_equal hash, @s.deep_clone.fuzzy_hash, "deep clone"
    assert_equal hash, s.deep_clone.fuzzy_hash,  "copy deep clone"
  end unless SKIP_1_9

  def test_all_subhashes
    expected = [-704571402, -282578980, -35395725,
                160138040, 815971090, 927228382]

    assert_equal expected, @s.all_subhashes.sort.uniq

    x = []

    @s.deep_each do |o|
      x << o.fuzzy_hash
    end

    assert_equal expected, x.sort.uniq
  end unless SKIP_1_9

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

class ArrayIntersectionTests < Test::Unit::TestCase
  def test_real_array_intersection
    assert_equal [2], [2, 2, 2, 3, 7, 13, 49] & [2, 2, 2, 5, 11, 107]
    assert_equal [2, 2, 2], [2, 2, 2, 3, 7, 13, 49].intersection([2, 2, 2, 5, 11, 107])
    assert_equal ['a', 'c'], ['a', 'b', 'a', 'c'] & ['a', 'c', 'a', 'd']
    assert_equal ['a', 'a'], ['a', 'b', 'a', 'c'].intersection(['a', 'c', 'a', 'd'])
  end
end
