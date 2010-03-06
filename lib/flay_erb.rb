#!/usr/bin/ruby

require 'rubygems'
require 'flay'
require 'erb'

class Flay
  def process_erb file
    erb = File.read file

    ruby = ERB.new(erb).src
    begin
      RubyParser.new.process(ruby, file)
    rescue => e
      warn ruby if option[:verbose]
      raise e
    end
  end
end
