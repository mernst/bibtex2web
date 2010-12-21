#!/usr/bin/env perl
# bwconv.pl: converter for bibtex2web system

use strict;
use English;
$WARNING = 1;

# For debugging
use Carp;

# Should really only do this if that entry doesn't already exist at the
# front of @INC.
if (defined $ENV{'BPHOME'}) {
  unshift(@INC, $ENV{'BPHOME'});
}
require "bp.pl";

&bib::errors('print', 'exit');

@ARGV = &bib::stdargs(@ARGV);

my @files;
my $outfile;
my $outdir;
my $header;
my $footer;
my $hfbodyline = "BODY";
my $copyright;
my $sortorder = "reverse_chronological";
my @categories;
my %linknames = ();
my %validurls = ();
my $author; # Only output matches for this author.
my $author_re; # Optional, also output any matches for this regexp.
my $filter; # Filter to apply but this expression overrides $author.

while (@ARGV) {
  $_ = shift @ARGV;
  /^--$/          && do { push(@files, @ARGV);  last; };
  /^-help$/       && do { &dieusage; };
  /^-to$/         && do { $outfile = shift @ARGV; next; };
  /^-todir$/      && do { $outdir = shift @ARGV; next; };
  /^-author$/     && do { $author = shift @ARGV;
                          if ($author =~ /^(.*?) \/(.*)\/$/) {
                            ($author, $author_re) = ($1, $2);
                          }
                          next; };
  /^-filter$/     && do { $filter = shift @ARGV; next; };
  /^-hfbodyline$/ && do { $hfbodyline = shift @ARGV; next; };
  /^-headfoot$/   && do { my $filename = shift @ARGV;
                          my $headtail = file_contents($filename);
                          if ($headtail !~ /^(.*\n)$hfbodyline\n(.*)$/s) {
                            die "Didn't find separator \"$hfbodyline\" in file $filename";
                          }
                          $header = $1;
                          $footer = $2;
                          next; };
  /^-header$/     && do { $header = file_contents(shift @ARGV);
                          next; };
  /^-footer$/     && do { $footer = file_contents(shift @ARGV);
                          next; };
  /^-copyright$/  && do { $copyright = file_contents(shift @ARGV);
                          next; };
  /^-linknames$/  && do { read_link_names(shift @ARGV);
                          next; };
  /^-validurls$/  && do { read_valid_urls(shift @ARGV);
                          next; };
  /^-categories$/ && do { my $categories = file_contents(shift @ARGV);
                          @categories = split('\n', $categories);
                          next; };
  /^-sort$/       && do { $sortorder = shift @ARGV; next; };
  /^-/            && do { print STDERR "Unrecognized option: $_\n";
                          &dieusage; };
  push(@files, $_);
}

# Note that unlike some programs like rdup, we can be used as a pipe, so
# we can't die with a usage output if we have no arguments.

# input from STDIN if nothing was specified.
unshift(@files, '-') unless @files;
# output to STDOUT if nothing was specified.
$outfile = '-' unless defined $outfile;
# check that if the file exists, we can write to it.
if (-e $outfile && !-w $outfile) {
  die "Cannot write to $outfile\n";
}
# check that we won't be overwriting any input files.
if ($outfile ne '-') {
  foreach my $file (@files) {
    next if $file eq '-';
    die "Will not overwrite input file $file\n" if $file eq $outfile;
  }
}

# Set input and output formats
my ($informat, $outformat) = &bib::format;
# $informat is not used!  (Is it?)

# clear errors.  Not really necessary.
&bib::errors('clear');

my ($reopen, $lastfmt);
# open the outfile if we know the type.
if ($outformat =~ /\bauto\b/) {
  $reopen = 1;
  $lastfmt = '';
} else {
  $reopen = 0;
  &bib::open('>' . $outfile) || die "Could not open $outfile\n";
}

