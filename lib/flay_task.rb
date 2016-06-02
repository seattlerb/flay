require 'rake/tasklib'

class FlayTask < Rake::TaskLib
  ##
  # The name of the task. Defaults to :flay

  attr_accessor :name

  ##
  # What directories to operate on. Sensible defaults.

  attr_accessor :dirs

  ##
  # Threshold to fail the task at. Default 200.

  attr_accessor :threshold

  ##
  # Verbosity of output. Defaults to rake's trace (-t) option.

  attr_accessor :verbose

  ##
  # Creates a new FlayTask instance with given +name+, +threshold+,
  # and +dirs+.

  def initialize name = :flay, threshold = 200, dirs = nil
    @name      = name
    @dirs      = dirs || %w(app bin lib spec test)
    @threshold = threshold
    @verbose   = Rake.application.options.trace

    yield self if block_given?

    @dirs.reject! { |f| ! File.directory? f }

    define
  end

  ##
  # Defines the flay task.

  def define
    desc "Analyze for code duplication in: #{dirs.join(", ")}"
    task name do
      require "flay"
      flay = Flay.run
      flay.report if verbose

      raise "Flay total too high! #{flay.total} > #{threshold}" if
        flay.total > threshold
    end
    self
  end
end
