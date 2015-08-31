#!/usr/bin/perl

use strict;
use warnings;
use YAML;
use RPM::Packager;

my $config = YAML::LoadFile( $ARGV[0] );
my $packager = RPM::Packager->new( %{ $config } );
$packager->create_rpm();