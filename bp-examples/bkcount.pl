#!/usr/bin/perl

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

&bib::format("bibtex");

&bib::errors("print", "exit");

foreach $file (@ARGV) {
  next unless &bib::open($file);
  while ( $record = &bib::read($file) ) {
    %entry = &bib::explode($record);

    if ( defined($entry{'read'}) ) {
      $totpages{$entry{'read'}} += $entry{'pages'};
      $totbooks{$entry{'read'}}++;
    }
  }
  &bib::close($file);

  foreach $date (sort keys %totpages) {
    printf "%15s: %3d books, %5d pages, %3.2f pages/book\n",
           $date, $totbooks{$date}, $totpages{$date},
           $totpages{$date}/$totbooks{$date};
    $Tbooks += $totbooks{$date};
    $Tpages += $totpages{$date};
    $Tmonths++;
  }
  printf "Total %2d months: %3d books, %5d pages, %3.2f pages/book, %4.2f pages/month\n",
    $Tmonths, $Tbooks, $Tpages, $Tpages/$Tbooks, $Tpages/$Tmonths;
}
