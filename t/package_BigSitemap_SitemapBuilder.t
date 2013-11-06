use Modern::Perl '2010';
use Try::Tiny;
use DateTime;
use Test::More;

BEGIN {
    use_ok 'URI::http';
    use_ok 'WWW::Sitemap::XML::URL'; 
    use_ok 'Catalyst::Plugin::BigSitemap::SitemapBuilder' 
};

diag "Testing Catalyst::Plugin::BigSitemap::SitemapBuilder module";

# test adding good and bad urls 
# make sure failed, urls_count, sitemap_count and failed_count all increment correctly.
{       
    my $sb = Catalyst::Plugin::BigSitemap::SitemapBuilder->new( 
        sitemap_base_uri    => URI->new('http://localhost/'), 
        sitemap_name_format => 'sitemap%d.xml'
    );
    
    # test adding valid urls in 5 different ways
    my $uri_string = 'http://www.google.com';
    $sb->add( $uri_string );
    
    my $uri = URI->new('http://www.google.com');
    $sb->add( $uri );
    
    my %np_string1 = ( loc => $uri_string,  );
    $sb->add( %np_string1 );
    
    my %np_string2 = ( loc => $uri_string, lastmod => '2013-19-09', changefreq => 'always', priority => 1.0 );
    $sb->add( %np_string2 );
    
    my %np_uri = ( loc => $uri );
    $sb->add( %np_uri );
    
    # make sure zero errors, 5 urls and 1 sitemap
    cmp_ok( $sb->failed_count,  '==', 0, 'SitemapBuilder->faild_count should report 0 after successful adds.');
    cmp_ok( $sb->urls_count,    '==', 5, 'SitemapBuilder->urls_count() should report 5 after 5 successful calls to add.' );
    cmp_ok( $sb->sitemap_count, '==', 1, 'Sitemap_count() should report 1 after 5 successful adds.');
    
    # test adding 2 bad urls
    my ( $bad_uri1, $bad_uri2 ) = ( 'I am not a URI', DateTime->now() );    
    $sb->add( $bad_uri1 );
    $sb->add( $bad_uri2 );
    
    cmp_ok( $sb->urls_count,    '==', 5, 'SitemapBuilder->urls_count should report the same as the number of elements in URLs array.' );
    cmp_ok( $sb->failed_count,  '==', 2, 'SitemapBuilder->failed_count should report 2 after 2 invalid adds.' );
    cmp_ok( $sb->sitemap_count, '==', 1, 'Sitemap_builder->sitemap_count should still report 1 after 5 successful adds and 2 failed adds.' );
    
} # incrementing tests


{ # test large number of urls 
    
    my $sb = Catalyst::Plugin::BigSitemap::SitemapBuilder->new( 
        sitemap_base_uri    => URI->new('http://www.summersetsoftware.com/'), 
        sitemap_name_format => 'sitemap%d.xml'
    );
    
    # this is handled by BigSitemap, but since we're instantiating 
    # SitemapBuilder ourselves, we need to wrap this in a transaction (otherwise, takes an hour+ to run)
    $sb->dbh->begin_work;
    for ( my $i = 0; $i < 50_000; $i++ ) {
        $sb->add( "http://www.summersetsoftware.com/$i" );   
        diag("at $i") unless $i % 100;     
    }
    $sb->dbh->commit;
    
    cmp_ok( $sb->urls_count,    '==', 50_000, 'SitemapBuilder should report 50,000 URLS from urls_count after 50,000 valid adds.' );
    cmp_ok( $sb->failed_count,  '==', 0, 'SitemapBuilder->failed_count should report 0 after 50,000 valid adds.' );
    cmp_ok( $sb->sitemap_count, '==', 1, 'Sitemap_builder->sitemap_count should still report 1 after 50,000 URLs added' );
    
    # add one more
    $sb->add( 'http://www.summersetsoftware.com/50000' );
    cmp_ok( $sb->sitemap_count, '==', 2, 'sitemap_count should report 2 after 50,001 URLs added.' );
    cmp_ok( $sb->urls_count,    '==', 50_001, 'urls_count should report 50,001 URLs after 50,001 valid adds.' );
    
    # make sure the actual urls we're expecting are being returned in our slices
    my @sitemap_1_urls = $sb->_urls_slice(0);
    my @sitemap_2_urls = $sb->_urls_slice(1);    
    cmp_ok( @sitemap_1_urls, '==', 50_000, 'Expecting 50,000 URLs in first _urls_slice of SitemapBuilder with 50,001 URLs.' );
    cmp_ok( @sitemap_2_urls, '==', 1, 'Expecting 1 URL in second _urls_slice of SitemapBuilder with 50,001 URLs.' );
        
}


done_testing();