#!/usr/bin/perl

# bibcount, counts records using the bp package
#
# This is more complicated than it has to be because it includes speedups for
# some formats that have the type information directly in the record (BibTeX).
#
# Dana Jacobsen (dana@acm.org)   22 Jan 95

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

@ARGV = &bib::stdargs(@ARGV);

$usespecials = 1;        # use speedups for known formats
$printtype = 1;          # print totals by type also, if it's easy.

while (@ARGV) {
  $_ = shift @ARGV;
  last if /^--$/;
  /^-nospec/ && do { $usespecials = 0; next; };
  /^-type/   && do { $printtype = 2;   next; };
  /^-notype/ && do { $printtype = 0;   next; };
  push (@filelist, $_);
}

push(@filelist, @ARGV)  if @ARGV;
unshift(@filelist, '-')  unless @filelist;

foreach $file (@filelist) {
  next unless $fmt = &bib::open($file);
  $totrecs = 0;
  undef %type;
  if (($usespecials) && ($fmt eq 'bibtex') ) {
    &bib::close;
    open(BFILE, $file);
    while (<BFILE>) {
      next unless /^\s*\@/o;
      ($ty) = /^\s*\@\s*(\w+)/;
      $ty =~ tr/A-Z/a-z/;
      $type{$ty}++;
    }
    close(BFILE);
  } elsif (($usespecials) && ($fmt eq 'endnote') ) {
    &bib::close;
    open(BFILE, $file);
    while (<BFILE>) {
      next unless /^\%0/o;
      ($ty) = /^\%0 (.+)/;
      #$ty =~ tr/A-Z/a-z/;
      $type{$ty}++;
    }
    close(BFILE);
  } else {
    # Don't do character set conversion -- it often generates extrenuous
    # warnings, and also takes up some time we don't need to spend.
    &bib::options('csconv=no');
    while ($record = &bib::read) {
      if ($printtype > 1) {
        # to generically retrieve the type, we need to put the record into
        # canonical form, which unfortunately is pretty slow.
        %can = &bib::tocanon(&bib::explode($record));
        $type{$can{'CiteType'}}++;
      } else {
        $totrecs++;
      }
    }
    &bib::close;
  }
  if (%type) {
    $totrecs = 0;
    foreach $f (sort keys %type) {
      printf "%5d %s\n", $type{$f}, $f    if $printtype;
      $totrecs += $type{$f};
    }
  }
  print "$file has $totrecs records.\n";
}
