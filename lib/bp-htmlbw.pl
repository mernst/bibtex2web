#
# bibliography package for Perl
#
# HTML extra routines
#

package bp_htmlbw;

use Carp;

use LWP::Simple;

# Global variables %supersedes and %citekeys are set in bwconv.pl.

my $csmeta = ${bib::cs_meta};
my $cs_meta0103 = $csmeta . "0103"; # begin bold "<b>"
my $cs_meta0113 = $csmeta . "0113"; # end bold "</b>"
my $cs_meta1100 = $csmeta . "1100";
my $cs_meta1110 = $csmeta . "1110";
# my $cs_meta2101 = $csmeta . "2101";
my $cs_meta2150 = $csmeta . "2150"; # line break "<br />"

sub make_href {
  my ($url, $title) = @_;

  return
    "${bib'cs_meta}2200"
    . "${bib'cs_meta}2300"
    . $url   . "${bib'cs_meta}2310"
    . $title . "${bib'cs_meta}2210";
}

# Either return the first argument (if second is missing), or
# append the two arguments, separated by a linebreak.
sub join_linebreak ( $;$ ) {
  my ($text1, $text2) = @_;

  if ((defined $text2) && ($text2 ne "")) {
    # remove newlines before line break.  As of 10/5/2002, both Netscape
    # and Internet Explorer can insert two line breaks (ie, a blank line)
    # if <br /> is at the beginning of a line.
    $text1 =~ s/\n*$//;
    $text1 .= "$cs_meta2150\n"; # line break (<br /> tag)
    $text1 .= $text2;
  }
  return $text1;
}


# The result is *not* surrounded by <p>...</p> (really,
# ${bib::cs_meta}1100...${bib::cs_meta}1110).  It's the caller's
# responsibility to do that, since not all callers want this as a separate
# paragraph.
sub downloads_text ( $$% ) {
  my ($htmldir, $abstract, %entry) = @_;
  if ($abstract eq "no_abstract") {
    $abstract = 0;
  } elsif ($abstract ne "with_abstract") {
    die "abstract argument '$abstract' should be 'with_abstract' or 'no_abstract'";
  }

  my $result = "";

  #   <a href="graycodes-abstract.html">Abstract</a>.
  #   Download: <a href="graycodes.ps">PostScript</a>,
  #   <a href="graycodes.pdf">PDF</a>.
  my $basefilename = $entry{'basefilename'};
  if ((! defined($basefilename)) && (! defined($entry{'nobasefilename'}))) {
    print STDERR "Warning: no basefilename for $entry{'CiteKey'}\n";
  }
  my @downloads = ();
  if (defined $entry{'downloads'}) {
    @downloads = split(';\s*', $entry{'downloads'});
  }
  if (defined($basefilename)) {

    if ($abstract eq 'with_abstract') {
      my $absfile = "$basefilename-abstract.html";
      if (! -e "$htmldir/$absfile") {
          # No need to use "confess" here; the backtrace isn't helpful.
          die "Can't find $htmldir/$absfile in " . `pwd`;
      }
      $result .= make_href("$absfile", "Details") . ".\n";
    }

    my @local_downloads = ();
    my %download_type_names = (
			       "ps" => "PostScript",
			       "ps.gz" => "PostScript (gzipped)",
			       "pdf" => "PDF",
			       "pdf.gz" => "PDF (gzipped)",
			       "ppt" => "PowerPoint",
			       "pptx" => "PowerPoint",
			       "ppt.gz" => "PowerPoint (gzipped)",
			       "odp" => "ODP",
			       "doc" => "MS Word",
			       "docx" => "MS Word",
			       "doc.gz" => "MS Word (gzipped)"
			      );


    my @download_type_order = ("pdf", "pdf.gz", "ps", "ps.gz",
			       "doc", "docx", "doc.gz",
                               "ppt", "pptx", "ppt.gz",
                               "odp");

    foreach my $category ("slides", "base") {
      # These get unshifted in, so reverse the order so they appear
      # on the page properly.
      foreach my $dtype (reverse @download_type_order) {
	my $dtn = $download_type_names{$dtype};
	my $fn_ext = "";
	my $label = $dtn;

	if ($category eq "slides") {
	  $fn_ext = "-slides";
	  $label = "slides (${dtn})";
	}

	my $fn = "${htmldir}/${basefilename}${fn_ext}.${dtype}";
	if (-e $fn) {
          $fn =~ s:^\./::;
	  unshift @local_downloads, "${fn} ${label}";
	}
      }
    }

    if (scalar(@local_downloads) > 0) {
      unshift @downloads, @local_downloads;
    } else {
      if (defined $entry{'downloadsnonlocal'}) {
        @nonlocal_downloads = split(';\s*', $entry{'downloadsnonlocal'});
        unshift @downloads, @nonlocal_downloads;
      }
    }
  }

  if (scalar(@downloads) > 0) {
    $result .= "Download:\n";
    my %urls = ();
    for my $download (@downloads) {
      chomp($download);  # omit trailing spaces
      my ($url, $anchor) = split(' ', $download, 2);
      if (defined($urls{$url})) {
        print STDERR "Duplicate download link $url for $entry{'CiteKey'}\n";
      }
      $urls{$url} = 1;
      if (! defined($anchor)) {
        print STDERR "Missing anchor text (e.g., \"PDF\"): $download\n";
        $anchor = "??";
      }
      # Check non-local links for validity
      if ((! defined($validurls{$url})) && ($url =~ /^http/) && (! head($url))) {
        print STDERR "Warning: invalid download URL $url\n";
      }
      $result .= make_href($url, $anchor) . ",\n";
    }
    $result =~ s/,\n$/.\n/m;
  } elsif (! defined $entry{'nodownloads'}) {
    print STDERR "Warning: no downloads for $entry{'CiteKey'}\n";
  }
  return $result;
}


