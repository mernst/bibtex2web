###########################################################################

# To use this file, just run "make".
# You generally don't want to use the other targets.

# Customization: you must update the BIBFILES variable.
BIBFILES = /home/jruser/bib1.bib /home/jruser/bib2.bib

###########################################################################

BWBIN = ${BPHOME}/../bin

html: HTML

HTML: abstracts index.html bytopic.html byauthor.html

index.html:
	${BWBIN}/bwconv.pl -format=bibtex,htmlpubs -outopts=withyears -headfoot index-headfoot.html -to $@ -filter '! (defined($$rec{"omitfromcv"}) || (lc($$rec{"TYPE"}) eq "lecture") || (defined($$rec{"crossrefonly"}) && ! defined($$rec{"inlined-crossref"})))' ${BIBFILES}

bytopic.html:
	${BWBIN}/bwconv.pl -format=bibtex,htmlsummary -headfoot bytopic-headfoot.html -categories research-index-categories -sort category -to $@ -filter '! (defined($$rec{"omitfromcv"}) || (lc($$rec{"TYPE"}) eq "lecture") || (defined($$rec{"crossrefonly"}) && ! defined($$rec{"inlined-crossref"})))' ${BIBFILES}
	html-update-toc $@

# Creates *-abstract.html files.  (A better name would be *-details.html
# files, since they contain more than just the abstract and are created
# even if a given BibTeX entry doesn't contain an abstract.)
abstracts:
	${BWBIN}/bwconv.pl -format=bibtex -outformat=htmlabstract -outopts=withbibtex -to abstracts-unsplit.html -linknames link-names -filter '! (defined($$rec{"omitfromcv"}) || (lc($$rec{"TYPE"}) eq "lecture") || (defined($$rec{"crossrefonly"}) && ! defined($$rec{"inlined-crossref"})))' ${BIBFILES}
	${BWBIN}/htmlabstract-split.pl -headfoot abstract-headfoot.html abstracts-unsplit.html
	rm abstracts-unsplit.html

byauthor.html:
	${BWBIN}/make-author-pages.pl authors author-urls byauthor-headfoot.html ${BIBFILES} > $@

.PHONY: abstracts index.html bytopic.html byauthor.html
