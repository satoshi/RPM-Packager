#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RPM::Packager;

subtest 'constructor', sub {
    my $obj = RPM::Packager->new();
    isa_ok( $obj, 'RPM::Packager', 'object created' );
};

subtest 'find_version', sub {
    my $obj = RPM::Packager->new( version => '1.2.3' );
    is( $obj->find_version(), '1.2.3', 'got version literal' );

    $obj = RPM::Packager->new( version => 'echo "3.2.1"' );
    is( $obj->find_version(), '3.2.1', 'got version evaluated' );
};

subtest 'generate_dependency_opts', sub {
    my $obj = RPM::Packager->new( dependencies => [ 'some_package', 'foobar > 1.0' ] );
    is( $obj->generate_dependency_opts(), "-d 'some_package' -d 'foobar > 1.0'", 'dependency string created' );

    $obj = RPM::Packager->new();
    is( $obj->generate_dependency_opts(), '', 'no dependencies specified' );
};

subtest 'generate_user_group', sub {
    my $obj = RPM::Packager->new();
    my ( $user, $group ) = $obj->generate_user_group();
    is( $user,  'root', 'default is root' );
    is( $group, 'root', 'default is root' );

    $obj = RPM::Packager->new( user => 'pps', group => 'bar' );
    ( $user, $group ) = $obj->generate_user_group();
    is( $user,  'pps', 'pps user' );
    is( $group, 'bar', 'bar group' );
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