# Result has no paragraph start/end markers.
sub previous_versions_text ( $% ) {
  my ($title_author, %entry) = @_;

  my $result;

  my $citekey = $entry{'CiteKey'};

  # Add "previous version appeared as" information.
  my $supersedees = $supersedes{$citekey};
  # if (! defined $supersedees) { print STDERR "$citekey supersedes nothing\n"; }
  if (defined $supersedees) {
    # print STDERR "$citekey supersedes $supersedees\n";
    for my $subkey_and_how (split /,/, $supersedees) {
      my ($subkey, $how) = (split / /, $subkey_and_how, 2);
      my $subrec = $citekeys{$subkey};
      # print STDERR "subrec = $subrec\n";
      my %subentry = &bib::explode($subrec);
      # print STDERR "subentry keys = ", join(' ', keys %subentry), "\n";
      my %subrec = &bib::tocanon(%subentry);
      # print STDERR "subrec keys = ", join(' ', keys %subrec), "\n";
      my %subhtmlentry = &bp_htmlpubs::fromcanon_noyears(%subrec);
      # Do not call implode; that will interfere with the subsequent call.
      my $subtext = $subhtmlentry{'TEXT'};
      # Don't boldface title, don't break across any lines.
      $subtext =~ s/$cs_meta0103(.*)$cs_meta0113/$1/;
      $subtext =~ s/$cs_meta2150//g;
      # If title and authors are identical to final version, eliminate them.
      # (Commas in technical report institutions seem to confuse this, as
      # they turn the period at the end of the author list into a period.)
      $subtext =~ s/\Q$title_author//;
      # print STDERR "subtext = $subtext\n";
      # print STDERR "title_author = $title_author\n";
      # Remove paragraph break
      $subtext =~ s/^$cs_meta1100//;
      $subtext =~ s/$cs_meta1110$//;
      $subtext =~ s/\n+\n$/\n/;
      if ($subtext =~ s/^In /in /) {
	# nothing to do
      } elsif ($subtext =~ /^(Masters|Bachelors) thesis/) {
	$subtext = "as a $subtext";
      } else {
	$subtext = "as $subtext";
      }
      # Convert some periods to commas, perhaps.
      # $subtext =~ s/\. *Revised/, revised/g;
      # $subtext =~ s/\. /, /g;
      # <br /> needs to be at end of previous line, not start of new line.
      if (defined $result) {
	$result = join_linebreak($result,
				 "$how appeared $subtext");
      } else {
	$result = "$how appeared $subtext";
      }
    }
  }
  return $result;
}


#######################
# end of package
#######################

1;
