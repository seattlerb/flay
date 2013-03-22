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

  def test_delete_eql
    s1 = s(:a, s(:b, s(:c)))
    s2 = s(:a, s(:b, s(:c)))
    s3 = s(:a, s(:b, s(:c)))

    a1 = [s1, s2, s3]
    a2 = [s1,     s3]

    a1.delete_eql a2

    assert_equal [s2], a1
    assert_same s2, a1.first
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

  DOG_AND_CAT = Ruby18Parser.new.process <<-RUBY
    class Dog
      def x
        return "Hello"
      end
    end
    class Cat
      def y
        return "Hello"
      end
    end
  RUBY

  ROUND = Ruby18Parser.new.process <<-RUBY
    def x(n)
      if n % 2 == 0
        return n
      else
        return n + 1
      end
    end
  RUBY

  def test_prune
    contained = s(:a, s(:b,s(:c)), s(:d,s(:e)))
    container = s(:d, contained)

    flay = Flay.new :mass => 0
    flay.process_sexp s(:outer,contained)
    2.times { flay.process_sexp s(:outer,container) }

    exp = eval <<-EOM # just to prevent emacs from reindenting it
          [
           [      s(:a, s(:b, s(:c)), s(:d, s(:e))),
                  s(:a, s(:b, s(:c)), s(:d, s(:e))),
                  s(:a, s(:b, s(:c)), s(:d, s(:e)))],
           [            s(:b, s(:c)),
                        s(:b, s(:c)),
                        s(:b, s(:c))],
           [s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e)))),
            s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e))))],
           [                          s(:d, s(:e)),
                                      s(:d, s(:e)),
                                      s(:d, s(:e))],
          ]
    EOM

    assert_equal exp, flay.hashes.values.sort_by(&:inspect)

    flay.prune

    exp = [
           [s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e)))),
            s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e))))]
          ]

    assert_equal exp, flay.hashes.values.sort_by(&:inspect)
  end

  def test_prune_liberal
    contained = s(:a, s(:b,s(:c)), s(:d,s(:e)))
    container = s(:d, contained)

    flay = Flay.new :mass => 0, :liberal => true
    flay.process_sexp s(:outer,contained)
    2.times { flay.process_sexp s(:outer,container) }

    exp = eval <<-EOM # just to prevent emacs from reindenting it
          [
           [      s(:a, s(:b, s(:c)), s(:d, s(:e))),
                  s(:a, s(:b, s(:c)), s(:d, s(:e))),
                  s(:a, s(:b, s(:c)), s(:d, s(:e)))],
           [            s(:b, s(:c)),
                        s(:b, s(:c)),
                        s(:b, s(:c))],
           [s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e)))),
            s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e))))],
           [                          s(:d, s(:e)),
                                      s(:d, s(:e)),
                                      s(:d, s(:e))],
          ]
    EOM

    assert_equal exp, flay.hashes.values.sort_by(&:inspect)

    flay.prune

    exp = [
           [s(:a, s(:b, s(:c)), s(:d, s(:e))),
            s(:a, s(:b, s(:c)), s(:d, s(:e))),
            s(:a, s(:b, s(:c)), s(:d, s(:e)))],
           [s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e)))),
            s(:d, s(:a, s(:b, s(:c)), s(:d, s(:e))))]
          ]

    assert_equal exp, flay.hashes.values.sort_by(&:inspect)
  end

  def test_process_sexp
    flay = Flay.new

    expected = [] # only ones big enough

    flay.process_sexp ROUND.deep_clone

    actual = flay.hashes.values.map { |sexps| sexps.map { |sexp| sexp.first } }

    assert_equal expected, actual.sort_by { |a| a.first.to_s }
  end

  def test_process_sexp_full
    flay = Flay.new(:mass => 1)

    expected = [[:call, :call],
                [:call],
                [:if],
                [:return],
                [:return]]

    flay.process_sexp ROUND.deep_clone

    actual = flay.hashes.values.map { |sexps| sexps.map { |sexp| sexp.first } }

    assert_equal expected, actual.sort_by { |a| a.inspect }
  end

  def test_process_sexp_no_structure
    flay = Flay.new(:mass => 1)
    flay.process_sexp s(:lit, 1)

    assert flay.hashes.empty?
  end

  def test_report
    # make sure we run through options parser
    $*.clear
    $* << "-d"
    $* << "--mass=1"
    $* << "-v"

    opts = nil
    capture_io do # ignored
      opts = Flay.parse_options
    end

    flay = Flay.new opts

    flay.process_sexp DOG_AND_CAT.deep_clone
    flay.analyze

    out, err = capture_io do
      flay.report nil
    end

    exp = <<-END.gsub(/\d+/, "N").gsub(/^ {6}/, "")
      Total score (lower is better) = 16


      1) Similar code found in :class (mass = 16)
        A: (string):1
        B: (string):6

      A: class Dog
      B: class Cat
      A:   def x
      B:   def y
             return \"Hello\"
           end
         end
    END

    assert_equal '', err
    assert_equal exp, out.gsub(/\d+/, "N")
  end
end
