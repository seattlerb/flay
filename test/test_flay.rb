#!/usr/bin/ruby -w

require 'minitest/autorun'
require 'flay'

$: << "../../sexp_processor/dev/lib"

class TestSexp < Minitest::Test
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
    ##
    # I am a dog.

    class Dog
      def x
        return "Hello"
      end
    end

    ##
    # I
    # am
    # a
    # cat.

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
        (string):1
        (string):6
    END

    assert_equal '', err
    assert_equal exp, out.gsub(/\d+/, "N")
  end

  def test_report_diff
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

         ##
      A: # I am a dog.
      B: # I
      B: # am
      B: # a
      B: # cat.

      A: class Dog
      B: class Cat
      A:   def x
      B:   def y
             return \"Hello\"
           end
         end
    END

    assert_equal '', err
    assert_equal exp, out.gsub(/\d+/, "N").gsub(/^ {3}$/, "")
  end

  def test_report_diff_plugin_converter
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

    # (string) does not have extension, maps to :sexp_to_
    Flay.send(:define_method, :sexp_to_){|s| "source code #{s.line}"}

    out, err = capture_io do
      flay.report nil
    end

    Flay.send(:remove_method, :sexp_to_)

    exp = <<-END.gsub(/\d+/, "N").gsub(/^ {6}/, "")
      Total score (lower is better) = 16

      1) Similar code found in :class (mass = 16)
        A: (string):1
        B: (string):6

      A: source code 1
      B: source code 6
    END

    assert_equal '', err
    assert_equal exp, out.gsub(/\d+/, "N").gsub(/^ {3}$/, "")
  end

  def test_n_way_diff
    dog_and_cat = ["##\n# I am a dog.\n\nclass Dog\n  def x\n    return \"Hello\"\n  end\nend",
                   "##\n# I\n#\n# am\n# a\n# cat.\n\nclass Cat\n  def y\n    return \"Hello\"\n  end\nend"]

    flay = Flay.new

    exp = <<-EOM.gsub(/\d+/, "N").gsub(/^ {6}/, "").chomp
         ##
      A: # I am a dog.
      B: # I
      B: #
      B: # am
      B: # a
      B: # cat.

      A: class Dog
      B: class Cat
      A:   def x
      B:   def y
             return \"Hello\"
           end
         end
    EOM

    assert_equal exp, flay.n_way_diff(*dog_and_cat).gsub(/^ {3}$/, "")
  end

  def test_n_way_diff_no_comments
    dog_and_cat = ["class Dog\n  def x\n    return \"Hello\"\n  end\nend",
                   "class Cat\n  def y\n    return \"Hello\"\n  end\nend"]

    flay = Flay.new

    exp = <<-EOM.gsub(/\d+/, "N").gsub(/^ {6}/, "").chomp
      A: class Dog
      B: class Cat
      A:   def x
      B:   def y
             return \"Hello\"
           end
         end
    EOM

    assert_equal exp, flay.n_way_diff(*dog_and_cat).gsub(/^ {3}$/, "")
  end

  def test_split_and_group
    flay = Flay.new

    act = flay.split_and_group ["a\nb\nc", "d\ne\nf"]
    exp = [%w(a b c), %w(d e f)]

    assert_equal exp, act
    assert_equal [%w(A A A), %w(B B B)], act.map { |a| a.map { |s| s.group } }
  end

  def test_pad_with_empty_strings
    flay = Flay.new

    a = %w(a b c)
    b = %w(d)

    assert_equal [a, ["d", "", ""]], flay.pad_with_empty_strings([a, b])
  end

  def test_pad_with_empty_strings_same
    flay = Flay.new

    a = %w(a b c)
    b = %w(d e f)

    assert_equal [a, b], flay.pad_with_empty_strings([a, b])
  end

  def test_collapse_and_label
    flay = Flay.new

    a = %w(a b c).map { |s| s.group = "A"; s }
    b = %w(d b f).map { |s| s.group = "B"; s }

    exp = [["A: a", "B: d"], "   b", ["A: c", "B: f"]]

    assert_equal exp, flay.collapse_and_label([a, b])
  end

  def test_collapse_and_label_same
    flay = Flay.new

    a = %w(a b c).map { |s| s.group = "A"; s }
    b = %w(a b c).map { |s| s.group = "B"; s }

    exp = ["   a", "   b", "   c"]

    assert_equal exp, flay.collapse_and_label([a, b])
  end

  def test_n_way_diff_methods
    dog_and_cat = ["##\n# I am a dog.\n\ndef x\n  return \"Hello\"\nend",
                   "##\n# I\n#\n# am\n# a\n# cat.\n\ndef y\n  return \"Hello\"\nend"]

    opts = Flay.parse_options
    flay = Flay.new opts

    exp = <<-EOM.gsub(/\d+/, "N").gsub(/^ {6}/, "").chomp
         ##
      A: # I am a dog.
      B: # I
      B: #
      B: # am
      B: # a
      B: # cat.

      A: def x
      B: def y
           return \"Hello\"
         end
    EOM

    assert_equal exp, flay.n_way_diff(*dog_and_cat).gsub(/^ {3}$/, "")
  end
end
