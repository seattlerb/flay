# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe::add_include_dirs("../../sexp_processor/dev/lib",
                      "../../ruby_parser/dev/lib")

require './lib/flay.rb'

Hoe.new('flay', Flay::VERSION) do |flay|
  flay.rubyforge_name = 'seattlerb'
  flay.developer('Ryan Davis', 'ryand-ruby@zenspider.com')

  flay.extra_deps << ['sexp_processor', '>= 3.0.0']
  flay.extra_deps << ['ruby_parser',    '>= 1.1.0']
end

# vim: syntax=Ruby
