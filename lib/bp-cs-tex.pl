#
# bibliography package for Perl
#
# TeX character set.
#
# Dana Jacobsen (dana@acm.org)
# 22 January 1995 (last modified on 14 March 1996)
#
# These routines have gone through a major update in November 1995.
#
# This is still in beta.
# There are many characters not implemented, and the underlying charset
# code is not solid yet.
#
# Some ugly convolutions are gone through to make it run at a decent
# speed.  This code is _very_ timing sensitive.  On a typical 1043 record
# run, the first implementation ran at 83 seconds for tocanon, 28 seconds
# for fromcanon.  Two days of work brought this down to 1 second and 2
# seconds.
# Lesson:
#    If you're not careful, you may find the charset code dominating
#    your entire conversion time since it is run for every _field_, but
#    with some careful profiling, it can be very fast.
#

package bp_cs_tex;

######

$bib::charsets{'tex', 'i_name'} = 'tex';

$bib::charsets{'tex', 'tocanon'}   = "bp_cs_tex'tocanon";
$bib::charsets{'tex', 'fromcanon'} = "bp_cs_tex'fromcanon";

# This regexp should match any (La)TeX character that needs to be escaped.
$bib::charsets{'tex', 'toesc'}   = "([\$\\\\]|``|''|---)";
# XXXXX We have so many characters to protect, should we even bother?
$bib::charsets{'tex', 'fromesc'} = "[\\#\$\%\&{}_\|><\^~\200-\377]|${bib::cs_ext}|${bib::cs_meta}";

######

$cs_init = 0;

# package variables for anyone to use
$mine = '';
$unicode = '';
$can = '';

######

sub init_cs {

# Thorn and eth are really nasty since they don't exist in the standard TeX
# fonts.  This is what I came up with in r2b to fake it.  Fortunately they
# aren't used often.  Get the cmoer fonts if you want to do them right.
# My eth is pretty nice, but the thorn leaves a little to be desired.

%charmap = (
'00A1', "!'",                   # inverted exclamation mark
'00A2', '\leavevmode\hbox{\rm\rlap/c}',
'00A3', '{\pounds}',
'00A4', '$\spadesuit$',
'00A5', '\leavevmode\hbox{\rm\rlap=Y}',
'00A6', '\leavevmode
         \hbox{\hskip.4ex\hbox{\ooalign{\vrule width.2ex height.5ex depth.4ex\crcr
         \hfil\raise.8ex\hbox{\vrule width.2ex height.9ex depth0ex}\hfil}}}',
'00A7', '\S ',
'00A8', '{\"{ }}',
'00A9', '\leavevmode\hbox{\raise.6em\hbox{\copyright}}',
'00AA', '${}^{\b{\scriptsize a}}$',
'00AB', '$\scriptscriptstyle\ll$',
'00AC', '$\neg$',
'00AE', '\leavevmode\hbox{\raise.6em\hbox{\ooalign{{\mathhexbox20D}\crcr
         \hfil\raise.07ex\hbox{r}\hfil}}}',
