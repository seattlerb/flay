# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe::add_include_dirs("../../sexp_processor/dev/lib",
                      "../../ruby_parser/dev/lib")

begin
  require 'flay'
rescue LoadError
  load 'lib/flay.rb'
end

Hoe.new('flay', Flay::VERSION) do |flay|
  flay.rubyforge_name = 'seattlerb'
  flay.developer('Ryan Davis', 'ryand-ruby@zenspider.com')

  flay.flay_threshold = 250

  flay.extra_deps << ['sexp_processor', '>= 3.0.0']
  flay.extra_deps << ['ruby_parser',    '>= 1.1.0']
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |t|
    pattern = ENV['PATTERN'] || 'test/test_*.rb'

    t.test_files = FileList[pattern]
    t.verbose = true
    t.rcov_opts << "--threshold 80"
    t.rcov_opts << "--no-color"
  end

  task :rcov_info do
    pattern = ENV['PATTERN'] || "test/test_*.rb"
    ruby "-Ilib -S rcov --text-report --save coverage.info -x rcov,sexp_processor --test-unit-only #{pattern}"
  end

  task :rcov_overlay do
    rcov, eol = Marshal.load(File.read("coverage.info")).last[ENV["FILE"]], 1
    puts rcov[:lines].zip(rcov[:coverage]).map { |line, coverage|
      bol, eol = eol, eol + line.length
      [bol, eol, "#ffcccc"] unless coverage
    }.compact.inspect
  end
rescue LoadError
  # skip
end

# vim: syntax=Ruby
