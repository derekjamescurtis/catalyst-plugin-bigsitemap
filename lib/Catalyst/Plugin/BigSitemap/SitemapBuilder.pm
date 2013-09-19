package Catalyst::Plugin::BigSitemap::SitemapBuilder;
use Modern::Perl '2010';
use WWW::Sitemap::XML;
use WWW::Sitemap::XML::URL;
use WWW::SitemapIndex::XML;
use Carp;
use Try::Tiny;
use Data::Dumper;
use Moose;

=head1 NAME Catalyst::Plugin::BigSitemap::SitemapBuilder - Helper object for the BigSitemap plugin

=head1 DESCRIPTION

This object's role is to accept a collection of L<WWW::Sitemap::XML::URL> objects via the L<add>
method.  

=head1 CONSTRUCTOR

There are two required parameters that must be passed to the constructor, L<sitemap_base_uri> and
L<sitemap_name_format>.  


=head1 ATTRIBUTES

=shift 4

=item urls - I<ArrayRef> of L<WWW::Sitemap::XML::URL>

=item sitemap_base_uri - I<Str>

=item sitemap_name_format - I<URI::http>

=item failed_count - I<Int>

A running count of all the URLs that failed validation in the L<WWW::Sitemap::XML::URL> module and could not 
be added to the collection.. This should always report zero unless you've screwed something up in your
C<sub my_action_sitemap> controller methods.

=back

=cut

has 'urls'               => ( is => 'rw', isa => 'ArrayRef[WWW::Sitemap::XML::URL]', default => sub { [] } );
has 'sitemap_base_uri'   => ( is => 'ro', isa => 'URI::http' );
has 'sitemap_name_format'=> ( is => 'ro', isa => 'Str' );
has 'failed_count'       => ( is => 'rw', isa => 'Int', default => 0 );

=head1 METHODS

=over 4

=item add( $myUrlString )
=item add( loc => ?, changefreq => ?, priority => ? ) # last modified

This method comes in two flavors.  The first, take a single string parameter that should be the stringified version of the
URL you want to add to the sitemap.  The second flavor takes a hashref 

=item urls_count()

=item sitemap_count()

=item sitemap_index()

=item sitemap($index)

B<Note:> $index is a 1-based index (as well as being an integer value, if you didn't figure that much out ;) ) 

=back
=cut

sub add {
    my $self = shift;
    my @params = @_;
    
    # create our url object.. for compatability with Catalyst::Plugin::Sitemap
    # we allow a single string parameter to be passed in.
    my $u;
    try {
        if (@params == 1){  
            $u = WWW::Sitemap::XML::URL->new(loc => $params[0]);
        }
        elsif (@params > 1) {       
            my %ph = @params;      
            $u = WWW::Sitemap::XML::URL->new(%ph);
        }
        else {                        
            die "add requires at least one argument";  
        }
        
        push @{$self->urls}, $u;        
    }
    catch {
        warn $!;
        warn "Failed to add url.  The following parameters were specified: @params";        
        $self->failed_count($self->failed_count + 1);
    };
    
}

sub urls_count {
    my $self = shift;    
    return scalar @{$self->urls};
}

sub sitemap_count {
    my $self = shift;
    
    my $whole_pages     = int ( $self->urls_count / 50_000 );
    my $partial_pages   = $self->urls_count % 50_000 ? 1 : 0; 
    
    return $whole_pages + $partial_pages;    
}

sub sitemap_index {
    my $self = shift;
    
    my $smi = WWW::SitemapIndex::XML->new();
    
    for (my $index = 0; $index < $self->sitemap_count; $index++) {   
        # TODO: support lastupdate
        # TODO: document that we're using 1-based indexes for the sitemap files
        $smi->add( loc => $self->sitemap_base_uri->as_string . sprintf($self->sitemap_url_format, ($index + 1)) );
    }
    
    return $smi;    
}

sub sitemap {
    my $self = shift;
    my $index = shift;
    
    my @sitemap_urls = $self->_urls_slice( $index );
    
    my $sm = WWW::Sitemap::XML->new();
    
    foreach my $url (@sitemap_urls) {
        try{            
            $sm->add($url);    
        }
        catch{
            warn "Problem adding url to sitemap: " . Dumper $url;    
        };
    }
    
    return $sm;    
}


=head1 INTERNAL USE METHODS

Methods you're not meant to use directly.

=over 4

=item _urls_slice($index)

Returns an array slice of URLs for the sitemap at the provided index.  
Sitemaps can consist of up to 50,000 URLS, when creating the slice, 
we use the assumption that we'll try to get up to 50,000 per each 
sitemap.

=back
=cut

sub _urls_slice {
    my ($self, $index) = @_;
    
    my $start_index = $index * 49_999;
    my $end_index   = 0;
    
    if ($index + 1 == $self->sitemap_count) {
        $end_index  = ($self->urls_count % 50_0000) - 1;        
    }
    else {
        $end_index  = $start_index + 50_000;
    }
        
    return @{$self->urls}[$start_index .. $end_index];    
}

=head1 SEE ALSO

=head1 AUTHOR

Derek J. Curtis <djcurtis@summersetsoftware.com>

Summerset Software, LLC

L<http://www.summersetsoftware.com>

=head1 COPYRIGHT

Derek J. Curtis 2013

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;