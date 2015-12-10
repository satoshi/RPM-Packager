package RPM::Packager::Utils;

use strict;
use warnings;
use File::Find;

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

1;
