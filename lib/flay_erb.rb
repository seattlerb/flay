#!/usr/bin/ruby

require 'rubygems'
require 'flay'
require 'erb'

class Flay
  def process_erb file
    erb = File.read file

    src = ERB.new(erb).src
    RubyParser.new.process(src, file)
  end
end
