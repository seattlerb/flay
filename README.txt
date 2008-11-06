= flay

* http://ruby.sadi.st/
* http://rubyforge.org/projects/seattlerb

== DESCRIPTION:

Flay analyzes ruby code for structural similarities. Differences in
literal values, variable, class, method names, whitespace, programming
style, braces vs do/end, etc are all ignored. Making this totally rad.

== FEATURES/PROBLEMS:

* Differences in literal values, variable, class, and method names are ignored.
* Differences in whitespace, programming style, braces vs do/end, etc are ignored.
* Works across files.
* Reports differences at any level of code.

== TODO:

* Editor integration (emacs, textmate, other contributions welcome).
* N-way diff reporting... or... something. Not sure.
* UI improvement suggestions welcome. :)

== SYNOPSIS:

  % flay lib/*.rb
  Processing unit/itemconfig.rb...
  
  Matches found in :when (mass = 572)
    unit/itemconfig.rb:343
    unit/itemconfig.rb:379
    unit/itemconfig.rb:706
    unit/itemconfig.rb:742
  
  Matches found in :when (mass = 500)
    unit/itemconfig.rb:509
    unit/itemconfig.rb:539
    unit/itemconfig.rb:875
    unit/itemconfig.rb:905
  ...

== REQUIREMENTS:

* ruby_parser
* sexp_processor

== INSTALL:

* sudo gem install flay

== LICENSE:

(The MIT License)

Copyright (c) 2008 Ryan Davis, Seattle.rb

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
