#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'RPM::Packager' ) || print "Bail out!\n";
}

diag( "Testing RPM::Packager $RPM::Packager::VERSION, Perl $], $^X" );
