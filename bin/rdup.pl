#!/usr/bin/perl

# bibrdup, removes duplicates using the bp package
#
# The major problem with this program is that is takes a lot of memory.
# Expect it to use 2-3 times in memory the size of your file.  To reduce
# this usage would require a 2-pass system.  It is also rather slow -- it
# takes about 45 seconds per 1000 records on my 486/66.
#
# Dana Jacobsen (dana@acm.org)   22 Jan 95
#
# 11 Mar 96: separator character changes, preserve original order, only
#            save format for possible matches, key format, fuzzymatch
#            preprocessing, added exact match, specified tolerance.
#

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";

@ARGV = &bib::stdargs(@ARGV);

$printdups = 0;
$exact = 0;
$deftol = 0.25;

while (@ARGV) {
  $_ = shift @ARGV;
  last if /^--$/;
  /^-help$/ && do { &dieusage; };
  /^-p$/    && do { $printdups = 1; next; };
  /^-e$/    && do { $exact = 1; next; };
  /^-t$/    && do { $deftol = shift @ARGV; next; };
  push (@filelist, $_);
}

push(@filelist, @ARGV)  if @ARGV;
&dieusage() unless @filelist;

#
# Step 1:  Read in all the information, and construct a list of possible
#          duplicates.  Any entry that has a common author, the same date,
#          and is of the same type will be considered to be a potential
#          duplicate.
#
#          For exact matching, we do the test for equality as soon as we
#          find a possible match.  If it is equal, we add it directly to
#          the dup list.
#
@possible = ();
@dup = ();
$key = 0;
foreach $file (@filelist) {
  next unless $fmt = &bib::open($file);
  push(@files, $file);
  while ($record = &bib::read) {

    # Since the key is never actually used in any output routines, it is
    # much faster just to use a single number as the key.  This also saves
    # us a fair bit of memory.  In addition, we can print the results in
    # order without having to save any order information!
    #
    # if (defined $can{'CiteKey'}) {
    #   $key = $can{'CiteKey'};
    # } else {
    #   $key = &bp_util::genkey(%can);
    # }
    # $key = &bp_util::regkey($key);

    $key++;
    $master{$key} = $record;

    %can = &bib::tocanon(&bib::explode($record));

    # now check whether this might be a duplicate.
    #
    # full is the full author list
    # auth is the first author's last name
    #
    # author{last} is a list of keys with "last" as first author
    # date{key}    is the date of "key"
    # type{key}    is the type of "key"
    #
    if (defined $can{'Authors'}) {
      $full = $auth = $can{'Authors'};
      substr($auth, index($auth, $bib::cs_sep2)) = '';
    } elsif (defined $can{'CorpAuthor'}) {
      $full = $auth = $can{'CorpAuthor'};
    } elsif (defined $can{'Editors'}) {
      $full = $auth = $can{'Editors'};
      substr($auth, index($auth, $bib::cs_sep2)) = '';
    } else {
      $auth = $full = undef;
    }
    if (defined $auth) {
      if (defined $author{$auth}) {
        foreach $nkey (split(/$bib::cs_sep/o, $author{$auth})) {

          next unless &fuzzymatch( $can{'Year'},     $date{$nkey}, 0 );
          next unless &fuzzymatch( $can{'CiteType'}, $type{$nkey}, 0 );

          if ($exact) {
            if ($master{$key} eq $master{$nkey}) {
              push(@dup, $key);
            }
          } else {
            $filename{$key} = $file;
            push(@possible, "$key : $nkey");
          }
        }
      }
      $date{$key} = $can{'Year'};
      $type{$key} = $can{'CiteType'};
      foreach $a ( split(/$bib::cs_sep/o, $full) ) {
        ($last) = split(/$bib::cs_sep2/o, $a, 2);
        if (defined $author{$last}) {
          $author{$last} .= $bib::cs_sep . $key;
        } else {
          $author{$last} = $key;
        }
      }
    }
  }
  # Since we are going to use the file information later while exploding
  # and converting, we don't want to close the file yet.
  # &bib::close;
}
$lastkey = $key;
# clear up some memory
undef %date;
undef %type;
undef %author;
&bib::format($fmt);

