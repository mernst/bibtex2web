#
# Makefile for bibtex2web, which is an extension of bp.
#

# Set this to where you want bp installed.  Choices include:
# 1) your standard perl library path, usually /usr/lib/perl.
# 2) your site-specific perl library path, often /usr/lib/perl/site_perl
# 3) a completely new place, such as /usr/local/lib/bp
# 4) leave them here in the source directory
# options 3 and 4 will require that the environment variable BPHOME be set
# to run any bp programs, but I prefer them.

# BPHOME = /usr/lib/perl
# BPHOME = /usr/local/lib/bp

# Set this to where you want the included perl scripts to be installed.
BINDEST = /usr/local/bin

# This is the prefix that will be used for the perl scripts.
BINPREF = bib

test:
	(cd tests; make)

install: install.lib install.bin

install.lib:
	test -d $(BPHOME) || mkdir $(BPHOME)
	install -m 644 lib/*.pl $(BPHOME)

install.bin:
	install -m 755 bin/conv.pl  $(BINDEST)/$(BINPREF)conv
	install -m 755 bin/count.pl $(BINDEST)/$(BINPREF)count
	install -m 755 bin/grep.pl  $(BINDEST)/$(BINPREF)grep
	install -m 755 bin/rdup.pl  $(BINDEST)/$(BINPREF)rdup
	install -m 755 bin/sort.pl  $(BINDEST)/$(BINPREF)sort

TAGS: tags

tags:
	etags `find . -name '*.pl' | grep -v old`

tar: ../bibtex2web.tar.gz

../bibtex2web.tar.gz: . lib
	cd ..; find bibtex2web -name '*~' -o -name '#*#' -o -name '.#*' -o -name TAGS -o -name CVS > bibtex2web-exclude
	cd ..; tar czf bibtex2web.tar.gz --exclude-from bibtex2web-exclude  bibtex2web
	rm ../bibtex2web-exclude

dist: ../bibtex2web.tar.gz
	cp -pf $< ${HOME}/www/software/
	cp -pf bibtex2web.html ${HOME}/www/software/
	$(MAKE) -C ${HOME}/www/software/ linkdates
