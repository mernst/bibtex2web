#!/usr/bin/perl
#
# Convert C3 (TERENA) def tables to the form used by bp.
#
# See: <http://www.nada.kth.se:80/i18n/c3/> for more info on C3.
#
# Written 19 November 1995 by Dana Jacobsen (dana@acm.org)
#
# As in all things seemingly, this began as a quick hack and got a lot
# bigger when it turned out to work quite well.

$title   = undef;
$package = undef;
$name    = undef;

while ( $ARGV[0] =~ /^-/ ) {
  $_ = shift;
  /^-pack$/  && do { $package = shift; next; };
  /^-title$/ && do { $title   = shift; next; };
  /^-name$/  && do { $name    = shift; next; };
  warn "Unrecognized option: $_\n";
}

$n = 0;
while (<>) {
  if (/^%/) {
    ($head, $com) = /^%(\S+)\s+(.*)/;
    $headers{$head} = $com;
  } elsif (/^'.... = ../) {
    ($uni, $hex, $com) = /^('....) = (..)(.*)/;

    $com =~ s/^\s+:/#/;
    $com =~ s/^#[\dA-F]{4,4} /# /;

    $table[hex($hex)]  = $uni;
    $comtab[hex($hex)] = $com;
    $n++;
  }
}

# Now try to parse out the headers.

($file, $version) = $headers{'COMMENT_CCS'} =~ /:\((\S+)\s+([^)]*)/;
$system = $headers{'CONV_SYST'};
($namel, $names) = $headers{'CCS'} =~ /:(.*)\s+\(([^)]*)/;
$width = $headers{'CCS_WIDTH'};

# Check that we read in the right number of entries.

if ($width == 8) {
  warn "Expected 256 entries, read $n\n" if $n != 256;
} elsif ($width == 7) {
  warn "Expected 128 entries, read $n\n" if $n != 128;
}

# Check to see how far we have to go before we differ from ISO-8859-1.

for ($s=0; $s < 255; $s++) {
  last if $s != hex( substr($table[$s], 1, 4) );
}

if ($s > 254) {
  $differt = "Table is ISO-8859-1 in all 8 bits.";
  $start = 256;
} elsif ($s > 126) {
  $differt = "Table is ISO-8859-1 in 7 bits.";
  $start = 128;
} else {
  $differt = "Table is ISO-8859-1 only in the first $s values.";
  $start = 0;
}

# Set up our information and print out header info

$name    = $names unless defined $name;
$title   = $names unless defined $title;
$package = $names unless defined $package;
$name    =~ s/\s+//g;
$title   =~ s/\s+//g;
$package =~ s/\s+//g;

&printheader;

# Print out umap.

if ($start >= $n) {
  print "\n# No differing table entries.\n";
} else {
  print "\%umap = (\n";
  for ($s=$start; $s < $n; $s++) {
    next unless defined $table[$s];
    print $table[$s], "', ", $s, ",  $comtab[$s]\n";
  }
  print ");\n\n";
  print "foreach \$f (keys \%umap) {\n";
  print "  \$nmap\[\$umap\{\$f\}\] = \$f;\n";
  print "}\nundef \$f;\n\n";
}

if ($start == 256) {
  &code8bit;
} elsif ($start == 128) {
  &code7bit;
} elsif ($start == 0) {
  &codeall;
} else {
  die "Unknown starting position: $start\n";
}




#-------------------------------------


sub printheader {

print<<EOHEAD;
#
# bibliography package for Perl
#
# $namel.
#
# Converted from C3 ($system) table.
# CCS:  '$file',  version '$version'.
# Read $n values ($width bit code).
# $differt
#
# Converted by C3toTab.pl, version 1.0, Dana Jacobsen (dana\@acm.org)
#

package bp_cs_$package;

######

\$bib::charsets{'$name', 'i_name'} = '$name';
\$bib::charsets{'$name', 'i_protection'} = 0;

\$bib::charsets{'$name', 'tocanon'}  = "bp_cs_${package}'tocanon";
\$bib::charsets{'$name', 'fromcanon'}  = "bp_cs_${package}'fromcanon";

######

EOHEAD

}


#-------------------------------------


sub code8bit {

print<<EOCEIGHT;

######

sub tocanon {
  local(\$_, \$protect) = \@_;

  \&panic("cs-$name tocanon called with no arguments!") unless defined \$_;
  \&bib::debugs("in cs-$name tocanon", 16, 'module');

  s/\$bib::cs_escape/\$bib::cs_char_escape/g;
  \$_;
}

EOCEIGHT

}

sub code7bit {

print<<EOCSEVEN;

######

sub tocanon {
  local(\$_, \$protect) = \@_;
  local(\$repl, \$unicode, \$can);

  &panic("cs-$name tocanon called with no arguments!") unless defined \$_;

  s/\$bib::cs_escape/\$bib::cs_char_escape/g;

  # The 7bit part is the same
  while (/([\\200-\\377])/) {
    \$repl = \$1;
    if (defined \$nmap[ ord(\$repl) ]) {
      \$can = \$nmap[ ord(\$repl) ];
      s/\$repl/\${bib::cs_ext}\$can/g;
    } else {
      \&bib::gotwarn("Could not convert $title character ".ord(\$repl)." to canon");
      s/\$repl//g;
    }
  }
  # Now we've moved all the 8bit characters to enABCD form.  Since most are
  # in the en00.. range, we'd like to move them back down.
  while (/\${bib::cs_ext}00(..)/) {
    \$repl = \$1;
    \$can = pack("C", hex(\$repl));
    s/\${bib::cs_ext}00\$repl/\$can/g;
  }

  \$_;
}

EOCSEVEN

}
