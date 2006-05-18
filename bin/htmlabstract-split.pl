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

# Default header and footer.
my $header = "<html>
<head>
<title>PUB_TITLE</title>
</head>
<body>

<h1>PUB_TITLE</h1>

";
my $footer = "\n</body>\n</html>\n";

if ($ARGV[0] eq "-headfoot") {
  shift @ARGV;
  my $headfootfile = shift @ARGV;
  my $headtail = file_contents($headfootfile);
  if ($headtail !~ /^(.*\n)BODY\n(.*)$/s) {
    die "Didn't find \"BODY\" in $headfootfile";
  }
  $header = $1;
  $footer = $2;
}

# Use of "-footer" is deprecated.
if ($ARGV[0] eq "-footer") {
  print STDERR "Use of '-footer' option is deprecated; use '-headfoot' instead.";
  shift @ARGV;
  $footer = file_contents(shift @ARGV);
}

while (<>) {
  if (/NEWFILE: ([^ ]+) (.*)$/) {
    my ($basefile, $title) = ($1, $2);
    my $absfile = "$htmldir/$basefile-abstract.html";
    # print STDERR "basefile $basefile title $title\nabsfile $absfile\n";
    open(ABSFILE, ">$absfile") or die "Can't write $absfile";
    my $this_header = $header;
    $this_header =~ s/PUB_TITLE/$title/g;
    print ABSFILE $this_header;
    my $line;
    while ($line = <>) {
      if ($line eq "ENDFILE\n") {
	last;
      }
      if ((length($line) > 80) && ($line !~ /^[\`<]/)) {
	if ($line =~ /^by /) {
	  $line =~ s/ (<a href=)/\n$1/g;
	  $line =~ s/(<\/a>,) /$1\n/g;
	  $line =~ s/(<\/a>) and /$1\nand\n/g;
	  $line =~ s/(<\/a>) and/$1\nand/g;
	} else {
          # Wrap the line.
          # If we are in a BibTeX entry, then special-case this.
          if ($line =~ /^   \w+ = \{/) {
            $line = join("\n", Text::Wrap::wrap("", "        ", $line));
          } else {
            # Ordinary line wrapping.
            $line =~ s/^ *//;
            $line = join("\n", Text::Wrap::wrap("", "", $line));
          }
	}
      }
      print ABSFILE $line;
    }
    my $this_footer = $footer;
    $this_footer =~ s/PUB_TITLE/$title/g;
    print ABSFILE $this_footer;
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