my @records = ();
# Read all the files
foreach my $file (@files) {
  my $fmt = &bib::open($file);
  next unless defined $fmt;
  if ( ($reopen) && ($fmt ne $lastfmt) ) {
    &bib::close('>' . $outfile) unless $lastfmt eq '';
    &bib::open('>>' . $outfile) || die "Could not reopen $outfile\n";
    $lastfmt = $fmt;
  }
  my $rn = 0;
  while ( my $record = &bib::read ) {
    chop $record;
    $rn++;
    push @records, $record;
    # print STDERR "record: $record\n";

    # Set up crossref hash (which is not done correctly by bp-bibtex.pl.)
    if ($record !~ /^\s*\@\s*(\w+)\s*[\{\(]\s*(\S+)\s*,/ ) {
      print STDERR "Could not get key from record: $record\n";
    }
    my $id = $2;
    if (defined($bp_bibtex::glb_crossref_entries{$id})) {
      print STDERR "Duplicate entries for key $id\n";
    }
    # print STDERR "Setting up entry for $id\n";
    $bp_bibtex::glb_crossref_entries{$id} = $record;
  }
  my ($w, $e) = &bib::errors('totals');
  if ($w || $e) {
    print STDERR "$rn records read from $file";
    $w && print STDERR (($w == 1) ? " (1 warning)" : " ($w warnings)");
    $e && print STDERR (($e == 1) ? " (1 error)"   : " ($e errors)");
    print STDERR ".\n";
  }
  &bib::close;
}

# print STDERR "records (1): ", scalar(@records), "\n";

# Filter out records I don't care about.
# Remove records that are superseded.
if (defined($filter)) {
  @records = grep { my %rec = &bib::explode($_);
                    # print STDERR "filtering:\n";
                    # print STDERR %rec;
                    # Old filter was:
                    # ! (defined($rec{'omitfromcv'})
                    #    || (lc($rec{'TYPE'}) eq "lecture"));
                    eval $filter; }
                  @records;
}
# print STDERR "records (2): ", scalar(@records), "\n";
# print_records();
# print "defined(author): ", defined($author), "\n";
if (defined($author)) {
  @records = grep { my %rec = &bib::explode($_);
                    # print STDERR "author: $rec{'author'} for $rec{'title'}\n";
                    # print STDERR "editor: $rec{'editor'} for $rec{'title'}\n";
                    ((defined($rec{'author'})
                      && ($rec{'author'} =~ /\Q$author/o
                          || (defined($author_re)
                              && $rec{'author'} =~ /$author_re/o)))
                     || (defined($rec{'editor'})
                         && ($rec{'editor'} =~ /\Q$author/o
                             || (defined($author_re)
                                 && $rec{'editor'} =~ /$author_re/o)))
                     || (defined($rec{'pseudoauthor'})
                         && ($rec{'pseudoauthor'} =~ /\Q$author/o
                             || (defined($author_re)
                                 && $rec{'pseudoauthor'} =~ /$author_re/o))));
                  }
                  @records;
}

# print STDERR "records (3): ", scalar(@records), "\n";
# print_records();

###
### Sorting
###


# Also see hash bp-p-utils'month_table
my %month_abbrevs = ( "jan" => "01",
                      "feb" => "02",
                      "mar" => "03",
                      "apr" => "04",
                      "may" => "05",
                      "jun" => "06",
                      "jul" => "07",
                      "aug" => "08",
                      "sep" => "09",
                      "oct" => "10",
                      "nov" => "11",
                      "dec" => "12",
                      "winter" => "005",
                      "spring" => "035",
                      "summer" => "065",
                      "fall" => "095",
                      "autumn" => "095",
                      );


# Also see parsedate

sub yearmonth {
  my ($record) = @_;
  my %entry = &bib::explode($record);
  my $year;
  if (defined $entry{'year'}) {
    $year = $entry{'year'};
    if ($year !~ /^[12][0-9][0-9][0-9]$/) {
      die "Bad year `$year' in record: $record";
    }
  } else {
    # (! defined $entry{'year'})
    if (defined $entry{'note'} && ($entry{'note'} eq "To appear")) {
      # Not just "9999" because we want the sort to be predictable,
      # and multiple items might be "to appear".
      $year = "9999";
    } else {
      die "No year for record: $record";
    }
  }
  my $year_suffix = "";
  if (defined($entry{'month'})) {
    my $month = $entry{'month'};
    # Find the first thing that is plausibly a month.
    for my $candidate (keys %month_abbrevs) {
      # substitution enables looking for more matches earlier in month
      if ($month =~ s/\b$candidate(.*)$//i) {
        $year_suffix = $month_abbrevs{$candidate};
        # Look for days.  This assumes the days come after the month
        my $days = $1;
        if ($days =~ /\b([0123]?[0-9])\b/) {
          my $days = $1;
          $days =~ s/^([0-9])$/0$1/;
          $year_suffix .= $days;
        }
      }
    }
  } else {
    # print STDERR "No month in record: $record";
  }
  # avoid warnings about uninitialized values
  my $author = (defined($entry{'author'}) ? $entry{'author'} : "");

  # my $undefined_field = 0;
  # if (!defined($year)) { $undefined_field = 1; print STDERR "Undefined year\n"; $year = ""; }
  # if (!defined($entry{title})) { $undefined_field = 1; print STDERR "Undefined title\n"; $entry{title} = ""; }
  # if (!defined($author)) { $undefined_field = 1; print STDERR "Undefined author\n"; $author = ""; }
  # if ($undefined_field) {
  #   print STDERR "<<$year>><<$year_suffix>><<$entry{'title'}>><<$entry{'author'}>>\n";
  # }
  # print STDERR "Result = $year$year_suffix for $entry{'year'} $entry{'month'}\n";
  # print STDERR "<<$year>><<$year_suffix>><<$entry{'title'}>><<$entry{'author'}>>\n";
  # Add a further suffix because we want the sort to be predictable.
  if (!defined($year)) { $year = ""; }
  if (!defined($entry{'title'})) {
    # Could also print $record here.
    print STDERR "No title in record $entry{'CITEKEY'}";
  }
  return $year . $year_suffix . $entry{'title'} . $author;
}

sub byyearmonth {
  yearmonth($a) cmp yearmonth($b);
}

sub byyearmonth_reversed {
  yearmonth($b) cmp yearmonth($a);
}

# Find the index of a category in @categories.
# (Isn't there a built-in operator that will do this?)
sub catnum ( $ ) {
  my ($cat) = @_;
  for (my $i=0; $i<scalar(@categories); $i++) {
    if ($cat eq $categories[$i]) {
      # Add 100 to ensure 3 digits; we are sorting via a string comparison
      return $i+100;
    }
  }
  return "999 $cat";
}


sub bycategory {
  my %aentry = &bib::explode($a);
  my %bentry = &bib::explode($b);
  my $acat = $aentry{'category'};
  my $bcat = $bentry{'category'};
  if (!defined($acat)) { $acat = ""; }
  if (!defined($bcat)) { $bcat = ""; }
  my $acatnum = catnum($acat);
  my $bcatnum = catnum($bcat);
  return (($acatnum cmp $bcatnum)
          || byyearmonth($a, $b));
}


# Sort the records.
if ((! defined($sortorder))
    || $sortorder eq 'reverse_chronological') {
  @records = sort byyearmonth_reversed @records;
} elsif ($sortorder eq 'chronological') {
  @records = sort byyearmonth @records;
} elsif ($sortorder eq 'category') {
  @records = sort bycategory @records;
} else {
  die "Unrecognized sort order $sortorder";
}

# print STDERR "records (4): ", scalar(@records), "\n";


## Old technique
# {
#   my $sortfield = ...;
#   my %allrecs = ();
#   foreach my $record (@records) {
#     # Maybe do tocanon as well?
#     %entry = &bib::explode($record);
#     # this depends on newlines ending records.
#     # In the near future we will get either a new routine or some option
#     # to bib'write that will let us do this generically.
#     $allrecs{"$entry{$sortfield}"} .= "$record\n";
#   }
#   my @newrecords = ();
#   foreach my $record (sort keys %allrecs) {
#     push @newrecords, $record;
#   }
#   @records = @newrecords;
# }


###
### Superseding
###

# Set up datastructures to be used by ouput.

# Add list of papers it supersedes.  These are ordered the same way the
# whole list is.

my %citekeys = ();
foreach my $record (@records) {
  my %entry = &bib::explode($record);
  $citekeys{$entry{'CITEKEY'}} = $record;
}

# print STDERR "citekeys = ", join(" ", keys %citekeys), "\n";

# This refers to the final superseder, not the immediate superseder.
my %supersedes = ();
foreach my $record (@records) {
  my %entry = &bib::explode($record);
  my $superseded_key = $entry{'CITEKEY'};
  set_supersedes($superseded_key, $record, undef);
}

%bp_htmlbw::supersedes = %supersedes;
%bp_htmlbw::citekeys = %citekeys;
# print STDERR "linknames: " . scalar(%linknames) . "\n";
# print STDERR "validurls: " . scalar(%validurls) . "\n";
%bp_htmlabstract::linknames = %linknames;
%bp_htmlabstract::validurls = %validurls;
%bp_htmlbw::validurls = %validurls;

###
### More filtering
###

# Remove records that are superseded.
# This needs to come late because we use information in them above,
# to augment the supersedees.
@records = grep { my %rec = &bib::explode($_);
                  # print STDERR "superseding check: ", %rec, "\n";
                  ! (defined($rec{'supersededby'})) }
                @records;

# print STDERR "records (5): ", scalar(@records), "\n";


###
### Actual output
###

# This comes here because %bp_output... gets redefined when we read the
# format, so it can't be processed on the command line (I think).
{
  my $notice =
    "<!-- DO NOT EDIT: this file was generated by bibtex2web -->\n";
  if (defined($header)) {
    # "<!DOCTYPE..." must be the first thing in the webpage.
    $bp_output::headstr{'html'} = munge($header) . $notice;
  }
  if (defined($footer)) {
    $bp_output::tailstr{'html'} = munge($footer) . $notice;
  }
}

# Output the sorted records.
foreach my $record (@records) {
  # print STDERR "record: $record\n";
  my $recconv = &bib::convert($record);
  # print STDERR "recconv: $recconv\n";
  &bib::write($outfile, $recconv);
}

&bib::close('>' . $outfile);

exit(0);

###
### Subroutines
###

sub munge( $ ) {
    my ($text) = @_;
    my $timestamp = localtime();
    my $notice = "This page was generated $timestamp by "
        ."<a href=\"http://www.cs.washington.edu/homes/mernst/software/#bibtex2web\">"
        ."bibtex2web</a>";
    $text =~ s/BIBTEX2WEB_NOTICE/$notice/g;
    if (defined($copyright)) {
        $text =~ s/COPYRIGHT_NOTICE/$copyright/g;
    }
    return $text;
}

sub dieusage {
  my $prog = substr($0,rindex($0,'/')+1);

  my $str =<<"EOU";
Usage: $prog [<bp arguments>] [-to outfile] [bibfile ...]
  -to  Write the output to <outfile> instead of the standard out

  -bibhelp         general help with the bp package
  -supported       display all supported formats and character sets
  -hush            no warnings or error messages
  -debugging=#     set debugging on or off, or to a severity number
  -error_savelines warning/error messages also include the line number
  -informat=IF     set the input format to IF
  -outformat=OF    set the output format to OF
  -format=IF,OF    set the both the input and output formats
  -noconverter     always use the long conversion, never a special converter
  -csconv=BOOL     turn on or off character set conversion
  -csprot=BOOL     turn on or off character protection
  -inopts=ARG      pass ARG as an option to the input format
  -outopts=ARG     pass ARG as an option to the output format

  -header FILE     read HTML header from FILE
  -footer FILE     read HTML footer from FILE
  -headfoot FILE   read HTML header and footer from FILE, separated by "BODY"

Convert a Refer file to BibTeX:
        $prog  -format=refer,bibtex  in.refer  -to out.bibtex

Convert an Endnote file to an HTML document using the CACM style
        $prog  -format=endnote,output/cacm:html  in.endnote  -to out.html

EOU

  die $str;
}

sub file_contents {
  my ($file) = @_;
  {
    local(*CONTENTS, $/);
    open(CONTENTS, $file) or die "Couldn't open $file";
    my $result = <CONTENTS>;
    close(CONTENTS);
    return $result;
  }
}

sub read_link_names ( $ ) {
  my ($file) = @_;
  open(URLS, $file) or die "Couldn't open $file";
  my $line;
  while (defined($line = <URLS>)) {
    chomp $line;
    $line =~ s/ +$//;
    if ($line =~ /^$/) { next; }
    if ($line =~ /^#/) { next; }
    if ($line !~ /^(.*?) +([^ ]+)$/) {
      die "Didn't find space in link_names entry: '$line'";
    }
    if (defined $linknames{$1}) {
      warn "Multiple link_names entries for $1:\n old: $linknames{$1}\n new: $2\n";
    }
    $linknames{$1} = $2;
  }
  close(URLS);
  # print STDERR "read_link_names: " . scalar(%linknames) . "\n";
}

# FIXME: consolidate with bwconv.pl::read_link_names
sub read_valid_urls ( $ ) {
  my ($file) = @_;
  open(URLS, $file) or die "Couldn't open $file";
  my $line;
  while (defined($line = <URLS>)) {
    chomp $line;
    if ($line =~ /^$/) { next; }
    if ($line =~ /^\#/) { next; }
    if (defined $validurls{$line}) {
      warn "Duplicated URL in valid-urls file $file\n";
    }
    $validurls{$line} = 1;
  }
  close(URLS);
  # print STDERR "read_valid_urls: " . scalar(%validurls) . "\n";
  # for my $key (keys %validurls) {
  #   print STDERR "    $key\n";
  # }
}

sub set_supersedes ( $$$ ) {
  my ($superseded_key, $superseder, $how) = @_;
  # $superseder is a possibly non-final superseder; we will look for a
  # final superseder, or use it if it isn't itself superseded.
  # (This function is originally called with $superseded_key as the key for
  # record $superseder.)

  my %entry = &bib::explode($superseder);
  if (defined $entry{'supersededby'}) {
    for my $next_superseder (split(/\s*,\s*/, $entry{'supersededby'})) {
      if ($next_superseder =~ /^([^ ]+) (.*)$/) {
        $next_superseder = $1;
        $how = $2;
      }
      my $newrec = $citekeys{$next_superseder};
      if (! defined($newrec)) {
        die "Didn't find citekey $next_superseder which is referenced by $superseded_key";
      }
      # print STDERR "looked up $next_superseder and got: $newrec\n";
      # Try recursive call.
      set_supersedes($superseded_key, $newrec, $how);
    }
  } elsif (defined $entry{'supercededby'}) {
    print STDERR "$entry{'CITEKEY'} misspells 'supersededby' as 'supercededby'.\n";
  } else {
    my $superseder_key = $entry{'CITEKEY'};
    if ($superseded_key eq $superseder_key) {
      # print STDERR "$superseded_key is not superseded\n"
      # This was the original call; there is nothing to do.
    } else {
      # print STDERR "$superseded_key is superseded by $superseder_key\n";
      # I want an array here, but I'm having trouble, so just use a string and
      # split later.
      # push @$supersedes{$superseder_key}, $superseded_key;
      if (! defined($how)) {
        $how = "A previous version";
      }
      $supersedes{$superseder_key} .= "$superseded_key $how,";
      # print STDERR "$superseder_key supersedes $supersedes{$superseder_key}\n";
    }
  }
}

# Briefly print the contents of @records, for debugging.
sub print_records () {
  foreach my $record (@records) {
    my %entry = &bib::explode($record);
    my $message = $entry{"CITEKEY"};
    if (!defined($message)) {
      $message = $entry{"title"};
    }
    if (!defined($message)) {
      $message = $entry{"Title"};
    }
    print STDERR (defined($message) ? $message : %entry);
    print STDERR "\n";
    print STDERR %entry, "\n";
  }
}
