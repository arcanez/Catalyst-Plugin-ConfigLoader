package Catalyst::Plugin::ConfigLoader;
use strict;
use warnings;
use Catalyst::Plugin::ConfigLoader::Container;

sub setup {
    my $app = shift; 

    my $plugin = $app->config->{'Plugin::ConfigLoader'}; $plugin->{name} = $app;

    my $config = Catalyst::Plugin::ConfigLoader::Container->new( $plugin )->fetch('config')->get; 
    $app->config($config);
    $app->finalize_config; # back-compat
    $app->next::method(@_);
}

sub finalize_config {} # back-compat

sub get_config_local_suffix {}
sub get_config_path {}

1;
