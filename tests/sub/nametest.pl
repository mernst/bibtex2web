#!/usr/bin/perl

$| = 1;

if ($intest != 1) {
  unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
  require "bp.pl";
}

sub failp {
  local($should, $did) = @_;

  print "\n         got:  '$did'";
  print "\n should have:  '$should'";
  print "\n";
}

$failed = 0;
print "testing bp_util'mname_to_canon.....................";

open(NAMEFILE, "data/namesm.dat") || die "nametest: can't open data file.\n";

while (<NAMEFILE>) {
  $rname = <NAMEFILE>;
  $cname = <NAMEFILE>;
  chop($rname, $cname);
  &fixcname;

  $ncname = &bp_util::mname_to_canon($rname);

  next if $cname eq $ncname;

  $failed++;
  &failp($cname, $ncname);
}
close(NAMEFILE);

print (($failed) ? "$failed errors\n" : "ok\n");

$failed = 0;
print "testing bp_util'name_to_canon......................";

open(NAMEFILE, "data/names.dat") || die "nametest: can't open data file.\n";

while (<NAMEFILE>) {
  $rname = <NAMEFILE>;
  $cname = <NAMEFILE>;
  chop($rname, $cname);
  &fixcname;

  $ncname = &bp_util::name_to_canon($rname);

  next if $cname eq $ncname;

  $failed++;
  &failp($cname, $ncname);
}
close(NAMEFILE);

print (($failed) ? "$failed errors\n" : "ok\n");

$failed = 0;
print "testing bp_util'name_to_canon..............(long)..";

$bp_util::opt_complex = 10;

open(NAMEFILE, "data/n2.dat") || die "nametest: can't open data file.\n";

while (<NAMEFILE>) {
  $rname = <NAMEFILE>;
  $cname = <NAMEFILE>;
  chop($rname, $cname);
  &fixcname;

  $ncname = &bp_util::name_to_canon($rname);

  # protect in TeX fashion
  local($last, $rest) = split($bib::cs_sep2, $ncname, 2);
  $ncname = "\{$last\}$bib::cs_sep2$rest" if $last =~ / /;

  next if $cname eq $ncname;

  $failed++;
  &failp($cname, $ncname);
}
close(NAMEFILE);

print (($failed) ? "$failed errors\n" : "ok\n");

sub fixcname {
  $cname =~ s#/#$bib::cs_sep2#go;
  $cname =~ s#\|\|#$bib::cs_sep#go;
  $cname =~ s/~/\240/g;
  $rname =~ s/~/\240/g;
}
