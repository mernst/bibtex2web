#!/usr/bin/perl

$dobibread = 0;
while (@ARGV) {
  $_ = shift @ARGV;
  last if /^--$/;
  /^-r/ && do { $dobibread = 1;   next; };
  /^-i/ && do { $indexfile = shift @ARGV; next; };
  /^-help$/ && do { &dieusage; };
  push (@arglist, $_);
}

&dieusage unless @arglist;
die "Must have index file specified with -i.\n" unless defined $indexfile;
$index_is_open = 0;
&openindex;

if ($dobibread) {
  unshift(@INC, $ENV{'BPHOME'})  if defined $ENV{'BPHOME'};
  require "bp.pl";
}

foreach $arg (@arglist) {
  ($field, $val) = split(/:/, $arg);
  $field =~ tr/A-Z/a-z/;
  $val =~ tr/A-Z/a-z/;
  if (!defined $index{'FLD name' . $field}) {
    print "Field $field is not indexed in $indexfile.\n";
    next;
  }
  $fldn = $index{'FLD name' . $field};
  $val =~ tr/A-Z/a-z/;
  if (defined $index{$fldn . $val}) {
    #@reclist = &retrieve($index{$fldn . $val});
    #$recs = join("", @reclist);
    print "$arg: ", length($index{$fldn . $val}) / 6, " records\n";
    &retrieve_print($index{$fldn . $val});
  } else {
    print "'$val' in field '$field' not found.\n";
  }
}
dbmclose(%index) if $index_is_open;


sub retrieve {
  local($pointers) = @_;
  # for reading a paragraph record
  local($/) = '';
  local($fh, $r, @recs);

  while (length($pointers) > 0) {
    ($fnum, $fpos) = unpack("nN", $pointers);
    substr($pointers, 0, 6) = '';
    &openfilenum($fnum) unless defined $fname{$num};
    $fh = $fh{$num};
    seek($fh, $fpos, 0);
    # read a record (really a paragraph)
    push(@recs, scalar(<$fh>) );
  };
  @recs;
}

sub retrieve_print {
  local($pointers) = @_;
  local($fh, $r, @recs);
  if (!$dobibread) {
    # for reading a paragraph record
    local($/) = '';
  }

  while (length($pointers) > 0) {
    ($fnum, $fpos) = unpack("nN", $pointers);
    substr($pointers, 0, 6) = '';
    &openfilenum($fnum) unless defined $fname{$num};
    if ($dobibread) {
      seek("bib'GFMI" . $fname{$num}, $fpos, 0);
      print &bib::read($fname{$num}), "\n";
    } else {
      $fh = $fh{$num};
      seek($fh, $fpos, 0);
      print scalar(<$fh>);
    }
  }
};

sub dieusage {
  local($prog) = substr($0,rindex($0,'/')+1);

  $str =<<"EOU";
Usage: $prog [-i index_file_name] files...
EOU

  die $str;
}

sub openindex {
  if (!-e "$indexfile") {
    die "Cannot find DBM file $indexfile.\n";
  }

  dbmopen(%index, "$indexfile", 0644) || die "Cannot open index.\n";
  $index_is_open = 1;
}

sub openfilenum {
  ($num) = @_;

  return if defined $fname{$num};

  die "File $num not found in index!\n" unless defined $index{'I' . $num . 'name'};

  $fname{$num} = $index{'I' . $num . 'name'};
  $fform{$num} = $index{'I' . $num . 'format'};
  $fh{$num}    = "fh" . $num;

  if ($dobibread) {
    &bib::format($fform{$num});
    &bib::open($fname{$num});
  } else {
    open( $fh{$num}, $fname{$num} ) || die "Could not open file: $fname{$num}.\n";
  }
}
