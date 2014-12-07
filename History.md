=== 2.5.0 / 2014-05-29

* 6 minor enhancements:

  * Added Flay::Item and Flay::Location to encapsulate analysis.
  * Added `--only nodetype` filter flag.
  * Flay#analyze now returns a nice data structure you can walk over.
  * Flay#report is now much more dumb. :)
  * Flay#report now takes an optional IO object.
  * Removed unused prune arg in Flay#report.

=== 2.4.0 / 2013-07-24

* 1 minor enhancement:

  * Allow plugins to provide sexp to source converters for --diff. (UncleGene)

=== 2.3.1 / 2013-07-11

* 1 bug fix:

  * Fixed --diff outputting twice if there are no comments. (kalenkov)

=== 2.3.0 / 2013-05-10

* 2 minor enhancements:

  * Refactored n_way_diff into split_and_group, collapse_and_label, and pad_with_empty_strings.
  * n_way_diff now does leading comments separately from the code, to better align diffs.

* 1 bug fix:

  * Fixed code/home urls in readme/gem.

=== 2.2.0 / 2013-04-09

Semantic versioning doesn't take into account how AWESOME a release
is. In this case, it severely falls short. I'd jump to 4.0 if I could.

* 2 major enhancements:

  * Added --fuzzy (ie copy, paste, & modify) duplication detection.
  * Added --liberal, which changes the way prune works to identify more duplication.

* 12 minor enhancements:

  * Added -# to turn off item numbering. Helps with diffs to compare runs over time.
  * Added Sexp#+.
  * Added Sexp#code_index to specify where *code starts in some sexps.
  * Added Sexp#has_code?.
  * Added Sexp#initalize_copy to propagate file/line/modified info.
  * Added Sexp#modified, #modified=, and #modified?.
  * Added Sexp#split_at(n). (Something I've wanted in Array for ages).
  * Added Sexp#split_code.
  * Added mass and diff options to rake debug.
  * Added rake run task w/ mass, diff, and liberal options
  * Made report's sort more stable, so I can do better comparison runs.
  * Wrapped Sexp#[] to propagate file/line/modified info.

=== 2.1.0 / 2013-02-13

* 5 minor enhancements:

  * Added --timeout option. Defaults to 10 seconds.
  * Added ability for plugins to define options_<pluginname> method to extend options.
  * Flay no longer defaults to '.' if no args given. Allows plugins to do more
  * Moved #analyze down to #report. #process only processes, nothing more.
  * Sort output for more stable reporting. Better for diffing against, my dear.

=== 2.0.1 / 2012-12-18

* 2 bug fixes:

  * Avoid redefined warning for File::RUBY19. (svendahlstrand)
  * Relaxed the ruby_parser dependency.

=== 2.0.0 / 2012-11-02

* 1 minor enhancement:

  * Added a timeout handler to skip when RubyParser times out on a large file

=== 2.0.0.b1 / 2012-08-07

* 2 major enhancements:

  * Parses ruby 1.9! (still in beta)
  * Moved Sexp#deep_each and Sexp#each_sexp to sexp_processor

* 1 minor enhancements:

  * Use File.binread (File.read in 1.8) to bypass encoding errors

* 1 bug fix:

  * Fixed failing tests against ruby_parser 3

=== 1.4.3 / 2011-08-10

* 1 bug fix:

  * Fixes for 1.9 with --diff. (mmullis)

=== 1.4.2 / 2011-02-18

* 2 bug fixes:

  * Added flay require in flay_task
  * Switched to minitest. (doh)

=== 1.4.1 / 2010-09-01

* 2 minor enhancements:

  * Added extra error handling for ERB flay to deal with tons of bad ERB
  * Skip plugin if another version already loaded (eg local vs gem).

* 1 bug fix:

  * Fixed all tests that were having problems on 1.9 due to unstable hashes

=== 1.4.0 / 2009-08-14

* 4 minor enhancements:

  * Pushed Sexp#mass up to sexp_processor.
  * Removed #similarity #compare_to, #intersection, #triangle, and other cruft.
  * Renamed all_subhashes to all_structural_subhashes.
  * Renamed fuzzy_hash to structural_hash.

=== 1.3.0 / 2009-06-23

* 5 minor enhancements:

  * Added --summary to display flay scores per file.
  * Added --verbose to display processing progress.
  * Protect against syntax errors in bad code and continue flaying.
  * Removed fuzzy matching. Never got it to feel right. Slow. Broken on 1.9
  * Renamed --verbose to --diff.

=== 1.2.1 / 2009-03-16

* 3 minor enhancements:

  * Added gauntlet_flay.rb
  * Cached value of plugins loaded.
  * Refactored and separated analysis phase from process phase

* 1 bug fix:

  * Added bin dir to default dirs list in FlayTask

=== 1.2.0 / 2009-03-09

* 2 major enhancements:

  * Added flay_task.rb
  * Added plugin system (any flay_(c,java,js,etc).rb files).

* 4 minor enhancements:

  * Added expand_dirs_to_files and made dirs valid arguments.
  * Added flay_erb.rb plugin.
  * Added optparse option processing.
  * Refactored to make using w/in rake and other CI systems clean and easy.

=== 1.1.0 / 2009-01-20

* 7 minor enhancement:

  * Added -v verbose mode to print out N-way diff of the detected code.
  * Added identical node scoring and reporting.
  * Added the start of copy/paste+edit detection, not even close yet.
  * Added more tests.
  * Added rcov tasks
  * Clarified output a bit
  * Refactored process_sexps to make doing other languages/systems easier.

=== 1.0.0 / 2008-11-06

* 1 major enhancement

  * Birthday!
