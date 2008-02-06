#
# bibliography package for Perl
#
# BibTeX routines
#
# Dana Jacobsen (dana@acm.org)
# 8 July 1995 (last modified 30 November 1995)
#
# 30 Nov 95: Changed the way string parsing works.  It used to do a search
#            and replace over the entire string, but some bibliographies make
#            a string named, "el" for instance, which will just trash the
#            entire file.  So we look for _1_ unquoted string on the same
#            line as the field name.  That's a lot safer, but also won't
#            properly handle multiple strings on a line, or strings not in
#            the first position.  Those are fairly rare though.
#
# XXXXX Parsing BibTeX is extremely difficult to do correctly in Perl.  The
#       proper thing to do in my opinion is to write a yacc parser and compile
#       that in.  Not only will it be able to handle more bizarre cases
#       properly, but it will probably be much faster.

package bp_bibtex;

$version = "bibtex (dj 18 dec 96)";

######

&bib::reg_format(
  'bibtex',    # name
  'btx',       # short name
  'bp_bibtex', # package name
  'tex',       # default character set
  'suffix is bib',
# our functions
  'open is standard',
  'close is standard',
  'write is standard',
  'options',
  'read',
  'explode',
  'implode',
  'tocanon',
  'fromcanon',
  'clear',
);

######

# Set to 0 for handling bibclean (faster, but makes a lot of assumptions)
#        1 for arbitrary bibtex
#
$opt_complex = 1;

# Set this to 0 if we want to ignore crossref fields.  Handling them may use
# a very large amount of memory (about the same as the size of the input file).
#
$opt_crossref = 1;

# Set this to 1 if we want to ignore unrecognized fields.
# if 0, they are included in the output, but a warning message is generated.
#
$opt_omit_unknown = 0;

######

sub options {
  my ($opt) = @_;

  &bib::panic("bibtex options called with no arguments!") unless defined $opt;
  &bib::debugs("parsing bibtex option '$opt'", 64);
  return undef unless $opt =~ /=/;
  my ($field, $val) = split(/\s*=\s*/, $opt, 2);
  &bib::debugs("option split: $_ = $val", 8);
  if ($field =~ /^complex$/) {
    $opt_complex = &bib::parse_num_option($val);
    return 1;
  }
  if ($field =~ /^crossref$/) {
    $opt_crossref = &bib::parse_num_option($val);
    return 1;
  }
  if ($field =~ /^omit_unknown$/) {
    $opt_omit_unknown = 1;
    return 1;
  }
  undef;
}

######

# This is only used for complexity 0 now.
$glb_eval_repl = 0;

# Initialize the macro list with the entries from plain.bst.
# XXXXX At some point we need to get these from a configuration file
%glb_replace_builtin = (
'jan',	'January',
'feb',	'February',
'mar',	'March',
'apr',	'April',
'may',	'May',
'jun',	'June',
'jul',	'July',
'aug',	'August',
'sep',	'September',
'oct',	'October',
'nov',	'November',
'dec',	'December',
'acmcs',	'ACM Computing Surveys',
'acta',		'Acta Informatica',
'cacm',		'Communications of the ACM',
'ibmjrd',	'IBM Journal of Research and Development',
'ibmsj',	'IBM Systems Journal',
'ieeese',	'IEEE Transactions on Software Engineering',
'ieeetc',	'IEEE Transactions on Computers',
'ieeetcad', 'IEEE Transactions on Computer-Aided Design of Integrated Circuits',
'ipl',		'Information Processing Letters',
'jacm',		'Journal of the ACM',
'jcss',		'Journal of Computer and System Sciences',
'scp',		'Science of Computer Programming',
'sicomp',	'SIAM Journal on Computing',
'tocs',		'ACM Transactions on Computer Systems',
'tods',		'ACM Transactions on Database Systems',
'tog',		'ACM Transactions on Graphics',
'toms',		'ACM Transactions on Mathematical Software',
'toois',	'ACM Transactions on Office Information Systems',
'toplas',	'ACM Transactions on Programming Languages and Systems',
'tcs',		'Theoretical Computer Science',
);
%glb_replace = %glb_replace_builtin;
$glb_replace = '';

$glb_noreadahead = 0;
@glb_readahead = ();
%glb_crossref_entries = ();
%glb_crossref_needed = ();

$ent = '';


$protectB = "${bib::cs_meta}3100";
$protectE = "${bib::cs_meta}3110";
######

