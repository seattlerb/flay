# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe::add_include_dirs("../../sexp_processor/dev/lib",
                      "../../ruby_parser/dev/lib",
                      "../../ruby2ruby/dev/lib",
                      "../../ZenTest/dev/lib",
                      "../../path_expander/dev/lib",
                      "lib")

Hoe.plugin :seattlerb
Hoe.plugin :isolate
Hoe.plugin :bundler

Hoe.spec "flay" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"
  license "MIT"

  dependency "sexp_processor", "~> 4.0"
  dependency "ruby_parser",    "~> 3.0"
  dependency "erubis",         "~> 2.7.0"
  dependency "path_expander",  "~> 1.0"

  dependency "minitest",       "~> 5.8.0", :dev
  dependency "ruby2ruby",      "~> 2.2.0", :dev

  self.flay_threshold = 250
end

task :debug => :isolate do
  require "flay"

  file = ENV["F"]
  fuzz = ENV["Z"] && ["-f", ENV["Z"]]
  mass = ENV["M"] && ["-m", ENV["M"]]
  diff = ENV["D"] && ["-d"]
  libr = ENV["L"] && ["-l"]
  ver  = ENV["V"] && ["-v"]

  flay = Flay.run [mass, fuzz, diff, libr, file, ver].flatten.compact
  flay.report
end

# vim: syntax=ruby
