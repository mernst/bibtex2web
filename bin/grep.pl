#!/usr/bin/perl

# bibgrep, searches bibliographies using the bp package
#
# Dana Jacobsen (dana@acm.org)   22 Jan 95

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

@ARGV = &bib::stdargs(@ARGV);

$field = undef;
$casesen = 1;

while (@ARGV) {
  $_ = shift @ARGV;
  last if /^--$/;
  /^-f/ && do { $field = shift @ARGV;   next; };
  /^-i/ && do { $casesen = 0; next; };
  /^-help$/ && do { &dieusage; };
  push (@filelist, $_);
}

push(@filelist, @ARGV)  if @ARGV;

&dieusage unless @filelist;

$regex = shift @filelist;

($ifmt) = &bib::format();
($fmt, $cset) = &bib::parse_format($ifmt);
&bib::format("$fmt:$cset", "$fmt:none");

if (!@filelist) {
  if (defined $ENV{'BIBINPUTS'}) {
    # real ugly way to get the suffix to look for
    $suffix = $bib::formats{$fmt, 'i_suffix'};
    # walk through the directories looking for files.
    foreach $dir (split(/:/, $ENV{'BIBINPUTS'})) {
      next unless opendir(BDIR, $dir);
      foreach $f (grep(/\.$suffix$/, readdir(BDIR))) {
        push(@filelist, $dir . '/' . $f);
      }
      closedir(BDIR);
    }
    &bib::goterror("No files *.$suffix in BIBINPUTS") unless @filelist;
  }
}

&dieusage unless @filelist;

foreach $file (@filelist) {
  next unless &bib::open($file);
  while ($record = &bib::read) {
    if (defined $field) {
      %ent = &bib::explode($record);
      $line = $ent{$field};
      next unless defined $line;
    } else {
      $line = $record;
    }
    $line =~ s/\n/ /g;
    $line =~ s/\s+/ /g;

    $ncsline = &bib::convert($line);
   #$func = $bib::charsets{$cset, 'tocanon'};
   #$csline = &$func($line, $bib::opt_CSProtect);
   #$ncsline = &bp_util::nocharset($csline);

    if ($casesen) {
      $ncsline =~ /$regex/  && print $record, "\n";
    } else {
      $ncsline =~ /$regex/i && print $record, "\n";
    }
  }
}

sub dieusage {
  my $prog = substr($0,rindex($0,'/')+1);

  $str =<<"EOU";
Usage: $prog [-f field] perl-regex [bibfile ...]
EOU

  die $str;
}
