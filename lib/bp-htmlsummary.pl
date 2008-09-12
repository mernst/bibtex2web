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

package bp_htmlsummary;

use Carp;

$version = "html (dj 14 mar 96)";

require "bp-s-generic.pl";
$bp_s_generic::titlefirst = 1;
$bp_s_generic::smartquotes = 1;

# print STDERR "at bp-htmlsummary.pl entry, conv_func = " . (defined($conv_func) ? $conv_func : "<undef>") . "\n";

######

# $bib::cset = "html";

&bib::reg_format(
  'htmlsummary',     # name
  'htmlsummary',     # short name
  'bp_htmlsummary',  # package name
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

my $csmeta = ${bib'cs_meta};

my $prev_category = undef;

sub make_href {
  my ($url, $title) = @_;

  return
    "${bib'cs_meta}2200"
    . "${bib'cs_meta}2300"
    . $url   . "${bib'cs_meta}2310"
    . $title . "${bib'cs_meta}2210";
}

sub make_aname {
  my ($name, $title) = @_;

  $name =~ s/ /_/g;
  # Parens are illegal in anchor names
  $name =~ s/\(//g;
  $name =~ s/\)//g;
  return
    "${bib'cs_meta}2200"
    . "${bib'cs_meta}2301"
    . $name  . "${bib'cs_meta}2310"
    . $title . "${bib'cs_meta}2210";
}


# my $month_regexp = '(Jan(uary|\.)|Feb(ruary|\.)|Mar(ch|\.)|Apr(il|\.)|May|June|July|Aug(ust|\.)|Sep(tempber|\.)|Oct(ober|\.)|Nov(ember|\.)|Dec(ember|\.))';

# This needs to operate somewhat specially, in that it may insert headers
# when the current category changes.

sub fromcanon {
  my (%entry) = @_;

  if (defined($entry{'supersededby'})) {
    return "";
  }

  my $title = $entry{'Title'};
  if (! defined $entry{'Title'}) {
    # die "No title";
    print STDERR %entry;
    confess "No title";
  }
  if ($entry{'CiteType'} eq 'book') {
    $title = "m2101$titlem2111";
  }

  my $type = $entry{'CiteType'};

  my $where;
  if      ($type eq 'article') {
    $where = "m2101$entry{'Journal'}m2111";
  } elsif ($type eq 'report') {
    if (defined $entry{'ReportType'} || $entry{'ReportNumber'}) {
      if (defined $entry{'ReportType'}) {
	$where .= "$entry{'ReportType'}";
      } else {
	$where .= "TR";
      }
    }
  } elsif ($type eq 'book') {
    $where = "";
  } elsif ($type eq 'inproceedings') {
    $where = "m2101$entry{'SuperTitle'}m2111";
  } elsif ($type eq 'inbook') {
    $where ="m2101$entry{'SuperTitle'}m2111";
  } elsif ($type eq 'thesis') {
    if (defined $entry{'ReportType'} || $entry{'ReportNumber'}) {
      if (defined $entry{'ReportType'}) {
	# print STDERR "\$entry{'ReportType'} = $entry{'ReportType'}\n";
	if ($entry{'ReportType'} eq "Ph.D.") {
	  $where = "Ph.D. dissertation";
	} elsif ($entry{'ReportType'} eq "Masters") {
	  $where = "Masters thesis";
	} else {
	  $where = "$entry{'ReportType'}";
	}
      } else {
	$where = "TR";
      }
    }
  } elsif ( ($type eq 'misc') || ($type eq 'unpublished') || ($type eq 'manual') || ($type eq 'avmaterial') || ($type eq 'proceedings') || ($type eq 'map') ) {
    if (defined $entry{'Journal'}) {
      $where = "m2101$entry{'Journal'}m2111";
    } elsif (defined $entry{'SuperTitle'}) {
      $where = "m2101$entry{'SuperTitle'}m2111";
    } else {
      $where = "";
    }
  }
  if (! defined($where)) {
    warn "No publication data for \"$title\" of type \"$type\"\n";
    $where = "";
  }
  my $where_when;
  my $year = $entry{'Year'};
  if ($where eq "") {
    if (defined($year)) {
      $where_when = " ($year)";
    } else {
      $where_when = "";
    }
  } else {
    if (defined($year)) {
      $where_when = " ($where, $year)";
    } else {
      $where_when = " ($where)";
    }
  }

  # print STDERR "<<$entry{'basefilename'}>><<$title>><<$where_when>>\n";
  if (defined $entry{'basefilename'}) {
    $title = make_href("../pubs/$entry{'basefilename'}-abstract.html", $title);
  }
  my $text = "$title$where_when\n";

  # Add summary.
  my $summary = $entry{'Summary'};
  if (! defined($summary)) {
    print STDERR "Warning: no summary for $entry{'CiteKey'}\n";
    $summary = "";
  }
  # print STDERR "<<${csmeta}>><<$csmeta>><<$text>><<$summary>>\n";
  $text = "\n${csmeta}2223\n$text${csmeta}2226\n${csmeta}2224\n$summary\n${csmeta}2227";

  my $category = $entry{'category'};
  if (! defined($category)) { die "no category: $text"; }
  if ((! defined($prev_category)) || ($category ne $prev_category)) {
    $text = "${csmeta}2232"
      . make_aname($category, $category)
      . "${csmeta}2233\n\n"
      . "${csmeta}2222\n\n"
      . $text;
    if (defined($prev_category)) {
      $text = "${csmeta}2225\n\n" . $text;
    }
    $prev_category = $category;
  }

  # Done with edits.

  my %rec = ();
  $rec{'TEXT'} = $text;
  %rec;
}

# sub fromcanon {
#   my (%entry) = @_;
#   my %rec = ();
#   my $ent = '';
#
#   # We do the conversion here rather than in implode because we can put
#   # escape characters and meta characters in the style without worrying
#   # about which character set is being used.
#
#   # Well, almost.  We do care if we're using HTML, because we want a number
#   # of special things done for it.  As of 0.2.2, we have glb_current_cset
#   # set for us for fromcanon.
#   if ($bib'glb_current_cset eq 'html') {
#     #$ent = "${bib'cs_meta}1100\n";
#     if (defined $entry{'Source'}) {
#       my ($url, $title);
#       $url = $entry{'Source'};
#       $url =~ s/<(.*)>/$1/;
#       $url =~ s/^url:\s*(.*)/$1/i;
#       if ($url =~ /^\w+:\/\//) {
#         $title = $entry{'Title'};
#         $entry{'Title'} = "${bib'cs_meta}2200" . "${bib'cs_meta}2300"
#                         . $url   . "${bib'cs_meta}2310"
#                         . $title . "${bib'cs_meta}2210";
#       }
#     }
#   }
#
#   # print STDERR "bp-output.pl fromcanon: conv_func = " . (defined($conv_func) ? $conv_func : "<undef>") . "\n";
#
#   # I give up; I can't figure out why this is necessary
#   if ($conv_func eq "conv_generic") {
#     $conv_func = "bp_s_generic::$conv_func";
#   }
#
#   $ent .= &$conv_func(%entry);
#
#   #$ent =~ s/\s\s+/ /g;
#   $ent =~ s/$bib'cs_sep/ ; /go;
#
#   $rec{'TEXT'} = $ent;
#
#   %rec;
# }




#######################
# end of package
#######################

1;
