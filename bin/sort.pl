#!/usr/bin/perl

# We want to find BP wherever it lives.
unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
# load the package
require "bp.pl";

# parse BP's arguments, like informat, outformat, etc.
@ARGV = &bib::stdargs(@ARGV);

# walk through the arguments.
while (@ARGV) {
  $_ = shift @ARGV;
  last if /^--$/;
  /^-f/   && do { $field = shift @ARGV; next; };
  push (@filelist, $_);
}

# if they told us to stop parsing arguments, this will be true.
push(@filelist, @ARGV)  if @ARGV;

# We don't have a default sort field.
die "You must specify a sort field with -f <field>.\n" unless defined $field;

# With no files, we read from stdin
unshift(@filelist, '-')  unless @filelist;

foreach $file (@filelist) {
  next unless &bib::open($file);
  while ($record = &bib::read) {
    %entry = &bib::explode($record);
    # this depends on newlines ending records.
    # In the near future we will get either a new routine or some option
    # to &bib::write that will let us do this generically.
    $allrecs{"$entry{$field}"} .= "$record\n";
  }
  &bib::close;
}
foreach $rec (sort keys %allrecs) {
  print $allrecs{$rec};
}
