package Catalyst::Plugin::BigSitemap::SitemapBuilder;
use Modern::Perl '2010';
use WWW::Sitemap::XML;
use WWW::Sitemap::XML::URL;
use WWW::SitemapIndex::XML;
use Carp;
use Try::Tiny;
use Data::Dumper;
use DBI;
use DBD::SQLite;
use File::Temp qw/tempdir/;
use Path::Class;
use Moose;

=head1 NAME 

Catalyst::Plugin::BigSitemap::SitemapBuilder - Helper object for the BigSitemap plugin

=head1 VERSION

0.02

=head1 DESCRIPTION

This object's role is to accept a collection of L<WWW::Sitemap::XML::URL> objects via the L<add>
method.  

=head1 CONSTRUCTOR

There are two required parameters that must be passed to the constructor, L<sitemap_base_uri> and
L<sitemap_name_format>.  


=head1 ATTRIBUTES

=shift 4

=item urls - I<ArrayRef> of L<WWW::Sitemap::XML::URL>

A collection of every URL in your application that will be included in the sitemap.

=item sitemap_base_uri - L<URI::http>

The base URI that should be used when resolving the action urls in your application.  
You should really specify this manually, in the event that one day you want to start
run this module from a cron job.

=item sitemap_name_format - I<Str>

A sprintf style format for the names of your sitemap files.  Note:  The names of the sitemap files
will start by inserting the number 1 and incrementing for each sitemap file written.  It's important
to note that in code, calls to the sitemap method use a 0-based-index but your sitemap filenames are
1-based.  This is just that way so the names of the individual sitemaps match to the examples given
on the L<http://www.sitemaps.org> website.

=item failed_count - I<Int>

A running count of all the URLs that failed validation in the L<WWW::Sitemap::XML::URL> module and could not 
be added to the collection.. This should always report zero unless you've screwed something up in your
C<sub my_action_sitemap> controller methods.

=back

=head1 TODOs

lastmod is not supported on the sitemap index.

=cut

# has 'urls'                  => ( is => 'rw', isa => 'ArrayRef[WWW::Sitemap::XML::URL]', default => sub { [] } );
has 'sitemap_base_uri'      => ( is => 'ro', isa => 'URI' );
has 'sitemap_name_format'   => ( is => 'ro', isa => 'Str' );
has 'failed_count'          => ( is => 'rw', isa => 'Int', default => 0 );
has 'dbh'                   => ( is => 'ro', builder => '_build_dbh' );

=head1 METHODS

=over 4

=item add( $myUrlString )
=item add( $myUriObject )
=item add( loc => ? [, changefreq => ?] [, priority => ?] [, lastmod => ?] )

This method comes in three flavors.  The first, take a single string parameter that should be the stringified version of the
URL you want to add to the sitemap. The second, takes a URI::http object.  The last flavor takes a hashref containing all your
input parameters. 

=item urls_count() = Int

.. how many urls total have been added to the builder.

=item sitemap_count() - Int

.. how many total sitemap files can be built with this data.

=item sitemap_index() - L<WWW::SitemapIndex::XML>

Generates and returns a new sitemapindex object based on the urls currently in this object's
urls collection, the sitemap_base_uri and the sitemap_name_format setting.  

=item sitemap($index) - L<WWW::Sitemap::XML>

Generates and returns a new sitemap object based at your requested index.

B<Note:> $index is a 0-based index of the sitemap you want to retrieve. 

=back

=cut

sub add {
    my $self = shift;
    my @params = @_;
    
    # create our url object.. for compatability with Catalyst::Plugin::Sitemap
    # we allow a single string parameter to be passed in.
    #
    # NOTE: The WWW::Sitemap::XML::URL object is immediately discarded afterwards.  This is 
    # a quick way to make sure it validates properly before we put it in the database.
    my $u;
    try {    	
        if (@params == 0) {
            croak "method add() requires at least one argument.";
        }
        elsif (@params == 1){  
        	# if only a single parameter is provided, we assume it's location
            $u = WWW::Sitemap::XML::URL->new(loc => $params[0]);
        }
        elsif (@params % 2 == 0) {       
        	# otherwise, we need an even number of args
            my %ph = @params;      
            $u = WWW::Sitemap::XML::URL->new(%ph);
        }        
        else {                        
            croak "method add() requires either a single argument, or an even number of arguments.";  
        }
        
        my $insert_cmd = $self->dbi->prepare('INSERT INTO uri (loc, lastmod, changefreq, priority) VALUES (?,?,?,?)');
        $insert_cmd->execute($u->loc, $u->lastmod, $u->changefreq, $u->priority);        
    }
    catch {   
        $self->failed_count($self->failed_count + 1);
    };
    
}

sub urls_count {
    my $self = shift;
    
    return $self->dbh->selectrow_hashref('SELECT COUNT(*) AS c FROM uri')->{c};
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
        $smi->add( loc => $self->sitemap_base_uri->as_string . sprintf($self->sitemap_url_format, ($index + 1)) );
    }
    
    return $smi;    
}

sub sitemap {
    my ( $self, $index ) = @_;    
    
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

Methods you're not meant to use directly, so don't!  They're here for documentation
purposes only.

=over 4

=item _urls_slice($index)

Returns an array slice of URLs for the sitemap at the provided index.  
Sitemaps can consist of up to 50,000 URLS, when creating the slice, 
we use the assumption that we'll try to get up to 50,000 per each 
sitemap.

=back

=cut

sub _urls_slice {
    my ( $self, $index ) = @_;
    
    my $start_index = $index * 50_000;
    
    my $rows = $self->dbh->selectall_hashref("SELECT * FROM uri LIMIT 50000 OFFSET $start_index", 'id');
    my @urls = ();
    foreach my $id (keys %$rows) {
        my $d = $rows->{$id};
        push @urls, WWW::Sitemap::XML::URL->new(
            loc         => $d->{loc}, 
            lastmod     => $d->{lastmod}, 
            changefreq  => $d->{changefreq}, 
            priority    => $d->{priority}
        );
    }
    
    return @urls;
}

=head1 BUILDER METHODS

=over 4

=item dbh_builder()

=back

=cut

sub _build_dbh {
    my $self = shift;
    
    # create + connect to temporary database
    my $db_path = Path::Class::File->new(tempdir(CLEANUP => 1), 'catalyst-plugin-bigsitemap.db')->stringify();    
    my $dbh = DBI->connect(
                'dbi:SQLite:dbname=' . $db_path,
                '',''
              ) || die 'Could not create database';
              
    # make our single table to use
    $dbh->do('CREATE TABLE uri (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                loc TEXT NOT NULL,
                lastmod TEXT NULL,
                changefreq TEXT NULL,
                priority TEXT NULL,
              );');
    
    return $dbh;    
}



=head1 SEE ALSO

=head1 AUTHOR

Derek J. Curtis C<djcurtis at summersetsoftware dot com>

=head1 COPYRIGHT

Derek J. Curtis 2013

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;