package Catalyst::Plugin::BigSitemap::SitemapBuilder;
use Modern::Perl '2012';
use WWW::Sitemap::XML;
use WWW::Sitemap::XML::URL;
use WWW::SitemapIndex::XML;
use Carp;
use Try::Tiny;
use Data::Dumper;
use Moose;

=head1 NAME 

=head1 DESCRIPTION

=head1 ATTRIBUTES

=shift 40

=item urls

=item sitemap_base_uri

=item is_gzipped

=item failed_count

=back

=cut

has 'urls'               => ( is => 'rw', isa => 'ArrayRef[WWW::Sitemap::XML::URL]', default => sub { [] } );
has 'sitemap_base_uri'   => ( is => 'ro', isa => 'URI::http' );
has 'is_gzipped'         => ( is => 'ro', isa => 'Bool' ); 
has 'sitemap_url_format' => ( is => 'ro', isa => 'Str' );

has 'failed_count'       => ( is => 'rw', isa => 'Int', default => 0 );

=head1 METHODS

=shift 40

=item add( $myUrlString )
=item add( loc => ?, changefreq => ?, priority => ? ) # last modified

This method comes in two flavors.  The first, take a single string parameter that should be the stringified version of the
URL you want to add to the sitemap.  The second flavor takes a hashref 

=item urls_count()

=item sitemap_count()

=item sitemap_index()

=item sitemap($index)


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
        warn "Failed to add parameter @params";        
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
    
    for (my $i = 0; $i < $self->sitemap_count; $i++) {   
             
        my $file_ext = $self->is_gzipped ? '.xml.gz' : '.xml';        
        $smi->add( loc => $self->sitemap_base_uri->as_string . "sitemap" . ($i + 1) . $file_ext );
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
            warn "Problem url" . Dumper $url;    
        };
    }
    
    return $sm;    
}


=head1 INTERNAL USE METHODS

=shift 40

=item _urls_slice($index)

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




1;