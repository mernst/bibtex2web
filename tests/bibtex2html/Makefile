# BIBDIR = ${HOME}/bib
# BIBFILES = ${BIBDIR}/bibstring-unabbrev.bib ${BIBDIR}/ernst.bib
BPHOME ?= ${HOME}/bin/src/perl/bibtex2web/lib
BWBIN = ${BPHOME}/../bin
# MDEWWW = ${HOME}/www

all: curly-braces.html

# The curly braces in the
curly-braces.html:
	touch ron-hotos2001-abstract.html
	${BWBIN}/bwconv.pl -format=bibtex,htmlpubs -outopts=withyears -author "David G. Andersen" -headfoot index-headfoot.html -to $@ curly-braces.bib

clean:
	rm curly-braces.html
