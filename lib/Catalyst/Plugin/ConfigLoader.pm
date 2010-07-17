package Catalyst::Plugin::ConfigLoader;
use strict;
use warnings;

sub setup {
    my $app = shift; 

    my %args = %{$app->config->{'Plugin::ConfigLoader'} || {} };
    my $container_class = $args{container_class} || 'Catalyst::Plugin::ConfigLoader::Container';;
    Class::MOP::load_class( $container_class );

    my $config = $container_class->new( %args, name => $app )->fetch('config')->get; 
    $app->config($config);
    $app->finalize_config; # back-compat
    $app->next::method(@_);
}

sub finalize_config {} # back-compat

sub get_config_local_suffix {}
sub get_config_path {}

1;
