#!/usr/bin/perl

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

while (@ARGV) {
  $_ = shift @ARGV;
  /^--$/  && do { push (@filelist, @ARGV); undef @ARGV; next; };
  /^-f/   && do { $field = shift @ARGV; next; };
  push (@filelist, $_);
}
die "You must specify a sort field with -f.\n" unless defined $field;
foreach $file (@filelist) {
  next unless &bib::open($file);
  while ($record = &bib::read($file) ) {
    %entry = &bib::explode($record);
    $allrecs{"$entry{$field}"} .= $record . "\n";
  }
  &bib::close($file);
}
foreach $rec (sort keys %allrecs) {
  print $allrecs{$rec};
}
