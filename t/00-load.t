#!perl
use v5.14;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Lingua::Thesaurus' ) || print "Bail out!\n";
}

diag( "Testing Lingua::Thesaurus $Lingua::Thesaurus::VERSION, Perl $], $^X" );
