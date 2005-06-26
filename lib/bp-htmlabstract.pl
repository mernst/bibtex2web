#
# bibliography package for Perl
#
# HTML routines
# Use "-outopts=withbibtex" to include BibTeX entries.
#
# Dana Jacobsen (dana@acm.org)
# 14 March 1996
#
#           All this is is a link to the output module.
#

package bp_htmlabstract;

$version = "html (dj 14 mar 96)";

# my $htmldir = "$ENV{HOME}/www/pubs";
my $htmldir = ".";

require "bp-s-generic.pl";
$bp_s_generic::titlefirst = 1;
$bp_s_generic::smartquotes = 1;

require "bp-htmlpubs.pl";
require "bp-htmlbw.pl";
require "bp-bibtex.pl";

# fields to omit from generated bibtex entries
@omitted_fields = (# 'downloads', 'category', 'basefilename',
                   # 'inlined-crossref',
                   'crossref',  # we've already inlined the crossref
                   # 'summary',   # not really useful in citations?
                   'abstract',  # already appears on the same page
                   'annote',    # already appears on the same page
                   'keywords',  # already appears on the same page
                   'key'        # sometimes inherited from crossrefs
                   );

# print STDERR "at bp-htmlpubs.pl entry, conv_func = " . (defined($conv_func) ? $conv_func : "<undef>") . "\n";

######

# $bib::cset = "html";

