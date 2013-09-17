package Catalyst::Plugin::BigSitemap;
use Modern::Perl '2012';
use Catalyst::Plugin::BigSitemap::SitemapBuilder;
use WWW::SitemapIndex::XML;
use WWW::Sitemap::XML;
use Path::Class;
use Carp;
use Moose;

BEGIN { $Catalyst::Package::BigSitemap::VERSION = '0.1'; }

#has 'sitemap_index' => ( is => 'rw', isa => 'XML::LibXML::Document',           );
#has 'sitemap_files' => ( is => 'rw', isa => 'HashRef[XML::LibXML::Document]',  );
#has 'update_freq'   => ( is => 'rw', isa => 'Int',                             );'

=head1 NAME Catalyst::Plugin::BigSitemap

=head1 DESCRIPTION

A nearly drop-in replacement for Catalyst::Plugin::Sitemap that builds a Sitemap Index file
as well as your normal Sitemap Files (to support websites with more than 50,000 urls).  

Additionally, this method allows for storing your sitemap files to disk once they are built,
and can automatically rebuild them for you at a specified interval

=head1 ATTRIBUTES

=head2 sitemap_builder

=cut

has 'sitemap_builder' => ( is => 'rw', builder => '_get_sitemap_builder', lazy => 1, );


=head1 CONFIG-SPECIFIED ATTRIBUTES

The following attributes pull their configuration through your application's configuration.

If you're using the default setup on new Catalyst builds, this will be in a L<Config::General>
file, and would look something like this.

<Plugin::BigSitemap>
    cache_dir /tmp/myapp/sitemap
    live_rebuilds 1
    rebuildfreq daily
    
</Plugin::BigSitemap>

=over 40

=item cache_dir (REQUIRED)

The absolute path to the directory where your sitemaps should be stored.  This really shouldn't be a 
web-accessible directory.  This can be something like C</tmp/myapp/sitemap> or on windows 
C<%USERPROFILE%\AppData\Local\Temp\myapp\sitemap>.  

=item live_rebuilds (Optional)

=item rebuildfreq (Optional) 


=back

=cut

sub write_sitemap_cache {
    my $self = shift;
    
    my $temp_dir    = Path::Class::tempdir( cleanup => 1 );
    my $temp_dh     = $temp_dir->open() || croak $!;
    
    my $cache_dir   = dir( $self->config->{'Plugin::BigSitemap'}->{cache_dir} );
    my $cache_dh    = $cache_dir->open() || croak $!;
    
    # create a temp build directory
    # keep an array of all of our sitemap paths
    # loop over all of our files, and create gzipped sitemap files in their place.
    
    # lastly, create our sitemap index file
    
    # get a handle to our cache directory -- create it if it doesn't exist
    
    
    
    
}

=back

=head1 INTERNAL USE METHODS

=head2 _get_sitemap_builder()

Returns a sitemap builder object that's fully populated with all the sitemap urls registered.

=cut

sub _get_sitemap_builder {
    my $self = shift;
    
    # TODO: allow this to be pulled from a configuration file
    my $sb = Catalyst::Plugin::BigSitemap::SitemapBuilder->new(
        sitemap_base_uri => $self->req->base,
        is_gzipped => $self->config->{''}->{is_gzipped} || 0,
        sitemap_url_format => $self->config->{''}->{sitemap_url_format} || ''
    );
    
    # Ugly ugly .. but all we're doing here is looping over every action of every controller in our application.
    foreach my $controller ( map { $self->controller($_) } $self->controllers ) {  
        
        ACTION: 
        foreach my $action ( map { $controller->action_for( $_->name ) } $controller->get_action_methods ) {

            # Make sure there's at least one sitemap action .. break and complain loudly if there is more than one sitemap
            my $attr = $action->attributes->{Sitemap} or next ACTION;
            # TODO: need to show the fully qualified name here
            croak "more than one attribute 'Sitemap' for sub " if @$attr > 1;

            my @attr = split /\s*(?:,|=>)\s*/, $attr->[0];

            my %uri_params;

            if ( @attr == 1 ) {
                
                # * indicates that this action maps to multiple urls.
                # The user must create a method named myactionname_sitemap 
                # which must populate our sitemap builder with all the urls
                if ( $attr[0] eq '*' ) {
                    my $sitemap_method = $action->name . "_sitemap";

                    if ( $controller->can($sitemap_method) ) {
                        $controller->$sitemap_method( $self, $sb );
                        next ACTION;
                    }
                }

                if ( $attr[0] + 0 > 0 ) {
                    # it's a number 
                    $uri_params{priority} = $attr[0];
                }

            }
            elsif ( @attr > 0 ) {
                %uri_params = @attr;
            }

            $uri_params{loc} = $self->uri_for_action( $action->private_path );
            $sb->add(%uri_params);
                               
        } # foreach $action             
    } # foreach $controller
    
    return $sb;
}


1;
