#!/usr/bin/perl

if ($intest != 1) {
  unshift(@INC,  $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
  require "bp.pl";
}

&bib::errors('print', 'print');

print STDERR "options\n";
&bib::options('debug=1');
print STDERR "debugging is $bib::glb_debug\n";

&bib::options('foo');

print STDERR "blank read\n";
&bib::read;

print STDERR "read unopened file\n";
&bib::read("../ref/ad425.ref");
