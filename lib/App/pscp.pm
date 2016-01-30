package App::pscp;
use strict;
use warnings;
use Getopt::Long ();
use Net::OpenSSH;
use Parallel::ForkManager;
use String::Glob::Permute ();
use File::Basename ();
use File::Spec;

our $VERSION = '0.01';

my $HELP = <<___;

 Usage: pscp [options] source destination

 Options:
  -c, --concurrency=NUM  ssh concurrency, default: 5
  -v, --verbose          turn on verbose message
  -h, --help             show this help
      --version          show version

 Examples:
  > pscp file.txt 'www[01-05].example.com:/path/to/file.txt'
  > pscp 'example.{com,jp}:file.txt' file.txt

___

sub help { print STDERR $HELP and exit }

sub new {
    my $class = shift;
    bless { concurrency => 5, @_ }, $class;
}

sub parse_options {
    my ($self, @argv) = @_;
    my $parser = Getopt::Long::Parser->new;
    $parser->configure(qw(no_auto_abbrev no_ignore_case bundling));
    $parser->getoptionsfromarray(\@argv,
        "c|concurrency=i" => \$self->{concurrency},
        "g|glob" => \$self->{glob},
        "h|help" => sub { $self->help },
        "version" => sub { printf "%s %s\n", ref $self, $self->VERSION and exit },
        "v|verbose" => \$self->{verbose},
    ) or return;
    $self->{argv} = \@argv;
    return 1;
}

sub run {
    my $self = shift;
    $self = $self->new unless ref $self;
    $self->parse_options(@_) or exit 1;
    my ($src, $dest) = @{$self->{argv}};
    die "Invalid argument, try `pscp --help`\n" unless $dest;
    my ($host_str, $method);
    if ($src =~ s/^([^:]+)://) {
        $host_str = $1;
        $method = "scp_get";
    } elsif ($dest =~ s/^([^:]+)://) {
        $host_str = $1;
        $method = "scp_put";
    }
    my $ok = $self->pscp(
        hosts => [ String::Glob::Permute::string_glob_permute($host_str) ],
        method => $method,
        source => $src,
        destination => $dest,
    );
    my $exit = $ok ? 0 : 1;
    return $exit;
}

sub pscp {
    my ($self, %option) = @_;
    my $hosts  = $option{hosts};
    my $method = $option{method};
    my $src    = $option{source};
    my $dest   = $option{destination};
    my $pm = Parallel::ForkManager->new($self->{concurrency});
    my %result; $pm->run_on_finish(sub {
        my ($pid, $exit, $host, $signal) = @_;
        $result{$host} = $exit == 0 && !$signal ? 1 : 0;
    });
    for my $host (@$hosts) {
        $pm->start($host) and next;
        my ($ssh, $err) = $self->_ssh($host);
        if ($err) {
            warn "[$host] $err\n";
            $pm->finish(1);
        }
        if ($method eq "scp_get") {
            if (-d $dest) {
                my $base = File::Basename::basename($src);
                $dest = File::Spec->catfile($dest, "$base.$host");
            } else {
                $dest = "$dest.$host";
            }
        }
        warn "[$host] $method $src $dest\n" if $self->{verbose};
        my $option = { quiet => $self->{verbose} ? 0 : 1, glob => $self->{glob} };
        my $ok = $ssh->$method($option, $src, $dest);
        $pm->finish( $ok ? 0 : 1 );
    }
    $pm->wait_all_children;
    if (my @fail = grep { !$result{$_} } sort keys %result) {
        warn "Failed in:\n";
        warn "  \e[31m$_\e[m\n" for @fail;
        return;
    }
    return 1;
}

sub _ssh {
    my ($self, $host) = @_;
    my $ssh = Net::OpenSSH->new($host,
        strict_mode => 0,
        timeout => 5,
        kill_ssh_on_timeout => 1,
        master_opts => [
            -o => "StrictHostKeyChecking=no",
            -o => "UserKnownHostsFile=/dev/null",
            -o => "LogLevel=ERROR",
        ],
    );
    my $err = $ssh->error || "";
    chomp $err;
    ($ssh, $err);
}

no warnings;
__PACKAGE__;
__END__

=encoding utf-8

=head1 NAME

App::pscp - parallel scp

=head1 SYNOPSIS

  > pscp file.txt 'example[01-10].com:file.txt'

=head1 DESCRIPTION

App::pscp is

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
