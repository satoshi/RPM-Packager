package RPM::Packager::Utils;

use strict;
use warnings;
use Cwd;

sub copy_to_tempdir {
    my ( $tempdir, %hash ) = @_;

    my $cwd = getcwd();
    for my $key ( keys %hash ) {
        my $dst        = $hash{$key};
        my $target_dir = "$tempdir$dst";
        system("mkdir -p $target_dir");
        system("cp -r $cwd/$key/* $target_dir");
    }
    return 1;
}

sub is_command {
    my $val = shift;
    ( $val !~ /^\d/ ) ? 1 : 0;
}

1;
