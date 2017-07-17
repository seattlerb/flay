= flay

home :: http://ruby.sadi.st/
code :: https://github.com/seattlerb/flay
rdoc :: http://docs.seattlerb.org/flay/

== DESCRIPTION:

Flay analyzes code for structural similarities. Differences in literal
values, variable, class, method names, whitespace, programming style,
braces vs do/end, etc are all ignored. Making this totally rad.

== FEATURES/PROBLEMS:

* Reports differences at any level of code.
* Adds a score multiplier to identical nodes.
* Differences in literal values, variable, class, and method names are ignored.
* Differences in whitespace, programming style, braces vs do/end, etc are ignored.
* Works across files.
  * Add the flay-persistent plugin to work across large/many projects.
* Run --diff to see an N-way diff of the code.
* Provides conservative (default) and --liberal pruning options.
* Provides --fuzzy duplication detection.
* Language independent: Plugin system allows other languages to be flayed.
  * Ships with .rb and .erb.
  * javascript and others will be available separately.
* Includes FlayTask for Rakefiles.
* Uses path_expander, so you can use:
  * dir_arg -- expand a directory automatically
  * @file_of_args -- persist arguments in a file
  * -path_to_subtract -- ignore intersecting subsets of files/directories
* Skips files matched via patterns in .flayignore (subset format of .gitignore).
* Totally rad.

== KNOWN EXTENSIONS:

* flay-actionpack  :: Use Rails ERB handler.
* flay-js          :: Process JavaScript files.
* flay-haml        :: Flay your HAML source.
* flay-persistence :: Persist results across runs. Great for multi-project analysis.

== TODO:

* Editor integration (emacs, textmate, other contributions welcome).

* Vim integration started (https://github.com/prophittcorey/vim-flay)
    - Flays the current file on save, load, or on command

== SYNOPSIS:

  % flay -v --diff ~/Work/svn/ruby/ruby_1_8/lib/cgi.rb
  Processing /Users/ryan/Work/svn/ruby/ruby_1_8/lib/cgi.rb...

  Matches found in :defn (mass = 184)
    A: /Users/ryan/Work/svn/ruby/ruby_1_8/lib/cgi.rb:1470
    B: /Users/ryan/Work/svn/ruby/ruby_1_8/lib/cgi.rb:1925

  A: def checkbox_group(name = "", *values)
  B: def radio_group(name = "", *values)
       if name.kind_of?(Hash) then
         values = name["VALUES"]
         name = name["NAME"]
       end
       values.collect do |value|
         if value.kind_of?(String) then
  A:       (checkbox(name, value) + value)
  B:       (radio_button(name, value) + value)
         else
           if (value[(value.size - 1)] == true) then
  A:         (checkbox(name, value[0], true) + value[(value.size - 2)])
  B:         (radio_button(name, value[0], true) + value[(value.size - 2)])
           else
  A:         (checkbox(name, value[0]) + value[(value.size - 1)])
  B:         (radio_button(name, value[0]) + value[(value.size - 1)])
           end
         end
       end.to_s
     end

  IDENTICAL Matches found in :for (mass*2 = 144)
    A: /Users/ryan/Work/svn/ruby/ruby_1_8/lib/cgi.rb:2160
    B: /Users/ryan/Work/svn/ruby/ruby_1_8/lib/cgi.rb:2217

     for element in ["HTML", "BODY", "P", "DT", "DD", "LI", "OPTION", "THEAD", "TFOOT", "TBODY", "COLGROUP", "TR", "TH", "TD", "HEAD"] do
       methods = (methods + (("          def #{element.downcase}(attributes = {})\n" + nO_element_def(element)) + "          end\n"))
     end
  ...

== REQUIREMENTS:

* ruby_parser
* sexp_processor
* path_expander
* ruby2ruby -- soft dependency: only if you want to use --diff

== INSTALL:

* sudo gem install flay

== LICENSE:

(The MIT License)

Copyright (c) Ryan Davis, Seattle.rb

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
