= flay

* http://ruby.sadi.st/
* http://rubyforge.org/projects/seattlerb

== DESCRIPTION:

Flay analyzes code for structural similarities. Differences in literal
values, variable, class, method names, whitespace, programming style,
braces vs do/end, etc are all ignored. Making this totally rad.

== FEATURES/PROBLEMS:

* Plugin system allows other languages to be flayed.
  * Ships with .rb and .erb. javascript and others will be available separately.
* Includes FlayTask for Rakefiles.
* Differences in literal values, variable, class, and method names are ignored.
* Differences in whitespace, programming style, braces vs do/end, etc are ignored.
* Works across files.
* Reports differences at any level of code.
* Totally rad.
* Adds a score multiplier to identical nodes.
* Run verbose to see an N-way diff of the code.

== TODO:

* Editor integration (emacs, textmate, other contributions welcome).
* Score sequence fragments (a;b;c;d;e) vs (b;c;d) etc.

== SYNOPSIS:

  % flay -v ~/Work/svn/ruby/ruby_1_8/lib/cgi.rb
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

== INSTALL:

* sudo gem install flay

== LICENSE:

(The MIT License)

Copyright (c) 2008-2009 Ryan Davis, Seattle.rb

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
