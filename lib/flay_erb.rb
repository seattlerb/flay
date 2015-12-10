#!/usr/bin/ruby

require "rubygems"
require "flay"
require "erubis"

class Flay

  ##
  # Process erb and parse the result. Returns the sexp of the parsed
  # ruby.

  def process_erb file
    erb = File.read file

    ruby = Erubis.new(erb).src
    begin
      RubyParser.new.process(ruby, file)
    rescue => e
      warn ruby if option[:verbose]
      raise e
    end
  end

  class Erubis < ::Erubis::Eruby # :nodoc:
    BLOCK_EXPR = /\s+(do|\{)(\s*\|[^|]*\|)?\s*\Z/

    def add_expr_literal(src, code)
      if code =~ BLOCK_EXPR
        src << '@output_buffer.append= ' << code
      else
        src << '@output_buffer.append=(' << code << ');'
      end
    end

    def add_expr_escaped(src, code)
      if code =~ BLOCK_EXPR
        src << "@output_buffer.safe_append= " << code
      else
        src << "@output_buffer.safe_append=(" << code << ");"
      end
    end
  end
end