#
# Step 2: From the list of possible duplicates, use fuzzy matching on
#         the Journal, Pages, and Title fields to determine if we really
#         have a duplicate.
#
if (!$exact) {
  foreach (@possible) {
    # We would really like to just store the possible matches in their canon
    # format, but perl4 doesn't allow easy arrays of assoc arrays.  In either
    # case, we assume that the number of possible matches is pretty small.
    # This way takes more CPU, but saves a little memory.
    ($key1, $key2) = split(/ : /);
    %can1 = &bib::tocanon( &bib::explode( $master{$key1}, $filename{$key1} ),
                          $filename{$key1} );
    %can2 = &bib::tocanon( &bib::explode( $master{$key2}, $filename{$key2} ),
                          $filename{$key2} );
    if ( (defined $can1{'Journal'}) && (defined $can2{'Journal'}) ) {
      next unless &fuzzymatch($can1{'Journal'}, $can2{'Journal'});
    }
    if ( (defined $can1{'Pages'}) && (defined $can2{'Pages'}) ) {
      next unless &fuzzymatch($can1{'Pages'}, $can2{'Pages'});
    }
    if ( (defined $can1{'Title'}) && (defined $can2{'Title'}) ) {
      next unless &fuzzymatch($can1{'Title'}, $can2{'Title'});
    }
    # found a duplicate.  Push the shorter one on the duplicate list.
    if ( length($master{$key1}) > length($master{$key2}) ) {
      push(@dup, $key2);
    } else {
      push(@dup, $key1);
    }
  }
}

#
# Step 3: Print our output.  For the '-p' option, just print the duplicates.
#         For other options, delete all the duplicates, then print the rest.
#
foreach $file (@files) {
  &bib::close($file);
}
if ($printdups) {
  foreach $key (@dup) {
    print $master{$key}, "\n";
  }
} else {
  foreach $key (@dup) {
    delete $master{$key};
  }
  for ($key = 1; $key <= $lastkey; $key++) {
    next unless defined $master{$key};
    print $master{$key}, "\n";
  }
}


sub dieusage {
  my $prog = substr($0,rindex($0,'/')+1);

  $str =<<"EOU";
Usage: $prog [-p] [-e] [-t tol] [bibfile ...]
  -p  Print out duplicates instead of non-duplicates
  -e  Only consider exact matches to be duplicates
  -t  Set the tolerance for fuzzy matches (default: 0.25)
EOU

  die $str;
}


#
# My fuzzy match subroutine.  This is fairly untested.
# make a histogram of each string, then compute the linear difference of
# the two.  If (difference / length of longest string) is more than the
# tolerance, then they don't match.
#
sub fuzzymatch {
  my ($s1, $s2, $tol) = @_;
  my ($l1, $l2, $ll, $ldiff);
  my (%hist1, %hist2, %histd);
  my (@intersect);
  my ($diff, $dt);

  # special cases of one or both strings undefined.
  return 0 if ( (!defined $s1) && (defined $s2) );
  return 0 if ( (!defined $s2) && (defined $s1) );
  return 1 if ( (!defined $s1) && (!defined $s2) );

  $tol = $deftol unless defined $tol;

  # special case of tolerance equal to 0.
  return ($s1 eq $s2)  if $tol == 0;

  $l1 = length($s1);
  $l2 = length($s2);

  if ($l1 >= $l2) {
    $ldiff = $l1 - $l2;
    $ll = $l1;
  } else {
    $ldiff = $l2 - $l1;
    $ll = $l2;
  }
  return 0 if ( ($ldiff / $ll) > $tol );

  grep( $hist1{$_}++, split(//, $s1) );
  grep( $hist2{$_}++, split(//, $s2) );
  $diff = 0;

  grep( $histd{$_}++, keys %hist1 );
  @intersect = grep( $histd{$_}, keys %hist2 );

  foreach $c (@intersect) {
    $dt = $hist2{$c} - $hist1{$c};
    $dt = -$dt if $dt < 0;
    $diff += $dt;
    delete $hist1{$c};
    delete $hist2{$c};
  }

  grep( $diff += $hist1{$_}, keys %hist1 );
  grep( $diff += $hist2{$_}, keys %hist2 );

  return 0 if ( ($diff / $ll) > $tol );

  1;
}
