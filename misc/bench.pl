#!/usr/bin/perl

use Benchmark;

$count = 10000;

$string1 = 'This is a test.';
$string2 = '     This is a test.';
$string3 = '   ';
$string4 = '';

#timethese($count, {
#   'anchor1' => '$string1 =~ /^\s*$/',
#   'nospcs1' => '$string1 =~ /\S/',
#   'nospma1' => '$string1 =~ /[\S]/',
#   'anchor2' => '$string2 =~ /^\s*$/',
#   'nospcs2' => '$string2 =~ /\S/',
#   'nospma2' => '$string2 =~ /[\S]/',
#   'anchor3' => '$string3 =~ /^\s*$/',
#   'nospcs3' => '$string3 =~ /\S/',
#   'nospma3' => '$string3 =~ /[\S]/',
#   'anchor4' => '$string4 =~ /^\s*$/',
#   'nospcs4' => '$string4 =~ /\S/',
#   'nospma4' => '$string4 =~ /[\S]/',
#});

%recexp = (
'Authors', "Abel$;,$;,P. G.$;,$;/Gruber$;,$;,A.$;,",
'CiteType', 'report',
'OrigFormat', 'refer (dj 12 jan 95)',
'Pages', '24',
'PubAddress', 'Washington, DC',
'Publisher', 'National Oceanic and Atmospheric Administration',
'ReportNumber', '106',
'ReportType', 'Technical Report NESS',
'Title', 'An improved model for the calculation of longwave flux at 11 micrometers',
'Year', '1979',
);

$teststr = "[\\\\]";

timethese($count, {
  'join ' => '$testexp = join("", values %recexp); $set = 1 if $testexp =~ /$teststr/',
  'join2' => '$set = 1 if join("", values %recexp) =~ /$teststr/',
#  'jtest' => '$testexp =~ /$teststr/',
  'grep ' => '$set = grep(/$teststr/,  values %recexp)',
  'while' => 'while (($field, $val) = each %recexp) { next unless $val =~ /$teststr/; $set = 1;}'
});
