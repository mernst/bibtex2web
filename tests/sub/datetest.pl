#!/usr/bin/perl

if ( (!defined $intest) || ($intest != 1) ) {
  unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
  require "bp.pl";
}

$failed = 0;
print "testing bp_util'parsedate..........................";

open(DFILE, "data/dates.dat") || die "datetest: can't open data file.\n";

while (<DFILE>) {
  $idate = <DFILE>;
  $cdate = <DFILE>;
  chop($idate, $cdate);

  $odate = '';
  @oda = &bp_util::parsedate($idate);
  # Next two lines to prevent touching undefined data
  $oda[0] = '' unless defined $oda[0];
  $oda[1] = '' unless defined $oda[1];
  $odate = join('/', @oda);

  $failed++ unless $odate eq $cdate;
  if ($odate ne $cdate) {
    print "\n";
    print "got: $idate\n";
    print "out: $odate\n";
    print "can: $cdate\n";
  }
}

if ($failed) {
  print "$failed errors\n";
} else {
  print "ok\n";
}
