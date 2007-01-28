#!/usr/bin/env perl
# Arguments: authorfile linknameurlfile headfootfile bibfile ...
#   "authorfile" is a list, one name per line, of authors.
#     Optionally, each author name may be followed by a URL to that person's
#     additional publications.
#   "linknameurlfile" maps authors/institutions/etc. to URLs.
#   "headfootfile" contains text for the header and footer of the output file.

use strict;
use English;
$WARNING = 1;
use Carp;

my $debug = 0;
# $debug = 1;

my $filter = "";

while (@ARGV) {
  $_ = shift @ARGV;
  /^-filter$/     && do { $filter = shift @ARGV;
                          my $fq = shell_quote($filter);
                          $filter = "-filter '$fq'";
                          next; };
  /^-/            && do { print STDERR "Unrecognized option: $_\n";
                          &dieusage; };
  unshift(@ARGV, $_);
  last;
}

# Maybe these should be flags too, but they are always required.
my $authorfile = shift @ARGV;
my $linknamefile = shift @ARGV;
my $byauthor_headfootfile = shift @ARGV;
if (scalar(@ARGV) == 0) {
  die "No bib files supplied";
}
my $BIBFILES = join(' ', @ARGV);

my %linknames = ();
read_link_names($linknamefile);

my @authors;

my $byauthor_header;
my $byauthor_footer;
{
  my $headtail = file_contents($byauthor_headfootfile);
  $headtail =~ /^(.*\n)BODY\n(.*)$/s;
  $byauthor_header = $1;
  $byauthor_footer = $2;
}

my $bwconv_program = $PROGRAM_NAME;
$bwconv_program =~ s/make-author-pages\.pl/bwconv.pl/;


open(AUTHORS, $authorfile) or die "Can't open '$authorfile': $!";
while (<AUTHORS>) {
  if (/^ *\#/) { next; }
  if (/^ *$/) { next; }
  chomp;
  my $author = $_;
  my $author_pubs_url;
  if ($author =~ /^(.*?)[ \t]+(http:.*)$/) {
    ($author, $author_pubs_url) = ($1, $2);
  }
  my $author_with_regexp = $author;
  my $author_re;
  if ($author =~ /^(.*?) \/(.*)\/$/) {
    ($author, $author_re) = ($1, $2);
  }
  my $author_html = author_as_html($author);
  my $author_link;
  if (defined $linknames{$author_html}) {
    my $url = $linknames{$author_html};
    $author_link = "<a href=\"$url\">$author_html</a>";
  } else {
    $author_link = $author_html;
  }
  if ($debug) {
    print STDERR "author: $author\n  author_with_regexp: $author_with_regexp\n  link: $author_link\n";
  }
  if (defined($author_pubs_url)) {
    $author_pubs_url =
      "<br /><b>For a full list</b>, see <a href=\"$author_pubs_url\">$author_pubs_url</a>.";
  } else {
    $author_pubs_url = "";
  }
  my $filename_base = author_as_filename($author);
  my $filename = "$filename_base.html";
  my $this_headfootfile = "$filename_base-headfoot.html";

  {
    my $alq = shell_quote($author_link);
    my $ahq = shell_quote($author_html);
    my $apuq = shell_quote($author_pubs_url);
    ## Substitute for AUTHOR_LINK, AUTHOR_HTML, and AUTHOR_PUBS.
    system_or_die("perl -p -e 's|AUTHOR_LINK|$alq|g; s|AUTHOR_HTML|$ahq|g; s|AUTHOR_PUBS|$apuq|;' < author-headfoot.html > $this_headfootfile");
    ## Alternate implementation:
    # ## Don't call perl externally because of potential problems with quoting
    # ## the names (they might contain single- or double-quote characters).
    # open(AUTHOR_HEADFOOT, "author-headfoot.html") or die "Can't open 'author-headfoot.html': $!";
    # open(THIS_HEADFOOT, ">$this_headfootfile") or die "Can't open '$this_headfootfile': $!";
    # while (<AUTHOR_HEADFOOT>) {
    #   s|AUTHOR_LINK|$author_link|g;
    #   s|AUTHOR_HTML|$author_html|g;
    #   s|AUTHOR_PUBS|$author_pubs_url|g;
    #   print THIS_HEADFOOT $_;
    # }
    # close(AUTHOR_HEADFOOT);
    # close(THIS_HEADFOOT);
  }

  unlink "outfile.txt";
  # Quote any single-quote marks to protect them from the shell.  (Yuck.)
  my $author_quoted = shell_quote($author_with_regexp);
  my $command = "$bwconv_program -format=bibtex,htmlpubs -author '$author_quoted' -headfoot $this_headfootfile -to $filename $filter ${BIBFILES} >& outfile.txt";
  # print $command . "\n";
  ## Inline system_or_die so we can print file "outfile.txt".
  # system_or_die($command);
  { my $result = system($command);
    if ($result != 0)
      { system_or_die("cat outfile.txt");
        die "Failed executing $command"; }
  }
  unlink "outfile.txt";
  unlink $this_headfootfile;
  if (-z $filename) {
    unlink $filename;
    # print STDERR "No publications for $author_with_regexp\n";
  } else {
    # What is the point of this test?  It doesn't seem to be used.
    $author =~ s/[{}]//g;
    push @authors, $author_html;
  }
}
close(AUTHORS);

print $byauthor_header;
for my $author (@authors) {
  print "<a href=\"" . author_as_filename($author) . ".html\">$author</a><br />\n";
}
print $byauthor_footer;

exit;

###########################################################################
### Subroutines
###

# Argument is in HTML form.
sub author_as_filename ( $ ) {
  my ($author) = @_;
  $author =~ s/&\#0380;/z/g;
  $author =~ s/[\\\'\{\}.]//g;
  $author =~ s/ /-/g;
  return $author;
}

# This is partial and a hack.  Should use character set conversion instead.
sub author_as_html ( $ ) {
  my ($author) = @_;
  $author =~ s/{\\\.z}/&\#0380;/g; # For Adam Kiezun
  $author =~ s/[{}]//g;         # For grouped names: "Toh {Ne Win}"
  return $author;
}

# Execute the command; die if its execution is erroneous.
sub system_or_die ( $ )
{ my ($cmd) = @_;
  my $result = system($cmd);
  if ($result != 0)
    { croak "Failed executing $cmd"; }
  return $result;
}

# FIXME: consolidate with bwconv.pl::read_link_names
sub read_link_names ( $ ) {
  my ($file) = @_;
  open(URLS, $file) or die "Couldn't open $file";
  my $line;
  while (defined($line = <URLS>)) {
    chomp $line;
    if ($line =~ /^$/) { next; }
    if ($line =~ /^\#/) { next; }
    $line =~ /^(.*?) +([^ ]+)$/;
    if (defined $linknames{$1}) {
      warn "URL redefinition for $1:\n old: $linknames{$1}\n new: $2\n";
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

# Given a string, return a string that can be put inside single-quote
# characters in a shell command.  It doesn't add the surrounding
# single-quotes, though.
sub shell_quote {
  my ($string) = @_;
  $string =~ s/\'/\'\"\'\"\'/;
  return $string;
}
