requires 'perl', '5.008005';
requires 'Getopt::Long', '2.38';
requires 'Net::OpenSSH';
requires 'Parallel::ForkManager', '1.17';
requires 'String::Glob::Permute';

on test => sub {
    requires 'Test::More', '0.98';
};