# XXXXX todo:
#
#	don't just throw away preamble statements
#       mismatched braces in an entry will make us read the whole file
#               looking for the ending brace!!
#
# It ssems like reading BibTeX records are perfect for a program like
# yacc/lex or a similar state machine.  The format is nice and regular,
# but it contains too many oddities for a nice perl implmentation.  The
# best way I can describe the problem is that it is character based, rather
# than line based, like refer.  We can even have the end of one record on
# the same line as the beginning of the next.
#
#   The opt_complex variable can be set to 0 to remove most of the time-
# consuming regex stuff.  This will only work if the file has been run
# through bibclean, or is otherwise "regular" (the @ of a start record
# must be flush left, only { and not scribe's ( are allowed to surround
# a record, and records end with a single } flush left by itself).
#
# This would be a perfect use for perl5's interface to a C program.  A
# fairly simple lex/yacc parser could be written and be _much_ faster
# as well as less error prone.
#
# XXXXX Break this out into subroutines, esp for string parsing.
#
sub read {
  local($file) = @_;
  local($_);
  my ($type);

  # XXXXX A single readahead for all files.  Needs to be split somehow.
  if (@glb_readahead && (!$glb_noreadahead)) {
    return shift @glb_readahead;
  }

  BREAD: {
    if ($opt_complex == 0) {
      while (<$bib::glb_current_fh>) {
        last if /^\@/;
      }
      return undef if eof;
      $ent = $_;

      $bib::glb_vloc = sprintf("line %5d", $.);

      ($type) = /^\@(\w+)\{/;
      return &bib::goterror("Unable to parse field $ent")  unless defined $type;

      # skip comments
      redo BREAD if $type =~ /^comment/i;
      # we really ought to do something with this instead of tossing it
      redo BREAD if $type =~ /^preamble/i;

      if ($type =~ /^string/i) {
        # XXXXX should handle multi-line string statements.
        my ($name, $value);
        if ( ($name,$value) = /^\@string{(\S+)\s*=\s*\"([^\"]*)\"}$/i) {
          $name =~ s/(\W)/\\$1/g;   # quote special chars
          $name =~ s/\\ / /g;
          $value =~ s/(\W)/\\$1/g;
          $value =~ s/\\ / /g;
          $glb_replace .= "s/\\b$name\\b/$value/g;\n";
          $glb_eval_repl = 1;
          redo BREAD;
        } else {
          &bib::gotwarn("Could not parse field $ent");
        }
      }

      while (<$bib::glb_current_fh>) {
        $ent .= $_;
        last if  /^\}\s*$/;
      }
    } elsif ($opt_complex == 1) {

      # Assumptions made about format:
      #
      #   An entry must start on a line of its own, so this is ok:
      #       @ string { jgg1 = "journal of gnats" }
      #     But this is not:
      #       @string{j1 = "journal1"}  @proceedings{foo, author="joe"}
      #
      #   There are no string expansions inside string definitions.  OK:
      #       @string(jgg2 = "journal" # " of " # "gnats" }
      #     But this is not:
      #       @string(j2 = j1 # " of Imaging")

      my ($delim);

      while (<$bib::glb_current_fh>) {
        if (/^\s*\@/) {
          $ent = $_;
          last;
        }
      }
      return undef if eof;

      $bib::glb_vloc = sprintf("line %5d", $.);

      ($type, $delim) = $ent =~ /^\s*\@\s*(\w+)\s*([{(])/;
      return &bib::goterror("Unable to parse field $ent")  unless defined $type;
      $type =~ tr/A-Z/a-z/;

      # XXXXX We should do something with comment and preamble values

      if ($type eq 'comment') {
        $ent = &read_until_match($ent, $delim, 0);
        redo BREAD;
      }

      if ($type eq 'preamble') {
        $ent = &read_until_match($ent, $delim, 0);
        redo BREAD;
      }

      if ($type eq 'string') {
        my ($name, $value);
        my $rdelim =  '}';
        $rdelim = ')' if $delim eq '(';

        $ent = &read_until_match($ent, $delim, 0);

        $delim  =~ s/(\W)/\\$1/g;
        $rdelim =~ s/(\W)/\\$1/g;

        $ent =~ s/^\s*\@\s*string\s*$delim\s*//i;
        eval "\$ent =~ s/\\s*$rdelim\[^$rdelim\]*\$//;";

        $ent = &do_concat($ent) if ($ent =~ /#/);

        if ( ($name,$value) = $ent =~ /^(\S+)\s*=\s*(\w+)\s*$/ ) {
          # @string{name = macro}
          $macro_expansion = &macro_expansion($value);
          if (defined($macro_expansion)) {
            $ent = "$name = \"$macro_expansion\"";
          }
        }
        if ( ($name,$value) = $ent =~ /^(\S+)\s*=\s*[{"(]((.|\n)*)[}")]$/ ) {
          # @string{name = "value"}
          if ($name =~ /["#\%'(),={}]/) {
            &bib::gotwarn("Illegal string name: $name");
          } else {
            $name =~ tr/A-Z/a-z/;
            # Permit redefinition of built-ins without warning.
            if ((defined $glb_replace{$name})
                && (! defined $glb_replace_builtin{$name})) {
              &bib::gotwarn("Redefinition of string: $name");
            }
            #$value =~ s/(\W)/\\$1/g;
            $glb_replace{$name} = $value;
            $glb_eval_repl = 1;
            &bib::debugs("new string $name = '$value'", 32);
          }
        } else {
          &bib::gotwarn("Couldn't parse string entry <<<$ent>>>");
        }
        redo BREAD;
      }

      # All other types
      $ent = &read_until_match($ent, $delim, 1);

      if ($ent =~ /#/) {
        my $delim_pos = index($ent, $delim);
        $delim_pos++;
        substr($ent, $delim_pos) = &do_concat( substr($ent, $delim_pos) );
      }
      return $ent;

    } else {
      &bib::goterror("Unknown complexity level asked for");
    }
  }  # end of BREAD

  $_ = $ent;
  if ( ($opt_complex == 0) && $glb_eval_repl ) {
    study;
    eval $glb_replace;
    $@ && return &bib::goterror("Error in string eval, $@");
  }
  $_;
}


sub read_until_match {
  my ($line, $lmatch, $do_string_matching) = @_;
  my $braces = 0;
  my ($macro, $mfield);
  local($_);

  if ($lmatch eq '{') {
    $rmatch = '}';
  } elsif ($lmatch eq '(') {
    $rmatch = ')';
  } elsif ($lmatch eq '"') {
    $rmatch = '"';
  } else {
    &bib::gotwarn("Unknown left match character: $lmatch");
    $rmatch = $lmatch;
  }

  $lmatch =~ s/(\W)/\\$1/g;
  $rmatch =~ s/(\W)/\\$1/g;

  while ($line =~ /$lmatch/g) { $braces++; }
  while ($line =~ /$rmatch/g) { $braces--; }
  if ($braces < 0) {
    &bib::goterror("negative match level looking for $lmatch$rmatch");
  }
  return $line if ($braces <= 0);

  while (<$bib::glb_current_fh>) {
    if ($do_string_matching) {
      # XXXXX Check that this is right.
      #       This will match a left string.  Concatenation will then only
      #       have to worry about right strings.
      if (/^(\s*(\S+)\s*=\s*)([^\"\#%\'(),={}\s]+)/) {
        $mfield = $2;
        $macro = $3;
        $macro_expansion = &macro_expansion($macro, ((defined $i_order{$mfield})
						     ? " in $mfield field"
						     : undef));
        if (defined($macro_expansion)) {
          s/^(\s*\S+\s*=\s*)$macro/$1"$macro_expansion"/;
        }
      }
    }
    $line .= $_;
    while (/$lmatch/g) { $braces++; }
    while (/$rmatch/g) { $braces--; }
    last if ($braces <= 0);
    # XXXXX We should try to detect an overflow -- after reading too many lines
  }
  if (eof && ($braces > 0)) {
    &bib::gotwarn("File ended while still reading record");
  }
  if ($braces < 0) {
    &bib::goterror("negative match level looking for $lmatch$rmatch");
  }
  $line;
}


#
# This subroutine handles concatenating strings that are seperated with
# a pound sign ('#').  It also will do string substitution for defined
# string to the right of the concatenation symbol.
#
sub do_concat {
  my ($rest) = @_;

  return $rest unless $rest =~ /#/;

  # This is _very_ ugly.
  # Regular expressions just aren't powerful enough to do this.

  my ($left, $right);
  my $bracelev = 0;
  my $quotes = 0;
  my $finished_string = "";
  my ($macro);
  my $string_term = "";

  $rest =~ s/$bib::cs_escape/$bib::cs_char_escape/go;

  while ($rest =~ /[^\\]#/) {
    ($left, $right) = split(/#/, $rest, 2);
    while ($left =~ /\{/g) { $bracelev++; }
    while ($left =~ /\}/g) { $bracelev--; }
    while ($left =~ /"/g)  { $quotes++; }
#print STDERR ">>\n$left\n==== $bracelev/$quotes ====\n$right<<\n\n";
    if ( ($bracelev <= 0) && ($quotes % 2 == 0) ) {
      # The # occured outside of their text, so we concatenate

      # Remember: if $left is changed, $quotes and $bracelev must be updated
      ## left side, checking for macro
      if ($left =~ s/\}\s*$//) {
        # case:  {foo} # ...
        $bracelev++;
        $string_term = '}';
      } elsif ($left =~ s/"\s*$//) {
        # case:  "foo" # ...
        $quotes--;
        $string_term = '"';
      } else {
        # case:  macro # ...

        if ($left =~ /([^"#%'(),={}\s]+)\s*$/) {
          $macro = $1;
          $macro_expansion = &macro_expansion($macro);
          if (defined($macro_expansion)) {
            $left =~ s/$macro\s*$/$macro_expansion$string_term/;
          }
        } else {
          &bib::gotwarn("Unknown text '$1' found.");
        }

        $left =~ s/(\S+)\s*$/\"$1/;
        $quotes++;
        $string_term = '\"';

        # # MDE:  This appears to expect that macros will only be abutted
        # # with things that end in digits, or some such.
        # if ($left !~ /\"\d+$/) {
        #   &bib::gotwarn("left string encountered during concatenation");
	#   &bib::gotwarn("left=$left, quotes=$quotes");
        # }
      }

      ## right side, checking for macro
      if ($right =~ s/^\s*([{"])//) {
        # case:  ... # "foo"
        # We need to check for the case of {foo} # "bar", and "foo" # {bar}
        if ( ($string_term eq '}') && ($1 eq '"') ) {
          $right =~ s/^([^"]*)"/$1\}/;
        }
        if ( ($string_term eq '"') && ($1 eq '{') ) {
          $left =~ s/"([^"]*)$/\{$1/;
          $quotes--;  $bracelev++;
        }
      } else {
        # case:  ... # macro
        if ($right =~ /^\s*([^"#%'(),={}\s]+)/) {
          $macro = $1;
          $macro_expansion = &macro_expansion($macro);
          if (defined($macro_expansion)) {
            $right =~ s/^\s*$macro/$macro_expansion$string_term/;
          }
        } else {
          &bib::gotwarn("Unknown text '$1' found.");
        }
      }
    } else {
      # It's inside their text, so leave it
      $left .= "$bib::cs_temp";
    }
    $finished_string .= $left;
    $rest = $right;
  }
  $finished_string .= $rest;

  $finished_string =~ s/$bib::cs_temp/#/go;
  $finished_string =~ s/$bib::cs_char_escape/$bib::cs_escape/go;
  $finished_string;
}

######

sub explode {
  my ($rec) = @_;
  my (%be_entry);
  my (@e_values);
  my ($fld, $val);

  # This is potentially dangerous because:
  #  * it can catch things like ", v=" in the middle of a field; example:
  #        from O(n v^6) (n=program size, v=objects that may have pointers)
  #  * it does the wrong thing when multiple fields are defined on one line
  #  * it cannot deal with fields whose names contain a hyphen.
  # I should beware potential problems here, but they will probably be rare.
  # (The Emacs equivalent of this regular expression is
  #  ",[ \t\n\r\f]*\\(\\sw+\\)[ \t\n\r\f]*=[ \t\n\r\f]*"
  #  because bibtex-mode gives \n the character class of "comment starter".)
  @e_values = split(/,\s*(\w+)\s*=\s*/, $rec);
  ($be_entry{'TYPE'}, $be_entry{'CITEKEY'}) =
       ( shift(@e_values) =~ /^\s*\@\s*(\w+)\s*[{(]\s*(\S+)/ );
  &bib::goterror("error exploding bibtex record $rec") unless scalar(@e_values) > 1;
  # XXXXX 17 Dec 96, Changed ,?\s+[ to ,?\s*[
  $e_values[$#e_values] =~ s/\s*,?\s*[})]\s*$//;  # zap the final delimiter
  while (@e_values) {
      ($fld, $val) = splice(@e_values, 0, 2);
      $fld =~ tr/A-Z/a-z/;
      $val =~ s/^\s*\{((.|\n)*)\}\s*$/$1/
	|| $val =~ s/^\s*\"((.|\n)*)\"\s*$/$1/;
      # XXXXX Check to see if squeezing spaces here is ok.
      $val =~ s/\s+/ /g;
      # XXXXX If there are multiple fields of the same kind we will end
      #       up throwing away all but the last value!
      $be_entry{$fld} = $val;
      # print STDERR "field = $fld, val = $val\n";
  }
  if (! defined $be_entry{'basefilename'}) {
      # print STDERR "Using citekey $be_entry{'CITEKEY'} as basefilename\n";
      my $citekey = $be_entry{'CITEKEY'};
      $citekey =~ s/:/_/g;      # URLs shouldn't contain colons
      $citekey =~ s:/:_:g;
      $be_entry{'basefilename'} = $citekey;
  }
  # warning: crossref_fill copies any missing fields into this entry
  # from the crossref entry, so set "default values" before or after
  # crossref_fill as appropriate (e.g., year should be taken from crossref,
  # but basefilename should be taken from citekey, as above).
  if ($opt_crossref && defined $be_entry{'crossref'}) {
    %be_entry = &crossref_fill(%be_entry);
  }
  %be_entry;
}

######

# This is the ordering r2b uses.
%i_order = (
'key',		10,
'author',	20,
'affiliation',	25,
'editor',	30,
'title',	40,
'booktitle',	50,
'institution',	60,
'school',	70,
'journal',	80,
'type',		90,
'series',	100,
'volume',	110,
'number',	120,
'edition',	130,
'chapter',	140,
'pages',	150,
'publisher',	160,
'address',	170,
'month',	180,
'year',		190,
'price',	200,
'copyright',	210,
'keywords',	220,
'mrnumber',	230,
'language',	240,
'annote',	250,
'isbn',		260,
'ISBN',		261,
'issn',		270,
'ISSN',		271,
'subject',      275,
'abstract',	280,
'note',		290,
'contents',	300,
'url',		310,
);
sub bykey {
  # undefined fields always go last
  return 1 unless defined $i_order{$a};
  return -1 unless defined $i_order{$b};
  $i_order{$a} <=> $i_order{$b};
}

sub implode {
  my %entry = @_;
  my ($ent);

  return &bib::goterror("BibTeX: no TYPE field") unless defined $entry{'TYPE'};
  return &bib::goterror("BibTeX: no CITEKEY field") unless defined $entry{'CITEKEY'};

  $ent = join("", '@', $entry{'TYPE'}, '{', $entry{'CITEKEY'}, ",\n");
  if (($entry{'TYPE'} eq 'mastersthesis')
      && defined($entry{'type'})
      && ($entry{'type'} eq 'Masters')) {
    delete $entry{'type'};
  }
  delete $entry{'TYPE'};
  delete $entry{'CITEKEY'};

  # I hope we're using the TeX character set, because if $entry{$field}
  # contains a { without matching }'s, we're going to have hell to pay
  # when we try to read it.  We could check for it here, but what would
  # we replace it with?  $\lbrace$ is TeX-specific.  It's also very slow.
  foreach $field (sort bykey keys %entry) {
    $ent .= "   $field = \{$entry{$field}\},\n";
  }

  # use double-dash for page ranges
  my $dash = "${bib::cs_ext}2013";
  $ent =~ s/(\d)$dash(\d)/$1$dash$dash$2/g;

  # XXXXX This should be smarter
  $ent =~ s/   month = \{(...)\},/   month = \L$1,/;

  substr($ent, -2, 1) = '';
  $ent .= "\}\n";

  # We now might have some fields that still have separators left in them,
  # notably the keywords field.  Right now we change them to space.
  # XXXXX Should this be a newline, ';', '/', ',', or space?
  $ent =~ s/$bib::cs_sep/ /go;

  $ent;
}

######

# XXXXX A type field in an inbook citation does not mean ReportType, but
#       the type of section.

%btx_to_can_fields =
   ('CITEKEY',      'CiteKey',
    'title',        'Title',
    'booktitle',    'SuperTitle',
    'affiliation',  'AuthorAddress',
    'school',       'School',
    'organization', 'Organization',
    'journal',      'Journal',
    'type',         'ReportType',
    'series',       'Series',
    'volume',       'Volume',
    'edition',      'Edition',
    'chapter',      'Chapter',
    'pages',        'Pages',
    'howpublished', 'HowPublished',
    'institution',  'Organization',
    'publisher',    'Publisher',
    'address',      'PubAddress',
    'month',        'Month',
    'year',         'Year',
    'price',        'Price',
    'copyright',    'Copyright',
    'keywords',     'Keywords',
    'mrnumber',     'MRNumber',
    'language',     'Language',
    'annote',       'Annotation',
    'isbn',         'ISBN',
    'issn',         'ISSN',
    'subject',      'Field',
    'abstract',     'Abstract',
    'note',         'Note',
    'contents',     'Contents',
    'key',          'Key',
    'url',          'Source',
    'summary',	    'Summary',
   );

sub tocanon {
  my (%rec) = @_;
  my (%can);

  # print STDERR "tocanon: conv_func = " . (defined($conv_func) ? $conv_func : "<undef>") . "\n";

  my $type = $rec{'TYPE'};
  $type =~ tr/A-Z/a-z/;
  #                  NEW CANON TYPE <-- ORIGINAL BIBTEX
  $can{'CiteType'} = 'article'       if ($type =~ /^article/);
  $can{'CiteType'} = 'book'          if ($type =~ /^book/);
  $can{'CiteType'} = 'book'          if ($type =~ /^booklet/);
  $can{'CiteType'} = 'book'          if ($type =~ /^collection/);
  $can{'CiteType'} = 'inproceedings' if ($type =~ /^conference/);
  $can{'CiteType'} = 'inbook'        if ($type =~ /^inbook/);
  $can{'CiteType'} = 'inbook'        if ($type =~ /^incollection/);
  $can{'CiteType'} = 'inproceedings' if ($type =~ /^inproceedings/);
  $can{'CiteType'} = 'manual'        if ($type =~ /^manual/);
  $can{'CiteType'} = 'thesis'        if ($type =~ /^mastersthesis/);
  $can{'CiteType'} = 'misc'          if ($type =~ /^misc/);
  $can{'CiteType'} = 'thesis'        if ($type =~ /^phdthesis/);
  $can{'CiteType'} = 'proceedings'   if ($type =~ /^proceedings/);
  $can{'CiteType'} = 'report'        if ($type =~ /^techreport/);
  $can{'CiteType'} = 'unpublished'   if ($type =~ /^unpublished/);
  $can{'CiteType'} = 'lecture'       if ($type =~ /^lecture/);

  if (!defined $can{'CiteType'}) {
    &bib::gotwarn("Improper entry type: $rec{'TYPE'}");
    $can{'CiteType'} = 'misc';
  }

  if (!defined $rec{'type'}) {
    if ( $rec{'TYPE'} =~ /^phdthesis/i ) {
      $rec{'type'} = 'Ph.D.';
    } elsif ( $rec{'TYPE'} =~ /^mastersthesis/i ) {
      $rec{'type'} = 'Masters';
    }
  }


  if (defined $rec{'author'} ) {
    # check for braces around the whole name, in which case we will
    # assume it is a corporate author.
    if ( ($rec{'author'} =~ /^\{/) && ($rec{'author'} =~ /\}$/) ) {
      $can{'CorpAuthor'} = substr($rec{'author'}, $[+1, length($rec{'author'})-2);
    } else {
      $can{'Authors'} = &bibtex_name_to_canon( $rec{'author'} );
    }
    delete $rec{'author'};
  }

  if (defined $rec{'editor'}) {
    $can{'Editors'} = &bibtex_name_to_canon( $rec{'editor'} );
    # XXXXX either we don't need this, or we need it for authors also.
    delete $can{'Editors'} unless $can{'Editors'} =~ /\S/;
    delete $rec{'editor'};
  }

  if ( defined $rec{'organization'} && defined $rec{'school'} )  {
    &bib::gotwarn("Both school and organization defined.");
    delete $rec{'school'};
  }

  if ( defined $rec{'publisher'} && defined $rec{'institution'} )  {
    &bib::gotwarn("Both publisher and institution defined.");
    delete $rec{'institution'};
  }

  if (defined $rec{'number'}) {
    if ($can{'CiteType'} =~ /report|thesis/) {
      $can{'ReportNumber'} = $rec{'number'};
    } else {
      $can{'Number'} = $rec{'number'};
    }
    delete $rec{'number'};
  }

  if (defined $rec{'month'}) {
    $can{'Month'} = &bp_util::canon_month($rec{'month'});
    delete $rec{'month'} if defined $can{'Month'};
  }

  if (defined $rec{'pages'}) {
    $can{'Pages'} = &bp_util::replace_ranges($rec{'pages'});
    # print STDERR "Set \$can{'Pages'} to $can{'Pages'}\n";
    delete $rec{'pages'} if defined $can{'Pages'};
  }

  # done with massaging the fields
  delete $rec{'TYPE'};

  while ( my ($btxf, $btxv) = each %rec) {
    next unless $btxv =~ /\S/;
    if (defined $btx_to_can_fields{$btxf}) {
      # print STDERR "Defining \$can{$btx_to_can_fields{$btxf}} = $btxv\n";
      $can{$btx_to_can_fields{$btxf}} = $btxv;
    } else {
      # Unknown, so enter literal.  Perhaps a warning?
      $can{$btxf} = $btxv;
    }
  }

  # Shouldn't this be done for just about every field?
  foreach $canf ('Title', 'SuperTitle', 'ReportType', 'Abstract', 'Note', 'Summary', 'Address', 'PubAddress') {
    next unless defined $can{$canf};
    # print STDERR "field before $canf = $can{$canf}\n";
    $can{$canf} = &bp_cs_tex::change_tex_fonts($can{$canf});
    # In BibTeX, curly braces protect single characters and TeX commands, and
    # also single capitalized words.  But permit spaces in the regexp also,
    # for people who misuse the BibTeX curly braces.
    $can{$canf} =~ s/\{([^\}]+)\}/${bib::cs_meta}3100$1${bib::cs_meta}3110/g;
    $can{$canf} =~ s/\s\s+/ /g;
    # print STDERR "field after $canf = $can{$canf}\n";
  }

  # tell them who we are
  $can{'OrigFormat'} = $version;

  # print STDERR "done with tocanon: conv_func = " . (defined($conv_func) ? $conv_func : "<undef>") . "\n";

  # print STDERR "done with tocanon; fields = ", join(' ', keys %can), "; Pages=$can{'Pages'}\n";

  %can;
}


######
#
# This routine will convert a BibTeX name into its canon form.
# It protects items in braces, such as {O'Rielly and Associates}, so that
# they are dealt with as one unit.
#

# Shouldn't this also call bp_cs_tex::change_tex_fonts?
sub bibtex_name_to_canon {
  my ($name) = @_;
  my ($n);
  my ($vonlast, $von, $last, $jr, $first, $part);
  my (@savechars);
  my $saveptr = '00';
  my $canon_name = '';

  $name =~ s/\s+/ /g;
  $name =~ s/~/\240/g;

  # Move each item enclosed in braces to an atomic character.
  while ($name =~ s/(\{[^\}]*\})/$bib::cs_temp$saveptr/) {
    push(@savechars, $1);
    $saveptr++;
  }

  foreach $n ( split(/ and /, $name) ) {

    if ( ($vonlast, $jr, $first) = $n =~ /^([^,]*),\s*([^,]*),\s*([^,]*)$/ ) {
      # sep vonlast
    } elsif ( ($vonlast, $first) = $n =~ /([^,]*),\s*([^,]*)/ ) {
      $jr = '';
      # sep vonlast
    } else {
      $first = '';
      $jr = '';
      $vonlast = '';
      foreach $part (split(/ /, $n)) {
        if ($part =~ /^[^a-z]/ && ($vonlast eq '')) {
          $first .= " $part";
        } else {
          $vonlast .= " $part";
        }
      }
    }
    $vonlast =~ s/^\s+//;
    $von = '';
    if ($vonlast ne '') {
      if ( $vonlast =~ /^[a-z]/ ) {
        $last = '';
        foreach $part (split(/ /, $vonlast)) {
          if ($part =~ /^[a-z]/ && ($last eq '')) {
            $von .= " $part";
          } else {
            $last .= " $part";
          }
        }
        $von =~ s/^\s+//;
        $last =~ s/^\s+//;
      } else {
        $last = $vonlast;
      }
    } else {
      ($first, $last) = ($first =~ /^(.*)\s+(\S+)$/);
    }
    $first =~ s/^\s+//;

    $canon_name .= $bib::cs_sep . join($bib::cs_sep2, $last, $von, $first, $jr);
  }
  $canon_name =~ s/^$bib::cs_sep//o;

  if (@savechars) {
    my ($oldchar, $oldcharmb);
    $saveptr = '00';
    while (@savechars) {
      $oldchar = shift @savechars;
      $oldcharmb = $oldchar;
      $oldcharmb =~ s/^{(.*)}$/$1/;
      $canon_name =~ s/(^|$bib::cs_sep|$bib::cs_sep2)$bib::cs_temp$saveptr($|$bib::cs_sep|$bib::cs_sep2)/$1$oldcharmb$2/  ||  $canon_name =~ s/$bib::cs_temp$saveptr/$oldchar/;
      $saveptr++;
    }
  }

  $canon_name;
}

######

# XXXXX We really ought to generate these at load time from the other list.
# XXXXX Format?

%can_to_btx_fields =
   ('CiteKey',      'CITEKEY',
    'Title',        'title',
    'SuperTitle',   'booktitle',
    'AuthorAddress','affiliation',
    'School',       'school',
    'Organization', 'organization',
    'Journal',      'journal',
    'ReportType',   'type',
    'Series',       'series',
    'Volume',       'volume',
    'Edition',      'edition',
    'Chapter',      'chapter',
    'Pages',        'pages',
    'PagesWhole',   'pages',
    'HowPublished', 'howpublished',
    'Publisher',    'publisher',
    'PubAddress',   'address',
    'Month',        'month',
    'Year',         'year',
    'Price',        'price',
    'Copyright',    'copyright',
    'Keywords',     'keywords',
    'MRNumber',     'mrnumber',
    'Language',     'language',
    'Annotation',   'annote',
    'ISBN',         'isbn',
    'ISSN',         'issn',
    'Field',        'subject',
    'Abstract',     'abstract',
    'Note',         'note',
    'Contents',     'contents',
    'Key',          'key',
    'Source',       'url',
   );

sub fromcanon {
  my %reccan = @_;
  my (%record);

  if (!defined $reccan{'CiteType'}) {
    &bib::gotwarn("BibTeX didn't find a CiteType field!");
    $reccan{'CiteType'} = 'book';
  }

  # XXXXX 22Mar96: I think we had some mixup with incollection vs. inbook.

  my $ctype = $reccan{'CiteType'};
  if    ($ctype =~ /^article/       ) { $record{'TYPE'} = 'article'; }
  elsif ($ctype =~ /^avmaterial/    ) { $record{'TYPE'} = 'misc'; }
  elsif ($ctype =~ /^book/          ) {
    if (defined $reccan{'Publisher'}) { $record{'TYPE'} = 'book'; }
    else                              { $record{'TYPE'} = 'booklet'; } }
  elsif ($ctype =~ /^inbook/        ) {
    if (defined $reccan{'SuperTitle'}) { $record{'TYPE'} = 'incollection' }
    else                               { $record{'TYPE'} = 'inbook'; } }
  elsif ($ctype =~ /^inproceedings/ ) { $record{'TYPE'} = 'inproceedings'; }
  elsif ($ctype =~ /^lecture/       ) { $record{'TYPE'} = 'lecture'; }
  elsif ($ctype =~ /^manual/        ) { $record{'TYPE'} = 'manual'; }
  elsif ($ctype =~ /^misc/          ) { $record{'TYPE'} = 'misc'; }
  elsif ($ctype =~ /^thesis/        ) {
    if ( (defined $reccan{'ReportType'}) && ($reccan{'ReportType'} =~ /master/i)
       )                    { $record{'TYPE'} = 'mastersthesis' }
    else                    { $record{'TYPE'} = 'phdthesis'; } }
  elsif ($ctype =~ /^proceedings/   ) { $record{'TYPE'} = 'proceedings'; }
  elsif ($ctype =~ /^report/        ) { $record{'TYPE'} = 'techreport'; }
  elsif ($ctype =~ /^unpublished/   ) { $record{'TYPE'} = 'unpublished'; }
  else {
    &bib::gotwarn("Improper entry type: $reccan{'CiteType'}");
    $record{'TYPE'} = 'misc';
  }

  # generate key if necessary, using the default method.
  $reccan{'CiteKey'} = &bp_util::genkey(%reccan) unless defined $reccan{'CiteKey'};

  # register our citekey
  $reccan{'CiteKey'} = &bp_util::regkey($reccan{'CiteKey'});

  if ( defined $reccan{'Authors'} ) {
    $record{'author'} = &bp_util::canon_to_name($reccan{'Authors'}, 'bibtex');
    delete $reccan{'Authors'};
    if ($record{'author'} !~ / /) {
      if ($record{'author'} =~ s/\240/ /g) {
        $record{'author'} = $protectB . $record{'author'} . $protectE;
      }
    }
  }
  if ( defined $reccan{'CorpAuthor'} ) {
    # no need for no-break spaces, as we're putting braces around it.
    $reccan{'CorpAuthor'} =~ s/\240/ /g;
    if (defined $record{'author'}) {
      if (defined $reccan{'Organization'}) {
        $record{'author'} .= ' and ' . $protectB . $reccan{'CorpAuthor'} . $protectE;
      } else {
        $record{'organization'} = $reccan{'CorpAuthor'};
      }
    } else {
      $record{'author'} = $protectB . $reccan{'CorpAuthor'} . $protectE;
    }
    delete $reccan{'CorpAuthor'};
  }

  if ( defined $reccan{'Editors'} ) {
    $record{'editor'} = &bp_util::canon_to_name($reccan{'Editors'}, 'bibtex');
    delete $reccan{'Editors'};
  }

  if ( $reccan{'CiteType'} =~ /^(report|unpublished)/ ) {
    if ( defined $reccan{'Publisher'} ) {
      $record{'institution'} = $reccan{'Publisher'};
      delete $reccan{'Publisher'};
    } elsif ( defined $reccan{'Organization'} ) {
      $record{'institution'} = $reccan{'Organization'};
      delete $reccan{'Organization'};
    }
  }

#  if ( $reccan{'CiteType'} =~ /^thesis/ ) {
#    if ( defined $reccan{'Organization'} ) {
#      $record{'school'} = $reccan{'Organization'};
#      delete $reccan{'Organization'};
#    }
#  }

  if (defined $reccan{'ReportNumber'}) {
    if (defined $reccan{'Number'}) {
      &bib::gotwarn("Both Number and ReportNumber.");
      delete $reccan{'Number'};
    }
    if ($reccan{'CiteType'} !~ /report|thesis/) {
      &bib::gotwarn("ReportNumber defined, but not in a report.");
    }
    $record{'number'} = $reccan{'ReportNumber'};
    delete $reccan{'ReportNumber'};
  } elsif (defined $reccan{'Number'}) {
    if ($reccan{'CiteType'} =~ /report|thesis/) {
      &bib::gotwarn("Number defined inside a report.");
    }
    $record{'number'} = $reccan{'Number'};
    delete $reccan{'Number'};
  }

  if (defined $reccan{'ReportType'}) {
    if ($reccan{'ReportType'} !~ /($protectB|$protectE)/o) {
      $reccan{'ReportType'} =~ s/Ph\.\s*D\./${protectB}Ph.D.${protectE}/o;
    }
  }

  # done with massaging the fields
  delete $reccan{'CiteType'};
  # We don't know any special information about any types
  delete $reccan{'OrigFormat'};

  while (my ($canf, $canv) = each %reccan) {
    if (defined $can_to_btx_fields{$canf}) {
      $record{$can_to_btx_fields{$canf}} = $canv;
    } else {
      if ($opt_omit_unknown) {
        # Nothing to do; just ignore unknown fields.
      } else {
        &bib::gotwarn("Unknown field: $canf");
        $record{$canf} = $canv;
      }
    }
  }

  %record;
}

######

sub clear {
  my ($file) = @_;
  # variable $file is ignored

  # XXXXX currently we have just one strings mapping for all files.

## Don't reset it between files.
#  %glb_replace = ();
#  $glb_eval_repl = 0;
}

######

sub crossref_fill {
  my (%bent) = @_;
  my $id = $bent{'crossref'};
  my (%crossent);
  my ($cfield, $cval);

  &bib::debugs("trying to crossref $id in $bent{'CITEKEY'}", 64);
  if (!defined $glb_crossref_entries{$id}) {
    if ( ! &get_record_ahead($id) ) {
      &bib::gotwarn("Could not find bibtex crossref: $id");
      return %bent;
    }
  }
#print STDERR "using crossref $id.  readahead has $#glb_readahead entries\n";

  %crossent = &explode( $glb_crossref_entries{$id} );

  # Merge the two records
  # We do this by simply adding any fields from the crossref entry that
  # don't exist in the original record.
  while ( ($cfield, $cval) = each %crossent) {
    next if defined $bent{$cfield};
    $bent{$cfield} = $cval;
  }
  # Now that we've successfully merged the entries, we can remove the
  # crossref entry
  # But keep around a reminder of what it was before.
  $bent{'inlined-crossref'} = $bent{'crossref'};
  delete $bent{'crossref'};

  %bent;
}

sub get_record_ahead {
  my ($needed_id) = @_;
  my $id = undef;
  my ($next_record);

#print STDERR "new crossref: $needed_id\n" unless defined $glb_crossref_needed{$needed_id};
  $glb_crossref_needed{$needed_id} = 1;

  # We can't have the read routine returning our own results to us!
  $glb_noreadahead = 1;

  while ($next_record = &read) {
    # We look in each record to see if there is another crossref field.
    # If there seems to be, we make a note of it, so we will store the
    # record right away.
    if ($next_record =~ /crossref\s*=\s*[{"]([^}"]+)/i) {
      if (!defined $glb_crossref_entries{$1}) {
        $glb_crossref_needed{$1} = 1;
      }
    }

    ($id) = ( $next_record =~ /^\s*\@\s*\w+\s*[{(]\s*([^,\s]+)/ );

    if (defined $glb_crossref_needed{$id}) {
      $glb_crossref_entries{$id} = $next_record;
      delete $glb_crossref_needed{$id};
    }

    push(@glb_readahead, $next_record);
    last if $id eq $needed_id;
  }

  &bib::debugs("crossref looking for " . join(" ", keys %glb_crossref_needed) . ".", 4);
  &bib::debugs("crossref has " . join(" ", keys %glb_crossref_entries) . ".", 4);

  # Now let the read routine use the readahead information
  $glb_noreadahead = 0;

  ($id eq $needed_id);
}

# extra_message may be:
#  * undef:  no warning message ever printed
#  * a string:  appended to warning message
#  * "":  uncustomized warning message printed
#  * missing: same as ""
sub macro_expansion {
  my ($macro, $extra_message);
  if (scalar(@_) == 1) {
    ($macro) = @_;
    $extra_message = "";
  } elsif (scalar(@_) == 2) {
    ($macro, $extra_message) = @_;
  } else {
    die "Bad args to macro_expansion";
  }

  if ($macro =~ /^\d+$/) {
    # A number, not a macro
    return undef;
  }
  $macro_lower = $macro;
  $macro_lower =~ tr/A-Z/a-z/;
  if (defined $glb_replace{$macro_lower}) {
    return $glb_replace{$macro_lower};
  } else {
    if (defined($extra_message)) {
      &bib::gotwarn("Unknown macro: $macro$extra_message");
    }
    return undef;
  }
}


#######################
# end of package
#######################

1;
