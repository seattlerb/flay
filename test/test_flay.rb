#!/usr/bin/ruby -w

require 'test/unit'
require 'flay'

$: << "../../sexp_processor/dev/lib"

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

  def test_structural_hash
    s = s(:iter,
          s(:call, nil, :a, s(:arglist, s(:lit, 1))),
          s(:lasgn, :c),
          s(:call, nil, :d, s(:arglist)))

    hash = 955256285

    assert_equal hash, s.structural_hash,             "hand copy"
    assert_equal hash, @s.structural_hash,            "ivar from setup"
    assert_equal hash, @s.deep_clone.structural_hash, "deep clone"
    assert_equal hash, s.deep_clone.structural_hash,  "copy deep clone"
  end unless SKIP_1_9

  def test_all_structural_subhashes
    expected = [-704571402, -282578980, -35395725,
                160138040, 815971090, 927228382]

    assert_equal expected, @s.all_structural_subhashes.sort.uniq

    x = []

    @s.deep_each do |o|
      x << o.structural_hash
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
