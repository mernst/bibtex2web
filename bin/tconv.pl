#!/usr/bin/perl

$testcanon = 0;
$debprint = 0;
$convert = 0;
$compare = 0;
$dump = 0;

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

&bib::errors('print', 'exit');

@ARGV = &bib::stdargs(@ARGV);

while (@ARGV) {
  $_ = shift @ARGV;
  /^--$/      && do { push(@files, @ARGV);  last; };
  /^-D/       && do { $debprint = 1; next; };
  /^-canon/   && do { $testcanon = 1; next; };
  /^-convert/ && do { $convert = 1; next; };
  /^-compare/ && do { $convert = 1; $compare = 1; next; };
  /^-to/      && do { $outfile = shift @ARGV; next; };
  /^-dump$/   && do { $dump = 1; next; };
  if (/^-/) {
    print STDERR "Unrecognized option: $_\n";
    next;
  }
  push(@files, $_);
}

unshift(@files, '-') unless @files;
$outfile = '-' unless defined $outfile;
if (-e $outfile && !-w $outfile) {
  die "Cannot write to $outfile\n";
}
foreach $file (@files) {
  next if ( ($file eq '-') || ($outfile eq '-') );
  die "Will not overwrite input file $file\n" if $file eq $outfile;
}

print STDERR "This is bp, version ", &bib::doc('version'), ".\n";
($informat, $outformat) = &bib::format;
print STDERR "Reading: $informat  Writing: $outformat\n";
print STDERR "\n";
&bib::errors('clear');
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
   if ($dump) {
     print STDERR "file $file with format $fmt\n";
     &bib::debug_dump('all');
   }
   $rn = 0;
   while ( $record = &bib::read ) {
      chop $record;
      $rn++;

      if ($convert) {
         $recconv = &bib::convert($record);
      }
      if ( (!$convert) || ($compare) ) {
         $debprint && print "\n\n-----\n\nrecord $rn, as read:\n";
         $debprint && print $record, "\n";

         %ent = &bib::explode($record);
         $debprint && print "\n\n-----\n\nrecord $rn, in $informat format:\n";
         $debprint && &show(%ent);

         if ($testcanon) {
            %can = &bib::tocanon(%ent);
            $debprint && print "\n\nrecord $rn, in canon format:\n";
            $debprint && &show(%can);

            undef %ent;
            %ent = &bib::fromcanon(%can);
            $debprint && print "\n\nrecord $rn, in $outformat format:\n";
            $debprint && &show(%ent);
         }
         $recout = &bib::implode(%ent);
         $debprint && print "\n\nrecord $rn, using $outformat write:\n";
      }
      if ($compare) {
        if ($recconv ne $recout) {
          print "conv:\n$recconv\nlong:\n$recout\n";
        }
      } else {
        if ($convert) {
          &bib::write($outfile, $recconv);
        } else {
          &bib::write($outfile, $recout);
        }
      }
   }
   ($w, $e) = &bib::errors('totals');
   $wstring = "";
   $estring = "";
   $wstring = " ($w warning)" if $w == 1;
   $wstring = " ($w warnings)" if $w > 1;
   if ($e > 0) {
     $estring = " ($e errors)";
   }
   # print STDERR "$rn records read from $file$wstring$estring.\n";
   &bib::close;
}

&bib::close('>' . $outfile);
&bib::debug_dump('all') if $dump;

sub show {
   my %array = @_;

   foreach $key (sort keys %array) {
      print $key, ' = ', $array{$key}, "\n";
   }
}
