#!/usr/bin/perl

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";
&bib::format("refer","bibtex");

foreach $file (@ARGV) {
  next unless &bib::open($file);
  while ($record_refer = &bib::read($file) ) {
    $record_bibtex = &bib::convert($record_refer);
    &bib::write('-', $record_bibtex);
  }
  &bib::close($file);
}
