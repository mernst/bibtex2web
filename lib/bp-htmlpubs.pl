#
# bibliography package for Perl
#
# HTML routines
# Use "-outopts=withyears" option to separate the output by years.
#
# Dana Jacobsen (dana@acm.org)
# 14 March 1996
#
#           All this is is a link to the output module.
#

package bp_htmlpubs;

$version = "html (dj 14 mar 96)";

# my $htmldir = "$ENV{HOME}/www/pubs";
my $htmldir = ".";

require "bp-s-generic.pl";
$bp_s_generic::titlefirst = 1;
$bp_s_generic::smartquotes = 1;

require "bp-htmlbw.pl";

# print STDERR "at bp-htmlpubs.pl entry, conv_func = " . (defined($conv_func) ? $conv_func : "<undef>") . "\n";

######

# $bib::cset = "html";

&bib::reg_format(
  'htmlpubs',     # name
  'htmlpubs',     # short name
  'bp_htmlpubs',  # package name
  'html',     # default character set
  'suffix is html',
# functions
  'open      uses output',
  'close     uses output',
  'write     uses output',
  'clear     uses output',
  'read      uses output',
  'options',
  'implode   uses output',
  'explode   uses output',
  'tocanon   uses output',
#  'fromcanon uses output',
  'fromcanon',
);

######

my $opt_withyears = 0;

sub options {
    $_ = shift @_;
    /withyears/ && do {
        $opt_withyears = 1;
        return 1;
    };
    return undef;
}

sub make_href {
  my ($url, $title) = @_;

  return
    "${bib'cs_meta}2200"
    . "${bib'cs_meta}2300"
    . $url   . "${bib'cs_meta}2310"
    . $title . "${bib'cs_meta}2210";
}

my $csmeta = ${bib::cs_meta};
my $csext = ${bib::cs_ext};
my $cs_meta0103 = $csmeta . "0103"; # begin bold "<B>"
my $cs_meta0113 = $csmeta . "0113"; # end bold "</B>"
my $cs_meta1100 = $csmeta . "1100"; # <p>
my $cs_meta1110 = $csmeta . "1110"; # </p>
my $cs_ext2013  = $csext . "2013"; # en dash "--"
my $cs_meta2101 = $csmeta . "2101";
my $cs_meta2150 = $csmeta . "2150"; # line break "<br />"


my $month_regexp = '(:?Jan(uary|\.)|Feb(ruary|\.)|Mar(ch|\.)|Apr(il|\.)|May|June|July|Aug(ust|\.)|Sep(tember|\.)|Oct(ober|\.)|Nov(ember|\.)|Dec(ember|\.))';
my $date_range_regexp = '(:?' . $month_regexp . '[  ](:?[0123]?[0-9](:?(:?-|' . $cs_ext2013 . ')[0123]?[0-9])?, )?[12][0-9][0-9][0-9])';

my $lastyear = 0;

sub make_header {
  my ($title) = @_;
  # returns <h2> $title </h2>
  return "${bib'cs_meta}2232" . $title . "${bib'cs_meta}2233";
}

# Like fromcanon, but suppresses year processing
sub fromcanon_noyears {
  my (%entry) = @_;
  my $opt_withyears_save = $opt_withyears;
  $opt_withyears = 0;
  my %result = fromcanon(%entry);
  $opt_withyears = $opt_withyears_save;
  %result;
}

sub fromcanon {
  my (%entry) = @_;

  my %rec = &bp_output::fromcanon(%entry);
  my $text = $rec{'TEXT'};

  # Adjust the text, then set $rec{'TEXT'} and return %rec.

#  print STDERR "text: $text\n";
#  print STDERR "orig fields: ", join(" ", keys %entry), "\n";
#  print STDERR "rec fields: ", join(" ", keys %rec), "\n";

  # Split across lines, to be more readable in the HTML source;
  # also add line breaks, for readability in a browser.
  # This puts ${bib'cs_meta}1100 on line 1, title on line 2, authors on
  # line 3, and all other info on line 4.
  $text =~ s/($cs_meta1100)/$1\n$cs_meta0103/;
  my $title_author;
  if ($text =~ s/(''|${bib::cs_ext}201D),? ((?:edited )?by .*?), ((:?in )?$cs_meta2101|Ph\.D\. dissertation|Masters thesis|Bachelors thesis|[^,]*(:?Technical Report|Memo|Video)|$date_range_regexp)/$1$cs_meta0113$cs_meta2150\n$2.$cs_meta2150\n\u$3/i) {
    # print STDERR "split fields = <<$1>><<$2>><<$3>>\n";
    $text =~ /(^.*\n(.*)\n((edited )?by .*)\n)/m;
    # print STDERR "text = <<$text>>\n";
    # print STDERR "split2 fields = <<$2>><<$3>>\n";
    $title_author = $1;
    # Don't boldface title, don't break across any lines.
    $title_author =~ s/$cs_meta0103(.*)$cs_meta0113/$1/;
    $title_author =~ s/$cs_meta2150//g;
    # print STDERR "title_author = $title_author\n";
  } else {
    # print STDERR "failed to split lines: $text\n";
  }
  # print STDERR "text (2): $text\n";

  # Remove abstract, keywords, annotation
  #  print STDERR "removing abstract from $entry{'CiteKey'}...\n";
  $text =~ s/${bib::cs_meta}1103${bib::cs_meta}0103Abstract:  ${bib::cs_meta}0113\n.*${bib::cs_meta}1113//;
  $text =~ s/${bib::cs_meta}1103${bib::cs_meta}0103Keywords:  ${bib::cs_meta}0113\n.*${bib::cs_meta}1113//;
  $text =~ s/${bib::cs_meta}1103${bib::cs_meta}0103Annotation:  ${bib::cs_meta}0113\n.*${bib::cs_meta}1113//;
  # Remove paragraph end.  This doesn't harm the abstract, which has
  # already been removed.
  $text =~ s/${bib::cs_meta}1110//;

  if (! defined($entry{'supersededby'})) {
    # Add extra information.
    my $downloads = &bp_htmlbw::downloads_text($htmldir, 'with_abstract', %entry);
    $text = &bp_htmlbw::join_linebreak($text, $downloads);

    my $prev_versions = &bp_htmlbw::previous_versions_text($title_author, %entry);
    $text = &bp_htmlbw::join_linebreak($text, $prev_versions);
  }

  if ($opt_withyears && defined($lastyear) && defined $entry{'Year'}) {
      my $year = $entry{'Year'};
      if ($year ne $lastyear) {
          $text = make_header($year) . $text;
          $lastyear = $year;
      }
  }

  # Reinstate paragraph end.
  $text .= "${bib::cs_meta}1110";

  # Done with edits.

  $rec{'TEXT'} = $text;
  %rec;
}


#######################
# end of package
#######################

1;
