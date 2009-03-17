#!/usr/bin/ruby -ws

$: << 'lib' << '../../ParseTree/dev/lib' << '../../flay/dev/lib'

$v ||= false # HACK

require 'rubygems'
require 'flay'

require 'gauntlet'
require 'pp'

class FlayGauntlet < Gauntlet
  $owners       = {}
  $score_file   = 'flay-scores.yml'
  $misc_error   = {:total => -1, :average => -1, :methods => {}}
  $syntax_error = {:total => -2, :average => -2, :methods => {}}
  $no_gem       = {:total => -4, :average => -4, :methods => {}}

  # copied straight from hoedown.rb 
  my_projects = %w[InlineFortran ParseTree RubyInline RubyToC
                   ZenHacks ZenTest bfts box_layout
                   change_class flay flog gauntlet heckle
                   hoe image_science miniunit minitest
                   minitest_tu_shim png ruby2ruby ruby_parser
                   rubyforge test-unit un vlad zenprofile
                   zentest]

  MY_PROJECTS = Regexp.union(*my_projects)

  def run name
    warn name
    self.data[name] = score_for '.'
    self.dirty = true
  end

  def display_report max
    good_data  = {}
    bad_count  = 0
    zero_count = 0

    @data.each do |name, flay|
      case
      when flay < 0 then
        bad_count += 1
      when flay == 0 then
        zero_count += 1
      else
        good_data[name] = flay
      end
    end

    scores = good_data.values

    # SWEET JESUS:
    #
    # without zeros:
    #   average flay: 1487.23 +/- 7800.16
    # with zeros:
    #   average flay:  988.69 +/- 6398.45

    puts "broken projects : %d" % bad_count
    puts "great projects  : %d" % zero_count
    puts "bad projects    : %d" % good_data.size
    puts "average flay    : %.2f +/- %.2f" % [scores.average, scores.stddev]

    top = good_data.sort_by { |name,flay| -flay }.first max

    puts
    top.each_with_index do |(name, flay), i|
      puts "%3d: %10.2f: %s" % [ i, flay, name ]
    end
  end

  ############################################################
  # OTHER
  ############################################################

  def score_for dir
    # files = `find #{dir} -name \\*.rb | grep -v gen.*templ`.split(/\n/)
    flayer = Flay.new

    dirs = %w(app lib test spec).reject { |f| ! File.directory? f }

    flay = Flay.new
    flay.process(*Flay.expand_dirs_to_files(dirs))
    flay.total
  rescue Interrupt
    # let us break out
  rescue Exception
    -1
  end
end

max    = (ARGV.shift || 10).to_i
filter = ARGV.shift
filter = Regexp.new filter if filter
flayer = FlayGauntlet.new
flayer.run_the_gauntlet filter
flayer.display_report max
