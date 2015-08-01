#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RPM::Packager;

subtest 'constructor', sub {
    my $obj = RPM::Packager->new();
    isa_ok( $obj, 'RPM::Packager', 'object created' );
};

#subtest 'create_rpm', sub {
#    my %args = (
#        name    => 'testpackage',
#        version => 'grep Changelog',
#        files   => { bin => '/usr/local/bin' },
#        os      => 'el6',
#    );
#    my $obj = RPM::Packager->new(%args);
#    my $ret = $obj->create_rpm();
#    is( $ret, 1, 'RPM created successfully' );
#};

done_testing();
