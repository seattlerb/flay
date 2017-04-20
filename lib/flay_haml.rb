#!/usr/bin/ruby
require 'rubygems'
require 'flay'
require 'haml'

class Flay

  ##
  # Process erb and parse the result. Returns the sexp of the parsed
  # ruby.

  def process_haml file
    haml = File.read file

    ruby = Haml::Engine.new(haml).precompiled
    begin
      RubyParser.new.process(ruby, file)
    rescue => e
      warn ruby if option[:verbose]
      raise e
    end
  end
end
