#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Parse::ARGV' ) || print "Bail out!\n";
}

diag( "Testing Parse::ARGV $Parse::ARGV::VERSION, Perl $], $^X" );
