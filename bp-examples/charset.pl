#!/usr/bin/perl

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

&bib::format('text:troff', 'text:tex');

@ARGV = &bib::stdargs(@ARGV);

unshift(@ARGV, '-') unless @ARGV;

foreach $file (@ARGV) {
  next unless &bib::open($file);
  while ( $rec = &bib::read ) {
    $out_rec = &bib::convert($rec);
    &bib::write('-', $out_rec);
  }
  &bib::close;
}

