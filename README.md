# Catalyst::Plugin::BigSitemap

## Synposis

A [Catalyst Framework](http://catalystframework.org) Plugin that allows for automatic generation, and caching to disk
of [Sitemap](http://sitemaps.org/protocol.html) and [Sitemap Index](http://sitemaps.org/protocol#index) files to support
beyond the 50,000 URL max of a single sitemap, to a maximum of 2.5 billion urls.

## Note

This is designed to _almost_ be a drop-in replacement for the existing [Catalyst::Plugin::Sitemap](https://metacpan.org/module/Catalyst::Plugin::Sitemap), 
and the URL attributes work the exact same way.  


An action that resolves to a single URL can be defined as such:
```
sub my_action :Path('/my/action') :Sitemap {
    # stuff your action does..
}

# we need to document explicit parameter declaration
```

An action that resolves to multiple URLs must be defined in the following way:
```
sub my_multiple_url_action :Path('/my/action') :Sitemap('*') {
}

sub my_multiple_url_action_sitemap {
    my ($self, $c, $sitemap) = @_;

    my $rs = $c->model('SiteDB::Product)->search(undef);
    while (my $row = $rs->next) {
        my $uri = $c->uri_for( $c->controller('mycontroller')->action_for('my_multiple_url_action'), [ $row->id ]);
        $sitemap->add( $uri );
        # OR you can add a string ->add('http://mysite/url/');
        # OR you can add via parameterized ->add(loc=>?, changefreq=>?, lastmod=>?, priority=>?);
    }
}
```