&bib::reg_format(
  'htmlabstract',     # name
  'htmlabstract',     # short name
  'bp_htmlabstract',  # package name
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

my $opt_withbibtex = 0;
my $opt_linkauthors = 0;
my %authorlinks = ();

# FIXME: consolidate this code with make-author-pages.pl
 sub author_as_filename ( $ ) {
  my ($author) = @_;
  $author =~ s/[\'{}.]//g;
  $author =~ s/ /-/g;
  return $author;
}

sub options {
    $_ = shift @_;
    /withbibtex/ && do {
        $opt_withbibtex = 1;
        return 1;
    };
    /linkauthors/ && do {
        $opt_linkauthors = 1;
        my $authors_file = "authors";
        if (/linkauthors:(.*)/) {
            $authors_file = $1;
        }
        open(AUTHORS, $authors_file) or die
            "Cannot open file $authors_file; "
            . "specify a different file using linkauthors:filename";
        while (<AUTHORS>) {
            # FIXME: consolidate this code with make-author-pages.pl
            if (/^\#/) { next; }
            chomp;
            my $author = $_;
            my $author_pubs_url;
            if ($author =~ /^(.*?)[ \t]+(http:.*)$/) {
                ($author, $author_pubs_url) = ($1, $2);
            }
            $authorlinks{$author} = author_as_filename($author) . ".html";
        }
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

my $csmeta = "${bib::cs_meta}";
my $csext = ${bib::cs_ext};
my $cs_meta0103 = $csmeta . "0103"; # begin bold "<B>"
my $cs_meta0113 = $csmeta . "0113"; # end bold "</B>"
my $cs_meta1100 = $csmeta . "1100"; # paragraph break "<P>"
my $cs_meta1101 = $csmeta . "1101"; # begin preformatted "<PRE>"
my $cs_meta1111 = $csmeta . "1111"; # end preformatted "</PRE>"
my $cs_ext2013  = $csext . "2013"; # en dash "--"
my $cs_meta2101 = $csmeta . "2101"; # "<EM>"
## These were for the abstract.
# my $cs_meta2210 = $csmeta . "2210";
# my $cs_meta2310 = $csmeta . "2310";

my $month_regexp = '(Jan(uary|\.)|Feb(ruary|\.)|Mar(ch|\.)|Apr(il|\.)|May|June|July|Aug(ust|\.)|Sep(tember|\.)|Oct(ober|\.)|Nov(ember|\.)|Dec(ember|\.))';
my $date_range_regexp = '(:?' . $month_regexp . '[  ](:?[0123]?[0-9](:?(:?-|' . $cs_ext2013 . ')[0123]?[0-9])?, )?[12][0-9][0-9][0-9])';

sub fromcanon {
  my (%entry) = @_;

  my %rec = &bp_output::fromcanon(%entry);
  my $text = $rec{'TEXT'};

  # Adjust the text, then set $rec{'TEXT'} and return %rec.

#  print STDERR "text: $text\n";
#  print STDERR "orig fields: ", join(" ", keys %entry), "\n";
#  print STDERR "rec fields: ", join(" ", keys %rec), "\n";

  # Split across lines, to be more readable in the HTML file.
  # This puts ${bib'cs_meta}1100 on line 1, title on line 2, authors on
  # line 3, and all other info on line 4.
  $text =~ s/($cs_meta1100)/$1\n/;
  my $title_author;
  my $title;
  if ($text =~ s/(''),? ((?:edited )?by .*?), ((:?in )?$cs_meta2101|Ph\.D\. dissertation|Masters thesis|Bachelors thesis|[^,]*(:?Technical Report|Memo|Video)|$date_range_regexp)/$1\n$2.\n\u$3/i) {
    # print STDERR "split fields = <<$1>><<$2>><<$3>>\n";
    $text =~ /(^.*\n(.*)\n((edited )?by .*)\n)/m;
    # print STDERR "text = <<$text>>\n";
    # print STDERR "split2 fields = <<$2>><<$3>>\n";
    $title_author = $1;
    $title = $2;
    $title =~ s/``(.*)''/$1/;
    # print STDERR "title_author = $title_author\n";
  } else {
    # print STDERR "failed to split lines: $text\n";
  }
  # print STDERR "text (2): $text\n";

  my $downloads = bp_htmlbw::downloads_text($htmldir, 'no_abstract', %entry);
  if (defined $downloads) {
    # print STDERR "downloads (1): $downloads\n";
    $downloads =~ s/(Download:)\n/$cs_meta0103$1$cs_meta0113\n/;
    # print STDERR "downloads (2): $downloads\n";
    $text = "$downloads\n\n$text";
  }
  my $prev_versions = bp_htmlbw::previous_versions_text($title_author, %entry);
  $prev_versions = bp_htmlbw::join_linebreak("", $prev_versions);

  # Adjust formatting of the abstract
  $text =~ s/${bib::cs_meta}1103${bib::cs_meta}0103Abstract:  ${bib::cs_meta}0113\n(.*)${bib::cs_meta}1113/$prev_versions\n\n${bib::cs_meta}2232Abstract${bib::cs_meta}2233\n\n$1\n/;
  # Introduce line breaks
  $text =~ s/($cs_meta1100)([^\n])/\n$1\n$2/g;

  if (! defined($entry{'supersededby'})) {

    # print STDERR "text (2.5): $text\n";

    # Insert HTML links.
    {
      while (my ($linkname, $lurl) = each %linknames) {
          # print STDERR "checking for $linkname in $text\n";
          next if $opt_linkauthors && defined $authorlinks{$linkname};
          $text =~ s/\Q$linkname\E/&make_href($lurl, $linkname)/ge;
      }
      if ($opt_linkauthors) {
          while (my ($author, $aurl) = each %authorlinks) {
              $text =~ s/\Q$author\E/&make_href($aurl, $author)/ge;
          }
      }
    }

    # print STDERR "text (3): $text\n";

  }

  $text .= "$cs_meta1100\n$downloads\n";

  if ($opt_withbibtex) {
      my %bibentry;
      {
        # Temporarily ignore unknown fields, resetting the flag afterward
        # to its previous value.
        my $old_opt_omit_unknown = $bp_bibtex::opt_omit_unknown;
        $bp_bibtex::opt_omit_unknown = 1;
        %bibentry = bp_bibtex::fromcanon(%entry);
        $bp_bibtex::opt_omit_unknown = $old_opt_omit_unknown;
      }
      # Non-standard keys aren't included by the above.
      # Remove additional standard bibtex keys from the entry.
      foreach my $field (keys %bibentry) {
          # keep 'CITEKEY' and 'TYPE'
          delete $bibentry{$field} if
              # The "^" and "$" are crucial to avoid omitting "note" just
              # because "annote" is on @omitted_fields.
              grep {/^$field$/i} @omitted_fields;
      }
      $text .= $cs_meta1100 . "\n";
      $text .= $cs_meta0103 . "BibTeX entry:" . $cs_meta0113 . "\n";
      $text .= $cs_meta1101 . "\n";
      # my @be_list = %bibentry;
      # print STDERR "pre-implode: @be_list\n";
      my $bibtex_entry = bp_bibtex::implode(%bibentry);
      # print STDERR "post-implode: $bibtex_entry\n";
      $bibtex_entry = bp_cs_tex::fromcanon($bibtex_entry, 0);
      $bibtex_entry =~ s/(\d)----(\d)/$1--$2/g;
      # print STDERR "post-fromcanon: $bibtex_entry\n";
      $text .= $bibtex_entry;
      $text .= $cs_meta1111 . "\n";
  }

  # Done with edits.  Now introduce scaffolding.  This will get converted
  # into <HTML> etc. when the file is converted into multiple files.
  {
    # Remove leading paragraph break.
    $text =~ s/^\n\n($cs_meta1100)/\n/;

    my $basefile = $entry{'basefilename'};
    if (! defined $basefile) {
      $text = "";
    } else {
      # print STDERR "basefile:<<$basefile>> title:<<$title>> text:<<$text>>\n";
      $text = "\n\nNEWFILE: $basefile $title\n"
	. $text
        . "\n\nENDFILE\n\n";
    }
  }
  $rec{'TEXT'} = $text;
  %rec;
}


#######################
# end of package
#######################

1;
