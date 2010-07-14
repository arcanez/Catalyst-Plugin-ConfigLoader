package Catalyst::Plugin::ConfigLoader;
use strict;
use warnings;
use Catalyst::Plugin::ConfigLoader::Container;

sub setup {
    my $app = shift;
    my $config = Catalyst::Plugin::ConfigLoader::Container->new( name => $app )->fetch('config')->get; 
    $app->config($config);
    $app->finalize_config; # back-compat
    $app->next::method(@_);
}

sub finalize_config {} # back-compat

1;
