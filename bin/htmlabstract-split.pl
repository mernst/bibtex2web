#!/usr/bin/env perl

use strict;
use English;
$WARNING = 1;

use Text::Wrap qw(wrap $columns $huge);
$Text::Wrap::columns = 75;
$Text::Wrap::huge = 'overflow';

# Use current directory rather than hard-coding.
# my $htmldir = $ENV{"HOME"} . "/www/pubs";
my $htmldir = ".";

my $footer;
if ($ARGV[0] eq "-footer") {
  shift @ARGV;
  $footer = file_contents(shift @ARGV);
}

while (<>) {
  if (/NEWFILE: ([^ ]+) (.*)$/) {
    my ($basefile, $title) = ($1, $2);
    my $absfile = "$htmldir/$basefile-abstract.html";
    # print STDERR "basefile $basefile title $title\nabsfile $absfile\n";
    open(ABSFILE, ">$absfile") or die "Can't open $absfile";
    print ABSFILE "<html>
<head>
<title>$title</title>
</head>
<body>

<h1>$title</h1>

";
    my $line;
    while ($line = <>) {
      if ($line eq "ENDFILE\n") {
	last;
      }
      if ((length($line) > 80) && ($line !~ /^[\`<]/)) {
	if ($line =~ /^by /) {
	  $line =~ s/ (<A href=)/\n$1/g;
	  $line =~ s/(<\/A>,) /$1\n/g;
	  $line =~ s/(<\/A>) and /$1\nand\n/g;
	  $line =~ s/(<\/A>) and/$1\nand/g;
	} else {
	  $line =~ s/^ *//;
	  $line = join("\n", Text::Wrap::wrap("", "", $line));
	}
      }
      print ABSFILE $line;
    }
    if (defined($footer)) {
      print ABSFILE $footer;
    }
    print ABSFILE "\n</body>\n</html>\n";
    close(ABSFILE);
  }
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

