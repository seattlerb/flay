#!/usr/bin/ruby -w

require 'test/unit'
require 'flay'

class SexpTest < Test::Unit::TestCase
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

    hash = 992252

    assert_equal hash, s.fuzzy_hash,             "hand copy"
    assert_equal hash, @s.fuzzy_hash,            "ivar from setup"
    assert_equal hash, @s.deep_clone.fuzzy_hash, "deep clone"
    assert_equal hash, s.deep_clone.fuzzy_hash,  "copy deep clone"
  end

  def test_all_subhashes
    expected = [187948, 214336, 214416, 214496, 283760, 380700]

    assert_equal expected, @s.all_subhashes.sort.uniq
    assert ! @s.all_subhashes.include?(@s.fuzzy_hash)

    x = []

    @s.deep_each do |o|
      x << o.fuzzy_hash
    end

    assert_equal expected, x.sort.uniq
  end

end