'00AF', '{\={ }}',
'00B0', '${}^\circ$',
'00B1', '$\pm$',
'00B2', '${}^2$',
'00B3', '${}^3$',
'00B4', '{\'{ }}',
'00B5', '$\mu$',
'00B6', '\P ',
'00B7', '$\cdot$',
'00B8', '{\c{ }}',
'00B9', '${}^1$',
'00BA', '${}^{\b{\scriptsize o}}$',
'00BB', '$\scriptscriptstyle\gg$',
'00BC', '$1\over4$',
'00BD', '$1\over2$',
'00BE', '$3\over4$',
'00BF', '?`',                   # inverted question mark
'00C0', '{\`A}',
'00C1', q-{\'A}-,
'00C2', '{\^A}',
'00C3', '{\~A}',
'00C4', '{\"A}',
'00C5', '{\AA}',
'00C6', '{\AE}',
'00C7', '{\c{C}}',
'00C8', '{\`E}',
'00C9', q-{\'E}-,
'00CA', '{\^E}',
'00CB', '{\"E}',
'00CC', '{\`I}',
'00CD', q-{\'I}-,
'00CE', '{\^I}',
'00CF', '{\"I}',
'00D0', '\leavevmode\hbox{\ooalign{{D}\crcr
         \hskip.2ex\raise.25ex\hbox{-}\hfil}}',
'00D1', '{\~N}',
'00D2', '{\`O}',
'00D3', q-{\'O}-,
'00D4', '{\^O}',
'00D5', '{\~O}',
'00D6', '{\"O}',
'00D7', '$\times$',
'00D8', '{\O}',
'00D9', '{\`U}',
'00DA', q-{\'U}-,
'00DB', '{\^U}',
'00DC', '{\"U}',
'00DD', q-{\'Y}-,
'00DE', '\leavevmode\hbox{I\hskip-.6ex\raise.5ex\hbox{$\scriptscriptstyle\supset$}}',
'00DF', '{\ss}',
'00E0', '{\`a}',
'00E1', q-{\'a}-,
'00E2', '{\^a}',
'00E3', '{\~a}',
'00E4', '{\"a}',
'00E5', '{\aa}',
'00E6', '{\ae}',
'00E7', '{\c{c}}',
'00E8', '{\`e}',
'00E9', q-{\'e}-,
'00EA', '{\^e}',
'00EB', '{\"e}',
'00EC', '{\`\i}',
'00ED', q-{\'\i}-,
'00EE', '{\^\i}',
'00EF', '{\"\i}',
'00F0', '\leavevmode\hbox{\ooalign{$\partial$\crcr\hskip.8ex\raise.7ex\hbox{-}\hfil}}',
'00F1', '{\~n}',
'00F2', '{\`o}',
'00F3', q-{\'o}-,
'00F4', '{\^o}',
'00F5', '{\~o}',
'00F6', '{\"o}',
'00F7', '$\div$',
'00F8', '{\o}',
'00F9', '{\`u}',
'00FA', q-{\'u}-,
'00FB', '{\^u}',
'00FC', '{\"u}',
'00FD', q-{\'y}-,
'00FE', '\leavevmode\hbox{{\lower.3ex\hbox{\large l}}\hskip-.52ex o}',
'00FF', '{\"y}',
'0107', q-{\'c}-,
'010C', '{\vC}',
'010D', '{\vc}',
'0131', '{\i}',
'0159', '{\vr}',
'015F', '{\c{s}}',
'0160', '{\vS}',
'0161', '{\vs}',
'017A', q-{\'z}-,
'017C', '{\.z}',
'017E', '{\vz}',
# XXXXX
# Should these be surrounded by $ (math mode)?
# Also, what to do with \mu, which is listed twice?
'03B1', '\alpha',
'03B2', '\beta',
'03B3', '\gamma',
'03B4', '\delta',
'03B5', '\epsilon',
'03B6', '\zeta',
'03B7', '\eta',
'03B8', '\theta',
'03B9', '\iota',
'03BA', '\kappa',
'03BB', '\lambda',
'03BC', '\mu',
'03BD', '\nu',
'03BE', '\xi',
'03C0', '\pi',
'03C1', '\rho',
'03C2', '\varsigma',
'03C3', '\sigma',
'03C4', '\tau',
'03C5', '\upsilon',
'03C6', '\phi',
'03C7', '\chi',
'03C8', '\psi',
'03C9', '\omega',
'2007', '$\:$',
'2009', '$\,$',
'2192', '$\rightarrow',
'21D2', '$\Rightarrow$',
'2208', '\in',
'2260', '\ne',
'2264', '\le',
'2265', '\ge',
#  '0240', '~',
'2715', '\times',
# These are really meta, but I don't know how to make it work.
# Used to be 1110, but I don't know how to convert that to ISO-8859-1.
# '2029', '\par',			# Unicode paragraph separator
# '000A', '\\',
);

# This mapping is only used in the fromcanon section.  We'll do these by hand
# in the tocanon mapping.
%charmap2 = (
'00A0', '~',
'00AD', '-',
'2002', '\ ',
'2003', '\ \ ',
'2013', '--',
'2014', '---',
'201C', '``',
'201D', "''",
'03BF', 'o',
);

# Blah.  TeX has such a non-uniform way of handling characters that this is
# really slow.  I'm going to try some optimizations for the tocanon code
# since that will be heavily used.  It makes this stuff less uniform though.
# Remember that we don't have a full TeX parser, or even a partial one.

# Build up a search string to do the reverse map.
$cmap_to_eval = '';
$cmap_from8_eval = '';
$cmap_to_eval_1 = '';
$cmap_to_eval_2 = '';
%rmap = ();
%accent = ();
my $cmapvar = "\$text =~ "; # define to "" to operate on $_


# Step 1: Build a reverse map
while (($unicode, $mine) = each %charmap) {
  $rmap{$mine} = $unicode;
}
# Step 2: walk through the keys in sorted order
foreach $mine (sort keys %rmap) {
  $can = &bib::unicode_to_canon( $rmap{$mine} );
  my $mineE = $mine;
  $mineE =~ s/(\W)/\\$1/g;
  # The various maps for tocanon
  if ($mine =~ /^{\\([`'^"~])([\w])}$/) {
    $accent{$1 . $2} = $can;
  } elsif ($mine =~ /^{\\([vc])(\w)}$/) {
    $accent{$1 . $2} = $can;
  } elsif ($mine =~ /^{\\([vc]){(\w)}}$/) {
    $accent{$1 . $2} = $can;
  } elsif ($mine =~ /leavevmode/) {
    $cmap_to_eval_1 .= "$cmapvar s/$mineE/$can/g;\n";
  } elsif ($mine =~ /\$/) {
    $cmap_to_eval_2 .= "$cmapvar s/$mineE/$can/g;\n";
    # Try adding in without surounding dollar signs.
    if ($mine =~ /^\$(.*)\$$/) {
      $mineE_nonmath = $1;
      $mineE_nonmath =~ s/(\W)/\\$1/g;
      $cmap_to_eval_2 .= "$cmapvar s/$mineE_nonmath/$can/g;\n";
    }
  } else {
    $cmap_to_eval   .= "$cmapvar s/$mineE/$can/g;\n";
  }
  if ( length($can) == 1 ) {
    $cmap_from8_eval .= "$cmapvar s/$can/$mineE/g;\n";
  }
}
$cmap_from8_eval .= "$cmapvar s/\\240/\\~/g;\ns/\\255/-/g;";
# leave rmap

#%map_diac = (
#'tilde',	'\~{}',
#'circ',		'\^{}',
#'lcub',		'$\lbrace$',
#'rcub',		'$\rbrace$',
#'bsol',		'$\backslash$',
#);

# Careful. This is from canonical only.
# Conversion to canonical must be done by hand in change_tex_fonts().
%metamap = (
'3100', '{',   # Begin protection
'3110', '}',   # End   protection
               # fonts
'0101', '{\rm ',
'0102', '{\it ',
'0103', '{\bf ',
'0104', '{\tt ',
'0111', '}',
'0112', '}',
'0113', '}',
'0114', '}',
'0110', '}',	# previous font.  We don't need a font stack to handle it.
'1300', '\item',
'1301', '\begin{itemize}',
'1311', '\end{itemize}',
'1302', '\begin{enumerate}',
'1312', '\end{enumerate}',
'2102', '{\em ',
'2112', '}',
'1120', '\par ', 	   # ought to be 2029, Unicode paragraph separator
);

  $cs_init = 1;
}

######

sub tocanon {
  local($text, $protect) = @_;
  my $debug_tocanon = 0;
  # $debug_tocanon = 1;
  if ($debug_tocanon) { print STDERR "bp-cs-tex::tocanon <= $text\n"; }

  # unprotect the TeX characters
  if ($protect) {
    # input  is assumed to be in TeX format, before _any_ canon processing.
    # output is TeX format, but with raw magic characters.
    $text =~ s/\$>\$/>/g;
    $text =~ s/\$<\$/</g;
    $text =~ s/\$\|\$/\|/g;
    $text =~ s/\\_/_/g;
    $text =~ s/\$\\rbrace\$/}/g;
    $text =~ s/\$\\lbrace\$/{/g;
    $text =~ s/\\\&/\&/g;
    $text =~ s/\\\%/\%/g;
    $text =~ s/\\\$/\$/g;
    $text =~ s/\\#/#/g;
  }

  if ($text =~ /-/) {
    $text =~ s/\$-\$/${bib::cs_ext}2212/go;
    $text =~ s/([^-])--([^-])/$1${bib::cs_ext}2013$2/go;
    $text =~ s/([^-])---([^-])/$1${bib::cs_ext}2014$2/go;
    # leave -
  }
  if ($text =~ /~/) {
    1 while ($text =~ s/([^\\])~/$1\240/g); # should be 00A0?
  }
  $text =~ s/\\ \\ /${bib::cs_ext}2003/go;
  $text =~ s/\\ /${bib::cs_ext}2002/go;
  # Rather than eliminating this, I suppose I could make up a character to
  # take its place.
  $text =~ s/\\@//g;

  $text =~ s/([^\\])\\-/$1/g;	# discretionary line break

  $text =~ s/\\smaller\b//g;

  # Do these really need to be here, or could I move them back up?
  $text =~ s/``/${bib::cs_ext}201C/go;
  $text =~ s/''/${bib::cs_ext}201D/go;

  ## This test assumes that if there is no backslash, there is nothing more
  ## to do.  So characters like "``", "''", "~" must be handled above.
  # Can we go now?
  return $text unless ($text =~ /\\/);

  # (Optional) charset initialization
  &init_cs unless $cs_init;

  if ($text =~ /\\[`'^"~vc][{ ]?[\w]/) {
    # ISO -- we try {\"{c}}, {\"c}, \"{c}, \"c
    #                        ^^^^^
    #                      preferred
    #
    # XXXXX What do we do about all the other ways they can try?
    #       mgnet.bib uses {\" u} a lot.  (got this way now)

    while ($text =~ /{\\([`'^"~vc])( ?)([\w])}/) {
      $can = $accent{$1 . $3};
      $mine = "{\\$1$2$3}";
      if (!defined $can) {
        &bib::gotwarn("Can't convert TeX '$mine' in $text to canon");
        $can = '';
      }
      $mine =~ s/(\W)/\\$1/g;
      $text =~ s/$mine/$can/g;
    }
    while ($text =~ /{\\([`'^"~vc]){([\w])}}/) {
      $can = $accent{$1 . $2};
      $mine = "{\\$1\{$2\}}";
      if (!defined $can) {
        &bib::gotwarn("Can't convert TeX '$mine' in $text to canon");
        $can = '';
      }
      $mine =~ s/(\W)/\\$1/g;
      $text =~ s/$mine/$can/g;
    }
    while ($text =~ /\\([`'^"~vc]){([\w])}/) {
      $can = $accent{$1 . $2};
      $mine = "\\$1\{$2\}";
      if (!defined $can) {
        &bib::gotwarn("Can't convert TeX '$mine' in $text to canon");
        $can = '';
      }
      $mine =~ s/(\W)/\\$1/g;
      $text =~ s/$mine/$can/g;
    }
    while ($text =~ /\\([`'^"~])( ?)([\w])/) {
      $can = $accent{$1 . $3};
      $mine = "\\$1$2$3";
      if (!defined $can) {
        &bib::gotwarn("Can't convert TeX '$mine' in $text to canon");
        $can = '';
      }
      $mine =~ s/(\W)/\\$1/g;
      $text =~ s/$mine/$can/g;
    }

    # This unfortunately matches \cr and \circ.  We aren't doing a loop
    # any more, so it's not even necessary anymore.  Let the standard
    # routine try to match and give the normal error message on failure.
    #while ($text =~ s/(\\[`'^"~vc][{ ]?[\w])//) {
    #  &bib::gotwarn("Couldn't parse TeX accented character: $1!");
    #}

    return $text unless ($text =~ /\\/);
  } # end of standard accented characters

  # XXXXX What about the v, c, and other accents?  Do we need another
  #       section for those, or can we fit them in above?

  if ($text =~ /leavevmode/) {
    eval $cmap_to_eval_1;
  }
  if ($text =~ /\$/) {
    eval $cmap_to_eval_2;
  }
  eval $cmap_to_eval;

  $text =~ s/\\\^{}/\^/g;
  $text =~ s/\\~{\s?}/~/g;

  # hopefully we're done by now
  return $text unless ($text =~ /\\/);

  $text = change_tex_fonts($text);

  return $text unless ($text =~ /\\/);

  $text =~ s/\$\\backslash\$/$bib::cs_temp/g;
  if ($text !~ /\\/) {
    $text =~ s/$bib::cs_temp/\\/go;
    return $text;
  }
  $text =~ s/$bib::cs_temp/\\/go;

  # I give up.
  # XXXXX We really ought to remove the escape and meta characters we have
  #       converted when we give them this warning.
  &bib::gotwarn("Unknown TeX characters (backslashes) in '$text'");

  if ($debug_tocanon) { print STDERR "bp-cs-tex::tocanon => $text\n"; }

  $text;
}

# This also takes care of other cs_meta translations in %metamap.
sub change_tex_fonts {
  my ($string) = @_;

  # font changes
  # This doesn't work all that well, but most bibliographies are simple
  $string =~ s/\{\\rm ([^{}]*)\}/${bib::cs_meta}0101$1${bib::cs_meta}0110/g;
  $string =~ s/\{\\it ([^{}]*)\}/${bib::cs_meta}0102$1${bib::cs_meta}0110/g;
  $string =~ s/\{\\bf ([^{}]*)\}/${bib::cs_meta}0103$1${bib::cs_meta}0110/g;
  $string =~ s/\{\\tt ([^{}]*)\}/${bib::cs_meta}0104$1${bib::cs_meta}0110/g;
  $string =~ s/\{\\em ([^{}]*)\}/${bib::cs_meta}2102$1${bib::cs_meta}2112/g;
  $string =~ s/\\bgroup\\rm ([^{}]*)\\egroup/${bib::cs_meta}0101$1${bib::cs_meta}0110/g;
  $string =~ s/\\bgroup\\it ([^{}]*)\\egroup/${bib::cs_meta}0102$1${bib::cs_meta}0110/g;
  $string =~ s/\\bgroup\\bf ([^{}]*)\\egroup/${bib::cs_meta}0103$1${bib::cs_meta}0110/g;
  $string =~ s/\\bgroup\\tt ([^{}]*)\\egroup/${bib::cs_meta}0104$1${bib::cs_meta}0110/g;
  $string =~ s/\\bgroup\\em ([^{}]*)\\egroup/${bib::cs_meta}2102$1${bib::cs_meta}2112/g;
  $string =~ s/\\(?:text|math)rm\{([^{}]*)\}/${bib::cs_meta}0101$1${bib::cs_meta}0110/g;
  $string =~ s/\\(?:text|math)it\{([^{}]*)\}/${bib::cs_meta}0102$1${bib::cs_meta}0110/g;
  $string =~ s/\\(?:text|math)bf\{([^{}]*)\}/${bib::cs_meta}0103$1${bib::cs_meta}0110/g;
  $string =~ s/\\(?:text|math)tt\{([^{}]*)\}/${bib::cs_meta}0104$1${bib::cs_meta}0110/g;
  $string =~ s/\\textem\{([^{}]*)\}/${bib::cs_meta}2102$1${bib::cs_meta}2112/g;
  $string =~ s/\\emph\{([^{}]*)\}/${bib::cs_meta}2102$1${bib::cs_meta}2112/g;

  $string = &bib::font_check($string) if /${bib::cs_meta}01/o;
  # done with font changing

  $string =~ s/\{?\\,---\\,\}?/ ${bib::cs_meta}2014 /g;	# not sure why I need this
  $string =~ s/\b--\b/${bib::cs_meta}2013/g;	# not sure why I need this
  $string =~ s/\\,/ /g; 		# not sure why I need this
  $string =~ s/\\par\b/${bib::cs_meta}1120/g;
  $string =~ s/\\cite\{([^{}]+)\}/[$1]/g;
  $string =~ s/\$\$?([^\$]+)\$\$?/${bib::cs_meta}0102$1${bib::cs_meta}0110/g;
  $string =~ s/\\(log)\b/${bib::cs_meta}0102$1${bib::cs_meta}0112/g;
  $string =~ s/\\url\{([^{}]+)\}/${bib::cs_meta}2200${bib::cs_meta}2300$1${bib::cs_meta}2310$1${bib::cs_meta}2210/g;

  $string =~ s/\\item\b/${bib::cs_meta}1300/g;
  $string =~ s/\\begin{itemize}/${bib::cs_meta}1301/g;
  $string =~ s/\\end{itemize}/${bib::cs_meta}1311/g;
  $string =~ s/\\begin{enumerate}/${bib::cs_meta}1302/g;
  $string =~ s/\\end{enumerate}/${bib::cs_meta}1312/g;

  return $string;
}

######

sub fromcanon {
  my ($text, $protect) = @_;
  my $debug_fromcanon = 0;
  # $debug_fromcanon = 1;
  if ($debug_fromcanon) { print STDERR "bp-cs-tex::fromcanon <= $text\n"; }

  my $repl;
  # We no longer check for font matching here, as that should be done by a
  # call to bib'font_check in the tocanon code.

  $text =~ s/${bib::cs_meta}2200${bib::cs_meta}2300([^{}]+)${bib::cs_meta}2310\1${bib::cs_meta}2210/\\url\{$1\}/g;

  if ($protect) {
    $text =~ s/\\/$bib::cs_temp/go;
    $text =~ s/#/\\#/g;
    $text =~ s/\$/\\\$/g;
    $text =~ s/\%/\\\%/g;
    $text =~ s/\&/\\\&/g;
    $text =~ s/{/\$\\lbrace\$/g;
    $text =~ s/}/\$\\rbrace\$/g;
    $text =~ s/_/\\_/g;
    $text =~ s/\|/\$\|\$/g;
    $text =~ s/>/\$>\$/g;
    $text =~ s/</\$<\$/g;
    $text =~ s/\^/\\^{}/g;
    $text =~ s/~/\\~{}/g;
    $text =~ s/$bib::cs_temp/\$\\backslash\$/go;
  }
  if ($debug_fromcanon) { print STDERR "bp-cs-tex::fromcanon (1) : $text\n"; }

  while ($text =~ /([\200-\237])/) {
    $repl = $1;
    $unicode = &bib::canon_to_unicode($repl);
    &bib::gotwarn("Can't convert ".&bib::unicode_name($unicode)." to TeX");
    $text =~ s/$repl//g;
  }

  if ($debug_fromcanon) { print STDERR "bp-cs-tex::fromcanon (2) : $text\n"; }

  &init_cs unless $cs_init;

  #if ($text =~ /[\240-\377]/) {
  #  eval $cmap_from8_eval;
  #}
  $text =~ s/\240/~/g;
  $text =~ s/\255/-/g;
  while ($text =~ /([\240-\377])/) {
    $repl = $1;
    $unicode = &bib::canon_to_unicode($repl);
    $text =~ s/$repl/$charmap{$unicode}/g;
  }

  if ($debug_fromcanon) { print STDERR "bp-cs-tex::fromcanon (3) : $text\n"; }

  # Maybe we can go now?
  return $text unless ($text =~ /$bib::cs_escape/o);

  if ($debug_fromcanon) { print STDERR "bp-cs-tex::fromcanon (4) : $text\n"; }

  while ($text =~ /${bib::cs_ext}(....)/) {
    $unicode = $1;
    if ($unicode =~ /^00[0-7]/) {
      1 while $text =~ s/${bib::cs_ext}00([0-7].)/pack("C", hex($1))/ge;
      next;
    }
    defined $charmap{$unicode}  && $text =~ s/${bib::cs_ext}$unicode/$charmap{$unicode}/g
                                && next;
    defined $charmap2{$unicode} && $text =~ s/${bib::cs_ext}$unicode/$charmap2{$unicode}/g
                                && next;

    $can = &bib::unicode_approx($unicode);
    defined $can  &&  $text =~ s/$bib::cs_ext$unicode/$can/g  &&  next;

    &bib::gotwarn("Can't convert ".&bib::unicode_name($unicode)." to TeX");
    $text =~ s/${bib::cs_ext}$unicode//g;
  }

  while ($text =~ /${bib::cs_meta}(....)/) {
    $repl = $1;
    defined $metamap{$repl} && $text =~ s/${bib::cs_meta}$repl/$metamap{$repl}/g
                            && next;

    $can = &bib::meta_approx($repl);
    defined $can  &&  $text =~ s/$bib::cs_meta$repl/$can/g  &&  next;

    &bib::gotwarn("Can't convert ".&bib::meta_name($repl)." to TeX");
    $text =~ s/${bib::cs_meta}$repl//g;
  }

  if ($debug_fromcanon) { print STDERR "bp-cs-tex::fromcanon => $text\n"; }

  $text;
}

######


#######################
# end of package
#######################

1;
