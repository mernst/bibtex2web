
PERL=/usr/bin/perl

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
