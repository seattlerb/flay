# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe::add_include_dirs("../../sexp_processor/dev/lib",
                      "../../ruby_parser/dev/lib",
                      "../../ruby2ruby/dev/lib",
                      "../../ZenTest/dev/lib",
                      "lib")

Hoe.plugin :seattlerb

Hoe.spec 'flay' do
  developer 'Ryan Davis', 'ryand-ruby@zenspider.com'

  self.rubyforge_name = 'seattlerb'
  self.flay_threshold = 250

  dependency 'sexp_processor', '~> 4.0'
  dependency 'ruby_parser',    '~> 3.0'
end

task :debug do
  require "flay"

  file = ENV["F"]
  mass = ENV["M"]
  diff = ENV["D"]
  libr = ENV["L"]

  opts = Flay.parse_options
  opts[:mass] = mass.to_i if mass
  opts[:diff] = diff.to_i if diff
  opts[:liberal] = true if libr

  flay = Flay.new opts
  flay.process(*Flay.expand_dirs_to_files(file))
  flay.report
end

task :run do
  file = ENV["F"]
  fuzz = ENV["Z"] && "-f #{ENV["Z"]}"
  mass = ENV["M"] && "-m #{ENV["M"]}"
  diff = ENV["D"] && "-d"
  libr = ENV["L"] && "-l"

  ruby "#{Hoe::RUBY_FLAGS} bin/flay #{mass} #{fuzz} #{diff} #{libr} #{file}"
end

# vim: syntax=ruby
