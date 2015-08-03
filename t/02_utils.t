#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use RPM::Packager::Utils;

subtest 'copy_to_tempdir', sub {
    my $tempdir = File::Temp->newdir();
    my %mapping = ( 't/test_data' => '/usr/local/bin' );
    my $ret     = RPM::Packager::Utils::copy_to_tempdir( $tempdir, %mapping );
    is( $ret, 1, 'copy_to_tempdir succeeded' );
};

subtest 'is_command', sub {
    is( RPM::Packager::Utils::is_command('grep Changelog'), 1, 'command detected' );
    is( RPM::Packager::Utils::is_command('1.0.0'),          0, 'non-command detected' );
};

subtest 'eval_command', sub {
    is( RPM::Packager::Utils::eval_command('echo foobar'), 'foobar', 'eval command worked' );
};

done_testing();
