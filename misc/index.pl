#!/usr/bin/perl

unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
require "bp.pl";
@ARGV = &bib::stdargs(@ARGV);
&bib::errors('ignore');

while (@ARGV) {
  $_ = shift @ARGV;
  last if /^--$/;
# /^-f/ && do { $field = shift @ARGV;   next; };
  /^-i/ && do { $indexfile = shift @ARGV; next; };
  /^-help$/ && do { &dieusage; };
  push (@filelist, $_);
}

unshift(@filelist, '-')  unless @filelist;

%ignore = (
'of',	1,
'and',	1,
'the',	1,
'in',	1,
'a',	1,
'on',	1,
'to',	1,
'for',	1,
'from',	1,
'an',	1,
'with',	1,
'by',	1,
'at',	1,
'as',	1,
'its',	1,
);

die "Must have index file specified with -i" unless defined $indexfile;
$index_is_open = 0;
$| = 1;
$screensize = 75;
$filenum = 0;

&usefield( 'Authors'    , 'A', $bib::cs_sep);
&usefield( 'Editors'    , 'A', $bib::cs_sep);
&usefield( 'Title'      , 'T', " ");
&usefield( 'SuperTitle' , 'T', " ");
&usefield( 'Keywords'   , 'K', $bib::cs_sep . "\|\\s+");

foreach $file (@filelist) {
  # this little gem is from Larry Wall -- expand ~user.
  $file =~ s#^(~([a-z0-9]+))(/.*)?$#((getpwnam($2))[7]||$1).$3#e;
  # this is mine -- handle ~/file
  $file =~ s#^(~)(/.*)?$#((getpwnam(getlogin))[7]||$1).$2#e;
  next unless $fmt = &bib::open($file);
  $filenum++;
  &openindex unless $index_is_open;
  $str = "$file <$fmt> ";
  print $str;
  $modv = 1000 / ($screensize - length($str));
  $modv = 50 if $modv < 1;
  $num = 0;
  $fpos = tell;
  while ($record = &bib::read) {
    $num++;
    ($num % $modv) || print ".";
    %ent = &bib::tocanon( &bib::explode($record) );
    #   # First add the whole record
    #$index{$num} = $record;
       # Next fields to the index
    &addfield( 'Authors'    );
    &addfield( 'Editors'    );
    &addfield( 'Title'      );
    &addfield( 'SuperTitle' );
    &addfield( 'Keywords'   );
    $fpos = tell;
  }
  &closeinfo;
  &bib::close;
  ($warns, $errors) = &bib::errors('clear');
  if ($warns == 0) {
    print "ok\n";
  } else {
    print "$warns warns\n";
  }
}
&closeindex if $index_is_open;

sub closeinfo {
  $index{'I' . $filenum . 'name'}    = $file;
  $index{'I' . $filenum . 'format'}  = $fmt;
  $index{'I' . $filenum . 'records'} = $num;
  $index{'I' . 'fields'} = join("", values %field);
  while ( ($name, $val) = each %field ) {
    $index{'FLD #' . $val} = $name;
    $index{'FLD name' . $name} = $val;
  }
}


$fieldcount = 0;
sub usefield {
  local($name, $type, $splitchar) = @_;

  $name =~ tr/A-Z/a-z/;
  $field{$name} = pack("C", $fieldcount);
  $seper{$name} = $splitchar;
  $ftype{$name} = $type;
  $fieldcount++;
  # We have some reserved fields
  if ( ($fieldcount >= ord('A')) && ($fieldcount <= ord('Z')) ) {
    $fieldcount = ord('Z') + 1;
  }
  if ($fieldcount > 255) {
    die "Too many fields being indexed!\n";
  }
}

#  Assumes the following globals are set:
#
#    %ent	the record
#    $filenum	the file number
#    $fpos	the file position
#
sub addfield {
  local($name) = @_;
  local($nm) = $name;
  $nm =~ tr/A-Z/a-z/;
  local($prefix)    = $field{$nm};
  local($type)      = $ftype{$nm};
  local($splitchar) = $seper{$nm};

  return unless defined $ent{$name};
  $ent{$name} =~ s/^\s+//;
  $ent{$name} =~ tr/A-Z/a-z/;
  foreach $field ( split(/$splitchar/, $ent{$name}) ) {
    if ($type eq 'A') {
      # We only want the last name
      substr($field, index($field, $bib::cs_sep2)) = '';
    }
    $field =~ tr/A-Za-z0-9\- //cd;
    next if ($type eq 'T' && defined $ignore{$field});
    local($pointer) = pack("nN", $filenum, $fpos);
#print "adding $filenum:$fpos to ", unpack("C", $prefix), ".$field.\n";
    if (defined $index{$prefix . $field}) {
      $index{$prefix . $field} .= "$pointer";
    } else {
      $index{$prefix . $field} = "$pointer";
    }
  }
}

sub dieusage {
  local($prog) = substr($0,rindex($0,'/')+1);

  $str =<<"EOU";
Usage: $prog [-i index_file_name] files...
EOU

  die $str;
}


sub openindex {
  if (-e "$indexfile") {
    die "Will not overwrite existing DBM file $indexfile.";
  }

  %index = ();
  #dbmopen(%index, "$indexfile", 0644);
  $index_is_open = 1;
}

sub closeindex {
  print "Writing index.\n";
  dbmopen(%ind, "$indexfile", 0644);
  while ( ($key, $val) = each %index) {
    $ind{$key} = $val;
  }
  dbmclose(%ind);
}
