#!/usr/bin/perl
# conv.pl -- convert bibliographies to a variety of output formats

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

&bib::errors('print', 'exit');

@ARGV = &bib::stdargs(@ARGV);

while (@ARGV) {
  $_ = shift @ARGV;
  /^--$/      && do { push(@files, @ARGV);  last; };
  /^-help$/   && do { &dieusage; };
  /^-to/      && do { $outfile = shift @ARGV; next; };
  /^-/        && do { print STDERR "Unrecognized option: $_\n"; next; };
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
  foreach $file (@files) {
    next if $file eq '-';
    die "Will not overwrite input file $file\n" if $file eq $outfile;
  }
}

# print out a little message on the screen
($informat, $outformat) = &bib::format;
print STDERR "This is bp, version ", &bib::doc('version'), ".\n";
print STDERR "Reading: $informat  Writing: $outformat\n";
print STDERR "\n";

# clear errors.  Not really necessary.
&bib::errors('clear');

# open the outfile if we know the type.
if ($outformat =~ /\bauto\b/) {
  $reopen = 1;
  $lastfmt = '';
} else {
  $reopen = 0;
  &bib::open('>' . $outfile) || die "Could not open $outfile\n";
}

foreach $file (@files) {
  $fmt = &bib::open($file);
  next unless defined $fmt;
  if ( ($reopen) && ($fmt ne $lastfmt) ) {
    &bib::close('>' . $outfile) unless $lastfmt eq '';
    &bib::open('>>' . $outfile) || die "Could not reopen $outfile\n";
    $lastfmt = $fmt;
  }
  $rn = 0;
  while ( $record = &bib::read ) {
    chop $record;
    $rn++;
    $recconv = &bib::convert($record);
    &bib::write($outfile, $recconv);
  }
  ($w, $e) = &bib::errors('totals');
  # print STDERR "$rn records read from $file";
  $w && print STDERR (($w == 1) ? " (1 warning)" : " ($w warnings)");
  $e && print STDERR (($e == 1) ? " (1 error)"   : " ($e errors)");
  print STDERR ".\n";
  &bib::close;
}

&bib::close('>' . $outfile);


sub dieusage {
  my $prog = substr($0,rindex($0,'/')+1);

  $str =<<"EOU";
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

Convert a Refer file to BibTeX:
	$prog  -format=refer,bibtex  in.refer  -to out.bibtex

Convert an Endnote file to an HTML document using the CACM style
	$prog  -format=endnote,output/cacm:html  in.endnote  -to out.html

EOU

  die $str;
}

