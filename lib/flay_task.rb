class FlayTask < Rake::TaskLib
  attr_accessor :name
  attr_accessor :dirs
  attr_accessor :threshold
  attr_accessor :verbose

  def initialize name = :flay, threshold = 200, dirs = nil
    @name      = name
    @dirs      = dirs || %w(app bin lib spec test)
    @threshold = threshold
    @verbose   = Rake.application.options.trace

    yield self if block_given?

    @dirs.reject! { |f| ! File.directory? f }

    define
  end

  def define
    desc "Analyze for code duplication in: #{dirs.join(', ')}"
    task name do
      require "flay"
      flay = Flay.new
      flay.process(*Flay.expand_dirs_to_files(dirs))
      flay.report if verbose

      raise "Flay total too high! #{flay.total} > #{threshold}" if
        flay.total > threshold
    end
    self
  end
end
