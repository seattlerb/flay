# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe::add_include_dirs("../../sexp_processor/dev/lib",
                      "../../ruby_parser/dev/lib")

Hoe.plugin :seattlerb

Hoe.spec 'flay' do
  developer 'Ryan Davis', 'ryand-ruby@zenspider.com'

  self.rubyforge_name = 'seattlerb'
  self.flay_threshold = 250

  extra_deps << ['sexp_processor', '~> 3.0']
  extra_deps << ['ruby_parser',    '~> 2.0']
end

# vim: syntax=ruby
