#
# bibliography package for Perl
#
# HTML routines
#
# Dana Jacobsen (dana@acm.org)
# 14 March 1996
#
#           All this is is a link to the output module.
#

### DEPRECATED: use htmlpubs -outopts=withyears instead

package bp_htmlpubswithyears;

$version = "html (dj 14 mar 96)";

# my $htmldir = "$ENV{HOME}/www/pubs";
my $htmldir = ".";

require "bp-s-generic.pl";
$bp_s_generic::titlefirst = 1;
$bp_s_generic::smartquotes = 1;

require "bp-htmlpubs.pl";

######

# $bib::cset = "html";

&bib::reg_format(
  'htmlpubswithyears',     # name
  'htmlpubswithyears',     # short name
  'bp_htmlpubswithyears',  # package name
  'html',     # default character set
  'suffix is html',
# functions
  'open      uses output',
  'close     uses output',
  'write     uses output',
  'clear     uses output',
  'read      uses output',
  'options   uses output',
  'implode   uses output',
  'explode   uses output',
  'tocanon   uses output',
#  'fromcanon uses output',
  'fromcanon',
);

######

sub make_header {
  my ($title) = @_;
  # returns <h2> $title </h2>
  return "${bib'cs_meta}2232" . $title . "${bib'cs_meta}2233";
}

my $lastyear = 0;

sub fromcanon {
    print "'htmlpubswithyears' is deprecated; use 'htmlpubs -outopts=withyears' instead\n";
  my (%entry) = @_;
  my %rec = &bp_htmlpubs::fromcanon(%entry);
  my $text = $rec{'TEXT'};
  if (defined $entry{'Year'}) {
      my $year = $entry{'Year'};
      if ($year ne $lastyear) {
          $text = make_header($year) . $text;
          $lastyear = $year;
      }
  }
  $rec{'TEXT'} = $text;
  %rec;
}

#######################
# end of package
#######################

1;
