package RPM::Packager;

use strict;
use warnings;
use Data::Dumper;
use File::Temp;
use File::Copy qw(copy);
use File::Path qw(make_path);
use Cwd;
use Expect;
use RPM::Packager::Utils;

=head1 NAME

RPM::Packager - Manifest-based approach for building RPMs

=head1 VERSION

Version 0.3.0

=cut

our $VERSION = 'v0.3.0';

=head1 SYNOPSIS

Building RPMs should be easy.

This is a manifest approach to easily create custom RPMs.  Once this module is installed, building RPMs should be as
simple as writing a YAML file that looks like the following:

    ---
    name: testpackage
    version: grep Changelog             # version string or some command to retrieve it
    os: el6                             # optional, don't specify anything if package is os-independent
    dependencies:
      - perl-YAML > 0.5
      - perl-JSON
    files:
      bin: /usr/local/bin               # directory-based mapping.  RPM will install CWD/bin/* to /usr/local/bin.
    user: apache                        # specify the owner of files.  default: root
    group: apache                       # specify the group owner of files.  default: root
    sign:                               # optionally, gpg signing of RPM
      gpg_name: ED16CAB                 # provide the GPG key ID
      passphrase_cmd: cat secret_file   # command to retrieve the secret
    after_install: /path/to/script      # script to run after the package is installed (%post)

Then run:

    rpm_packager.pl <path_to_manifest.yml>

Note : You need to have fpm available in PATH.  For GPG signing, you need to have proper keys imported.

Note2: The 'release' field of RPM will be determined by the BUILD_NUMBER env variable plus 'os' field, like '150.el7'.
If BUILD_NUMBER is unavailable, 1 will be used.  If os is unspecified, nothing will be appended.

You may also interact with the library directly as long as you pass in the manifest information in a hash:

    use RPM::Packager;

    my %args = (
        name    => 'testpackage',
        version => 'grep Changelog',
        files   => { bin => '/usr/local/bin' },
        dependencies => [
            'perl-YAML > 0.5',
            'perl-JSON'
        ],
        os      => 'el6',
        user    => 'apache',
        group   => 'apache',
        sign    => {
            'gpg_name' => 'ED16CAB',
            'passphrase_cmd' => 'cat secret_file'
        },
        after_install => 'foo/bar/baz.sh'
    );

    my $obj = RPM::Packager->new(%args);
    $obj->create_rpm();                           # RPM produced in CWD

=head1 SUBROUTINES/METHODS

=head2 new(%args)

Constructor.  Pass in a hash containing manifest info.

=cut

sub new {
    my ( $class, %args ) = @_;
    chomp( my $fpm = `which fpm 2>/dev/null` );

    my $self = {
        fpm     => $fpm,
        cwd     => getcwd(),
        tempdir => File::Temp->newdir(),
        %args
    };
    return bless $self, $class;
}

sub find_version {
    my $self  = shift;
    my $value = $self->{version};
    ( RPM::Packager::Utils::is_command($value) ) ? RPM::Packager::Utils::eval_command($value) : $value;
}

sub generate_dependency_opts {
    my $self = shift;
    my $dependencies = $self->{dependencies} || [];
    my @chunks;
    for my $dependency ( @{$dependencies} ) {
        push @chunks, "-d '$dependency'";
    }
    return join( " ", @chunks );
}

sub generate_user_group {
    my $self  = shift;
    my $user  = $self->{user} || 'root';
    my $group = $self->{group} || 'root';
    return ( $user, $group );
}

sub copy_to_tempdir {
    my $self = shift;

    my $cwd     = $self->{cwd};
    my %hash    = %{ $self->{files} };
    my $tempdir = $self->{tempdir};

    for my $key ( keys %hash ) {
        my $src        = "$cwd/$key";
        my $dst        = $hash{$key};
        my $target_dir = "$tempdir$dst";
        make_path($target_dir);
        my @files = RPM::Packager::Utils::find_files($src);
        my @relative_paths = RPM::Packager::Utils::find_relative_paths( $src, @files );

        for my $entry (@relative_paths) {
            my $dir  = "$target_dir/$entry->{dirname}";
            my $file = "$src/$entry->{rel_path}";
            make_path($dir) if ( !-d $dir );
            copy $file, $dir;
        }
    }
    return 1;
}

sub add_gpg_opts {
    my $self = shift;

    return unless ( $self->should_gpgsign() );

    my $gpg_name       = $self->{sign}->{gpg_name};
    my $passphrase_cmd = $self->{sign}->{passphrase_cmd};
    my $opts           = $self->{opts} || [];
    push @{$opts}, '--rpm-sign', '--rpm-rpmbuild-define', "'_gpg_name $gpg_name'";
    $self->{opts}           = $opts;
    $self->{gpg_passphrase} = RPM::Packager::Utils::eval_command($passphrase_cmd);
}

sub add_after_install {
    my $self = shift;
    return unless ( $self->{after_install} );

    my $opts = $self->{opts} || [];
    push @{$opts}, '--after-install', $self->{after_install};
    $self->{opts} = $opts;
}

sub populate_opts {
    my $self            = shift;
    my $version         = $self->find_version();
    my $release         = $ENV{BUILD_NUMBER} || 1;
    my $os              = $self->{os};
    my $iteration       = ($os) ? "$release.$os" : $release;
    my $dependency_opts = $self->generate_dependency_opts();
    my ( $user, $group ) = $self->generate_user_group();

    my @opts = (
        $self->{fpm}, '-v',          $version,   '--rpm-user', $user,         '--rpm-group',
        $group,       '--iteration', $iteration, '-n',         $self->{name}, $dependency_opts,
        '-s',         'dir',         '-t',       'rpm',        '-C',          $self->{tempdir}
    );

    $self->{opts} = [@opts];
    $self->add_gpg_opts();
    $self->add_after_install();
    push @{ $self->{opts} }, '.';    # relative to the temporary directory
}

sub handle_interactive_prompt {
    my $self = shift;
    my $opts = $self->{opts};
    my $cmd  = join( ' ', @{$opts} );
    my $pass = $self->{gpg_passphrase};

    my $exp = Expect->new();
    $exp->spawn($cmd);
    $exp->expect(
        undef,
        [
            qr/Enter pass phrase:/i => sub {
                my $exp = shift;
                $exp->send("$pass\n");
                exp_continue;
              }
        ]
    );
    return 1;
}

sub should_gpgsign {
    my $self           = shift;
    my $gpg_name       = $self->{sign}->{gpg_name};
    my $passphrase_cmd = $self->{sign}->{passphrase_cmd};
    ( $gpg_name && $passphrase_cmd ) ? 1 : 0;
}

=head2 create_rpm

Creates RPM based on the information in the object

=cut

sub create_rpm {
    my $self = shift;

    $self->copy_to_tempdir();
    $self->populate_opts();

    if ( $self->should_gpgsign() ) {
        $self->handle_interactive_prompt();
    }
    else {
        my $cmd = join( ' ', @{ $self->{opts} } );
        system($cmd);
    }
    return 1;
}

=head1 AUTHOR

Satoshi Yagi, C<< <satoshi.yagi at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rpm-packager at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RPM-Packager>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RPM::Packager


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RPM-Packager>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RPM-Packager>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RPM-Packager>

=item * Search CPAN

L<http://search.cpan.org/dist/RPM-Packager/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Satoshi Yagi.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;    # End of RPM::Packager
