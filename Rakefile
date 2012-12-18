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
  dependency 'ruby_parser',    '~> 3.0.0'
end

task :debug do
  require "flay"

  file = ENV["F"]

  flay = Flay.new
  flay.process(*Flay.expand_dirs_to_files(file))
  flay.report
end

# vim: syntax=ruby
