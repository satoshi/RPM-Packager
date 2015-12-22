package RPM::Packager::Utils;

use strict;
use warnings;
use File::Find;
use File::Spec;
use File::Basename;

sub is_command {
    my $val = shift;
    ( $val !~ /^\d/ ) ? 1 : 0;
}

sub eval_command {
    my $cmd = shift;
    chomp( my $val = `$cmd` );
    return $val;
}

sub find_files {
    my $dir = shift;

    my @files;
    my $coderef = sub { push @files, $File::Find::name; };
    find( { wanted => $coderef, follow => 1, follow_skip => 2 }, $dir );
    return @files;
}

sub find_relative_paths {
    my ( $base, @files ) = @_;

    my @result;
    for my $file (@files) {
        my $rel_path = File::Spec->abs2rel( $file, $base );
        push @result, { rel_path => $rel_path, dirname => dirname($rel_path) };
    }
    return @result;
}

1;
