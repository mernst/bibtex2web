###########################################################################

# Customization: you must update the BIBFILES variable.
BIBFILES = /home/jruser/bib1.bib /home/jruser/bib2.bib

###########################################################################

BWBIN = ${BPHOME}/../bin

html: HTML

HTML: abstracts index.html bytopic.html byauthor.html

index.html:
	${BWBIN}/bwconv.pl -format=bibtex,htmlpubs -headfoot index-headfoot.html -to $@ -filter '! (defined($$rec{"omitfromcv"}) || (lc($$rec{"TYPE"}) eq "lecture") || (defined($$rec{"crossrefonly"}) && ! defined($$rec{"inlined-crossref"})))' ${BIBFILES}

bytopic.html:
	${BWBIN}/bwconv.pl -format=bibtex,htmlsummary -headfoot bytopic-headfoot.html -categories research-index-categories -sort category -to $@ -filter '! (defined($$rec{"omitfromcv"}) || (lc($$rec{"TYPE"}) eq "lecture") || (defined($$rec{"crossrefonly"}) && ! defined($$rec{"inlined-crossref"})))' ${BIBFILES}
	html-update-toc $@

# Creates *-abstract.html files.
abstracts:
	${BWBIN}/bwconv.pl -format=bibtex -outformat=htmlabstract -to abstracts-unsplit.html -authorurls author-urls -filter '! (defined($$rec{"omitfromcv"}) || (lc($$rec{"TYPE"}) eq "lecture") || (defined($$rec{"crossrefonly"}) && ! defined($$rec{"inlined-crossref"})))' ${BIBFILES}
	${BWBIN}/htmlabstract-split.pl -headfoot abstract-headfoot.html abstracts-unsplit.html
	rm abstracts-unsplit.html

byauthor.html:
	${BWBIN}/make-author-pages.pl authors author-urls byauthor-headfoot.html ${BIBFILES} > $@

.PHONY: abstracts index.html bytopic.html byauthor.html
