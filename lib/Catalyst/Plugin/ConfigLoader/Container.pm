package Catalyst::Plugin::ConfigLoader::Container;
use Bread::Board;
use Moose;
use Config::Any;
use Data::Visitor::Callback;
use Catalyst::Utils;

extends 'Bread::Board::Container';

has config_local_suffix => (
    is      => 'rw',
    isa     => 'Str',
    default => 'local',
);

has driver => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

has file => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has substitutions => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

has appname => (
    is      => 'rw',
    isa     => 'Str',
    default => 'TestApp',
);

sub BUILD {
    my $self = shift;

    container $self => as {
        service config_local_suffix => $self->config_local_suffix;
        service driver => $self->driver;
        service file => $self->file;
        service substitutions => $self->substitutions;
        service appname => $self->appname;

        service config => (
            block => sub { shift->param('setup_config'); },
            dependencies => [ depends_on('setup_config') ],
        );

        service prefix => (
            block => sub { Catalyst::Utils::appprefix( shift->param('appname') ) },
            dependencies => [ depends_on('appname') ],
         );

        service path => (
            block => sub {
                my $s = shift;

                my $path = Catalyst::Utils::env_value( $s->param('appname'), 'CONFIG' )
                || $s->param('file')
                || $s->param('appname')->path_to( $s->param('prefix') );
                return $path;
            },
            dependencies => [ depends_on('file'), depends_on('appname'), depends_on('prefix') ],
        );

        service setup_config => (
            block => sub {
                my $s = shift;

                my $local_suffix = $s->param('get_config_local_suffix');
                my $files = $s->param('find_files');
                my $appname = $s->param('appname');

                my $cfg   = Config::Any->load_files(
                    {   files       => $files,
                        filter      => \&_fix_syntax,
                        use_ext     => 1,
                        driver_args => $s->param('driver'),
                    }
                );

                # map the array of hashrefs to a simple hash
                my %configs = map { %$_ } @$cfg;

                # split the responses into normal and local cfg
                my ( @main, @locals );
                for ( sort keys %configs ) {
                    if ( m{$local_suffix\.}ms ) {
                        push @locals, $_;
                    }
                    else {
                        push @main, $_;
                    }
                }
                $appname->config( $configs{$_} ) for @main, @locals;

                $s->param('finalize_config');
            },
            dependencies => [ depends_on('get_config_local_suffix'), depends_on('find_files'), depends_on('appname'), depends_on('finalize_config') ], 
        );

        service finalize_config => (
            block => sub {
                my $s = shift;

                my $v = Data::Visitor::Callback->new(
                    plain_value => sub {
                        return unless defined $_;
                        $self->_config_substitutions( $s->param('appname'), $_ );
                    }

                );
                $v->visit( $s->param('appname')->config ); 
            },
            dependencies => [ depends_on('appname') ],
        );

        service find_files => (
            block => sub {
                my $s = shift;

                my ( $path, $extension ) = @{$s->param('get_config_path')}; 
                my $suffix = $s->param('get_config_local_suffix');

                my @extensions = @{ Config::Any->extensions }; 

                my @files;
                if ( $extension ) {
                    die "Unable to handle files with the extension '${extension}'" unless grep { $_ eq $extension } @extensions;
                    ( my $local = $path ) =~ s{\.$extension}{_$suffix.$extension};
                    push @files, $path, $local;
                } else {
                    @files = map { ( "$path.$_", "${path}_${suffix}.$_" ) } @extensions;
                }
                return \@files;
            }, 
            dependencies => [ depends_on('get_config_path'), depends_on('get_config_local_suffix') ],
        );

        service get_config_path => (
            block => sub {
                my $s = shift;

                my $path = $s->param('path');
                my $prefix = $s->param('prefix');

                my ( $extension ) = ( $path =~ m{\.(.{1,4})$} );

                if ( -d $path ) {
                    $path =~ s{[\/\\]$}{};
                    $path .= "/$prefix";
                }

                return [ $path, $extension ];
            },
            dependencies => [ depends_on('prefix'), depends_on('path') ],
        );

        service get_config_local_suffix => (
            block => sub {
                my $s = shift;
                my $suffix = Catalyst::Utils::env_value( $s->param('appname'), 'CONFIG_LOCAL_SUFFIX' ) || $s->param('config_local_suffix');

                return $suffix;
            },
            dependencies => [ depends_on('appname'), depends_on('config_local_suffix') ],
        );

    };
}

sub _fix_syntax {
    my $config     = shift;
    my @components = (
        map +{
            prefix => $_ eq 'Component' ? '' : $_ . '::',
            values => delete $config->{ lc $_ } || delete $config->{ $_ }
        },
        grep { ref $config->{ lc $_ } || ref $config->{ $_ } }
            qw( Component Model M View V Controller C Plugin )
    );

    foreach my $comp ( @components ) {
        my $prefix = $comp->{ prefix };
        foreach my $element ( keys %{ $comp->{ values } } ) {
            $config->{ "$prefix$element" } = $comp->{ values }->{ $element };
        }
    }
}

sub _config_substitutions {
    my $self = shift;
    my $appname = shift;
    my $subs = $self->substitutions;
    $subs->{ HOME }    ||= sub { shift->path_to( '' ); };
    $subs->{ ENV }    ||=
        sub {
            my ( $c, $v ) = @_;
            if (! defined($ENV{$v})) {
                Catalyst::Exception->throw( message =>
                    "Missing environment variable: $v" );
                return "";
            } else {
                return $ENV{ $v };
            }
        };
    $subs->{ path_to } ||= sub { $appname->path_to( @_ ); };
    $subs->{ literal } ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    for ( @_ ) {
        s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $self, $2 ? split( /,/, $2 ) : () ) }eg;
    }
}

1;
