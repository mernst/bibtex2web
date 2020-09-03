
PERL=/usr/bin/perl

## FIXME: Note that these tests are not run if the Test.pl file is up to date.
Test.pl: .test ../lib/bp.pl
	$(PERL) Test.pl
	$(PERL) newcset.pl
	touch .test

time: timetest.pl timetest2.pl
	touch .time

timetest.pl: .time
	$(PERL) timetest.pl
	touch .time

timetest2.pl: .time
	$(PERL) timetest2.pl

.test .time:

clean:
	rm -f .time .test
