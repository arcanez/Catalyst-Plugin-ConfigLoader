use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";

use_ok 'Catalyst::Plugin::ConfigLoader::Container';

my $container = Catalyst::Plugin::ConfigLoader::Container->new;

isa_ok $container, 'Bread::Board::Container';

use_ok $container->fetch('name')->get;

is $container->name, $container->fetch('name')->get;
is $container->config_local_suffix, $container->fetch('config_local_suffix')->get;

is $container->name, 'TestApp';
is $container->config_local_suffix, 'local';

is $container->fetch('name')->get, 'TestApp';
is $container->fetch('config_local_suffix')->get, 'local';

isa_ok $container->fetch('config_path')->get, 'ARRAY';

done_testing;
