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

package bp_htmllist;

$version = "html (dj 14 mar 96)";

require "bp-s-generic.pl";
$bp_s_generic::titlefirst = 1;
$bp_s_generic::smartquotes = 1;


######

&bib::reg_format(
  'htmllist',     # name
  'htmllist',     # short name
  'bp_htmllist',  # package name
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
  'fromcanon',
);

######

# if $limit > 0, only print up to $limit records
my $numrecs = 0;
my $limit   = 0;

# relative location of directory containing abstracts
my $abstract_dir = "../pubs/";

sub options {
    $_ = shift @_;
    /limit/ && do {
        $limit = 5;
        if (/limit:(.*)/) {
            $limit = $1;
        }
        return 1;
    };
    /abstract_dir/ && do {
        if (/abstract_dir:(.*)/) {
            $abstract_dir = $1;
        } else {
            die "Use abstract_dir:path, e.g., abstact_dir:../pubs";
        }
        return 1;
    };
    return undef;
}

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

sub fromcanon {
  my (%entry) = @_;

  if ($limit > 0 && $numrecs >= $limit) {
      my %rec = ();
      $rec{'TEXT'} = "";
      return %rec;
  }

  if (defined($entry{'supersededby'})) {
    return "";
  }

  my $title = $entry{'Title'};
  if (! defined $entry{'Title'}) {
    die "No title";
  }

  if ($entry{'CiteType'} eq 'book') {
    $title = "m2101$titlem2111";
  }

  if (defined $entry{'basefilename'}) {
    $title = make_href("$abstract_dir/$entry{'basefilename'}-abstract.html",
                       $title);
  }

  my $text = "$title${bib'cs_meta}2150\n";

  $numrecs++;
  my %rec = ();
  $rec{'TEXT'} = $text;
  %rec;
}

#######################
# end of package
#######################

1;
