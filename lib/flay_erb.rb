require "flay"
require "erubi"

class Flay

  ##
  # Process erb and parse the result. Returns the sexp of the parsed
  # ruby.

  def process_erb file
    erb = File.read file

    ruby = Erubi.new(erb).src

    begin
      parser = option[:parser].new
      parser.process(ruby, file, option[:timeout])
    rescue => e
      warn ruby if option[:verbose]
      raise e
    end
  end

  # stolen (and munged) from lib/action_view/template/handlers/erb/erubi.rb
  # this is also in the debride-erb gem, update both!
  class Erubi < ::Erubi::Engine
    # :nodoc: all
    def initialize(input, properties = {})
      @newline_pending = 0

      properties[:postamble]  = "_buf.to_s"
      properties[:bufvar]     = "_buf"
      properties[:freeze_template_literals] = false

      super
    end

    def add_text(text)
      return if text.empty?

      if text == "\n"
        @newline_pending += 1
      else
        src << "_buf.safe_append='"
        src << "\n" * @newline_pending if @newline_pending > 0
        src << text.gsub(/['\\]/, '\\\\\&')
        src << "';"

        @newline_pending = 0
      end
    end

    BLOCK_EXPR = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

    def add_expression(indicator, code)
      flush_newline_if_pending(src)

      if (indicator == "==") || @escape
        src << "_buf.safe_expr_append="
      else
        src << "_buf.append="
      end

      if BLOCK_EXPR.match?(code)
        src << " " << code
      else
        src << "(" << code << ");"
      end
    end

    def add_code(code)
      flush_newline_if_pending(src)
      super
    end

    def add_postamble(_)
      flush_newline_if_pending(src)
      super
    end

    def flush_newline_if_pending(src)
      if @newline_pending > 0
        src << "_buf.safe_append='#{"\n" * @newline_pending}';"
        @newline_pending = 0
      end
    end
  end
end
