#!/usr/bin/perl

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";
&bib::format("auto");

foreach $file (@ARGV) {
  next unless &bib::open($file);
  $totrecs = 0;
  while ($record = &bib::read($file) ) {
    $totrecs++;
  }
  &bib::close($file);
  print "$file has $totrecs records.\n";
}
