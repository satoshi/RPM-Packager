#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RPM::Packager::Utils;

subtest 'is_command', sub {
    is( RPM::Packager::Utils::is_command('grep Changelog'), 1, 'command detected' );
    is( RPM::Packager::Utils::is_command('1.0.0'),          0, 'non-command detected' );
};

subtest 'eval_command', sub {
    is( RPM::Packager::Utils::eval_command('echo foobar'), 'foobar', 'eval command worked' );
};

subtest 'find_files', sub {
    my @files = RPM::Packager::Utils::find_files("$Bin/test_data");
    is( grep( /test_yaml/, @files ), 1, "found expected file" );
};

subtest 'find_relative_paths', sub {
    my @files = RPM::Packager::Utils::find_files("$Bin/test_data");
    my @rel_paths = RPM::Packager::Utils::find_relative_paths( $Bin, @files );
    isa_ok( \@rel_paths, 'ARRAY', 'got arrayref' );
};

done_testing();
