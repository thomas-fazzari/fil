use Mojo::Base -strict, -signatures;

use Test::More;
use Test::Mojo;
use Mojo::JSON qw(false);
use Mojolicious;

my $year  = (localtime)[5] + 1900;
my %entry = (
  id           => 7,
  title        => 'Hello <world>',
  url          => 'https://example.com/hello',
  comments_url => 'https://news.example.com/item/7',
  content      =>
    '<p><strong><a href="https://example.com/hello">Hello &lt;world&gt;</a></strong></p><p>The body of the entry.</p>',
  status       => 'unread',
  starred      => false,
  reading_time => 3,
  published_at => "$year-10-06T08:00:00Z",
  feed         => {id => 5, title => 'Example'}
);

my (@read, @bookmarked, %query);
my $miniflux = Mojolicious->new;
$miniflux->log->level('fatal');
my $r = $miniflux->routes;
$r->get(
  '/v1/entries' => sub ($c) {
    my %params = $c->req->query_params->to_hash->%*;
    %query = %params;
    my @entries = (\%entry);
    @entries = ({%entry, id => 12, feed => {id => 6, title => 'Other'}}) if ($params{feed_id} // 0) == 6;
    @entries = ()                                                        if ($params{search}  // '') eq 'nothing';
    $c->render(json => {total => scalar @entries, entries => \@entries});
  }
);
$r->get('/v1/entries/7' => sub ($c) { $c->render(json => \%entry) });

# Entry 8 only links to its comments, like Lobsters, entry 9 cannot be fetched,
# entry 10 only repeats its title and entry 11 has a title without words
my %link = (%entry, content => '<p><a href="https://lobste.rs/s/1">Comments</a></p>');
my @fetched;
$r->get('/v1/entries/8'  => sub ($c) { $c->render(json => {%link,  id => 8}) });
$r->get('/v1/entries/9'  => sub ($c) { $c->render(json => {%link,  id => 9}) });
$r->get('/v1/entries/10' => sub ($c) { $c->render(json => {%entry, id => 10, content => '<h1>Hello world</h1>'}) });
$r->get(
  '/v1/entries/11' => sub ($c) {
    $c->render(json => {%entry, id => 11, title => '🎉', content => '<p><img src="https://example.com/a.png"></p>'});
  }
);
$r->get(
  '/v1/entries/12' => sub ($c) {
    $c->render(
      json => {%entry, id => 12, content => '<iframe src="https://www.youtube-nocookie.com/embed/x"></iframe>'});
  }
);
$r->get(
  '/v1/entries/<id:num>/fetch-content' => sub ($c) {
    return $c->render(json => {error_message => 'unreachable'}, status => 500) if $c->param('id') == 9;
    push @fetched, $c->param('update_content');
    $c->render(json => {content => '<p>The text of the linked page.</p>'});
  }
);
$r->get(
  '/v1/feeds' => sub ($c) {
    $c->render(
      json => [
        {id => 5, title => 'Example', category => {id => 1, title => 'rust'}},
        {id => 6, title => 'Other',   category => {id => 2, title => 'blogs'}}
      ]
    );
  }
);
$r->get('/v1/feeds/counters' => sub ($c) { $c->render(json => {reads => {}, unreads => {5 => 3}}) });
$r->put('/v1/entries'            => sub ($c) { push @read,       $c->req->json; $c->rendered(204) });
$r->put('/v1/entries/7/bookmark' => sub ($c) { push @bookmarked, 7;             $c->rendered(204) });

my $t = Test::Mojo->new('Fil');
$t->app->miniflux->url('')->token('test')->ua->server->app($miniflux);

subtest 'Unread' => sub {
  $t->get_ok('/')
    ->status_is(200)
    ->header_like('Content-Security-Policy' => qr/default-src 'none'/)
    ->header_like('Content-Security-Policy' => qr{frame-src https://www\.youtube-nocookie\.com;})
    ->text_is('.tabs__tab[aria-current="page"] .tabs__label' => 'Unread')
    ->text_is('.month__title'                                => 'October')
    ->text_is('.entries__day'                                => '6')
    ->text_is('.entries__title[href="/entries/7"]'           => 'Hello <world>')
    ->text_is('.entries__source'                             => 'Example')
    ->element_exists('script[type="module"][data-turbo-track="reload"][src^="/turbo.es2017-esm.js?"]')
    ->element_exists('meta[name="turbo-cache-control"][content="no-preview"]')
    ->element_exists('meta[name="turbo-refresh-method"][content="morph"]')
    ->element_exists('meta[name="turbo-refresh-scroll"][content="preserve"]')
    ->element_exists('.entries__title[data-turbo-prefetch="false"]')
    ->element_exists('.history button[data-history="back"][aria-label="Back"]')
    ->element_exists('.history button[data-history="forward"][aria-label="Forward"]')
    ->element_exists('script[type="module"][src^="/js/history.js?"]');
  $t->get_ok('/js/history.js')->status_is(200);
  $t->get_ok('/turbo.es2017-esm.js')->status_is(200);
  is_deeply \%query,
    {status => 'unread', order => 'published_at', direction => 'desc', limit => 100, globally_visible => 'true'},
    'newest first, without the feeds hidden from the lists';
};

subtest 'All and bookmarks' => sub {
  $t->get_ok('/all')->status_is(200)->text_is('.tabs__tab[aria-current="page"] .tabs__label' => 'All');
  is_deeply $query{status}, ['unread', 'read'], 'read and unread';
  $t->get_ok('/bookmarks')->status_is(200)->text_is('.tabs__tab[aria-current="page"] .tabs__label' => 'Bookmarks');
  is $query{starred}, 'true', 'bookmarked only';
};

subtest 'Search' => sub {
  $t->get_ok('/all?q=hello')
    ->status_is(200)
    ->element_exists('.search__input[value="hello"]')
    ->element_exists('.search__input[autocomplete="off"][aria-keyshortcuts="/ Meta+K Control+K"]')
    ->element_exists('script[type="module"][src^="/js/search.js?"]');
  is $query{search}, 'hello', 'search sent to Miniflux';
  $t->get_ok('/js/search.js')->status_is(200);
  $t->get_ok('/')->text_is('.search__shortcut[aria-hidden="true"]' => 'Ctrl K');
  $t->get_ok('/' => {'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15.0)'})
    ->text_is('.search__shortcut' => '⌘K');
  $t->get_ok('/?q=nothing')->status_is(200)->text_is('.empty' => 'No results.');
  $t->get_ok('/all?q=oth')
    ->element_count_is('.entries__title', 2)
    ->element_exists('.entries__title[href="/entries/12"]');
};

subtest 'Sidebar and filters' => sub {
  $t->get_ok('/')
    ->element_count_is('.sidebar .tree__group',         2)
    ->element_count_is('#drawer[popover] .tree__group', 2)
    ->text_like('.sidebar .tree__group:nth-of-type(1) .tree__summary .tree__item' => qr/^\s*blogs\s*$/)
    ->text_like('.sidebar .tree__group:nth-of-type(2) .tree__summary .tree__item' => qr/^\s*rust\s*$/)
    ->text_is('.sidebar .tree__group:nth-of-type(2) .tree__summary .tree__count' => '3')
    ->element_exists('.masthead__toggle button[aria-label="Filters"][aria-expanded="true"]')
    ->element_exists_not('.icon-button--active')
    ->element_exists('.masthead__drawer[popovertarget="drawer"]')
    ->element_exists('#drawer button[popovertarget="drawer"][popovertargetaction="hide"][aria-label="Close"] svg.icon')
    ->element_exists('.tree__item[href="/?feed=5"]')
    ->element_exists_not('.tree__group[open]')
    ->element_exists('.entries__source[href="/?feed=5"]');

  $t->get_ok('/?category=1')
    ->element_exists('.sidebar .tree__group[open] .tree__item[aria-current][href="/"] svg.icon')
    ->element_exists('.masthead__toggle .icon-button--active')
    ->element_exists('.tabs__tab[href="/all?category=1"]')
    ->element_exists('.search input[type="hidden"][name="category"][value="1"]');
  is $query{category_id}, 1, 'category sent to Miniflux';

  $t->get_ok('/all?feed=5&q=x')
    ->element_exists('.sidebar .tree__group[open] .tree__item[aria-current][href="/all"]')
    ->element_exists('.masthead__drawer.icon-button--active');
  is $query{feed_id}, 5, 'feed sent to Miniflux';

  $t->get_ok('/?category=nope')->status_is(200)->element_exists_not('.icon-button--active');
  ok !exists $query{category_id}, 'invalid category ignored';
};

subtest 'Hide the sidebar' => sub {
  $t->post_ok('/sidebar' => {Referer => 'http://127.0.0.1:3000/all?feed=5'})
    ->status_is(303)
    ->header_is(Location => '/all?feed=5');
  $t->get_ok('/all')
    ->element_exists('.layout--collapsed')
    ->element_exists_not('.sidebar')
    ->element_exists('.masthead__toggle button[aria-expanded="false"]')
    ->text_is('.masthead .tabs__tab[aria-current] .tabs__label' => 'All');

  $t->post_ok('/sidebar' => {Referer => 'https://elsewhere.example/x'})->header_is(Location => '/x');
  $t->post_ok('/sidebar' => {Referer => 'https://elsewhere.example//elsewhere.example/x'})->header_is(Location => '/');
  $t->post_ok('/sidebar');
  $t->get_ok('/all')->element_exists('.sidebar');
};

subtest 'Entry' => sub {
  $t->get_ok('/entries/7')
    ->status_is(200)
    ->element_exists_not('.tabs__tab[aria-current]')
    ->text_is('.entry__title a' => 'Hello <world>')
    ->text_like('.entry__meta span' => qr/Example · 6 October $year\s+· 3 min read/)
    ->element_count_is('.entry__content > p', 1)
    ->text_is('.entry__content > p' => 'The body of the entry.')
    ->element_exists('.entry__actions a[href="https://news.example.com/item/7"][aria-label="Comments"] svg.icon')
    ->element_exists('.entry__actions button[aria-label="Bookmark"][aria-pressed="false"] svg.icon');
  is_deeply \@read, [{entry_ids => [7], status => 'read'}], 'marked read on view';
};

subtest 'Entries without text' => sub {
  $t->get_ok('/entries/8')->status_is(200)->text_is('.entry__content > p' => 'The text of the linked page.');
  is_deeply \@fetched, ['true'], 'fetched once and kept by Miniflux';

  $t->get_ok('/entries/9')
    ->status_is(200)
    ->element_exists_not('.entry__content')
    ->element_exists('.empty a[href="https://example.com/hello"]');

  $t->get_ok('/entries/10')->text_is('.entry__content > p' => 'The text of the linked page.');
  is_deeply \@fetched, ['true', 'true'], 'fetched once the title is left out';
  $t->get_ok('/entries/11')->element_exists('.entry__content img');
  $t->get_ok('/entries/12')->element_exists('.entry__content iframe');
  is scalar @fetched, 2, 'a video alone is content';
  $t->get_ok('/entries/404')->status_is(404);
};

subtest 'Export to Markdown' => sub {
  my $read = @read;
  $t->get_ok('/entries/7')
    ->element_exists(
    '.entry__actions a[href="/entries/7/markdown"][download][aria-label="Export to Markdown"] svg.icon');
  $t->get_ok('/entries/7/markdown')
    ->status_is(200)
    ->content_type_like(qr{^text/markdown})
    ->header_is('Content-Disposition' => 'attachment; filename="hello-world.md"')
    ->content_is(
    "# Hello <world>\n\n[Example](https://example.com/hello) · 6 October $year\n\nThe body of the entry.\n");
  is scalar @read, $read + 1, 'only the visit marks it read';
  $t->get_ok('/entries/404/markdown')->status_is(404);
};

subtest 'Bookmark' => sub {
  $t->post_ok('/entries/7/bookmark')->status_is(303)->header_is(Location => '/entries/7');
  is_deeply \@bookmarked, [7], 'toggled';
};

subtest 'Filter context follows the entry' => sub {
  $t->get_ok('/?feed=5')->element_exists('.entries__title[href="/entries/7?feed=5"]');
  $t->get_ok('/entries/7?feed=5')
    ->element_exists('.sidebar .tree__group[open][data-category="1"] .tree__item[aria-current]')
    ->element_exists('.entry__actions form[action="/entries/7/bookmark?feed=5"]')
    ->element_exists('script[type="module"][src^="/js/sidebar.js?"]');
  $t->post_ok('/entries/7/bookmark?feed=5')->status_is(303)->header_is(Location => '/entries/7?feed=5');
  $t->get_ok('/js/sidebar.js')->status_is(200);
};

subtest 'Theme' => sub {
  $t->get_ok('/')
    ->element_exists('html[data-theme="dark"]')
    ->element_exists('meta[name="color-scheme"][content="dark"]')
    ->element_exists('form[data-theme-toggle] button[aria-label="Toggle theme"]')
    ->element_exists('script[type="module"][src^="/js/theme.js?"]');
  $t->post_ok('/theme' => {Referer => 'http://127.0.0.1:3000/all'})->status_is(303)->header_is(Location => '/all');
  $t->get_ok('/')
    ->element_exists('html[data-theme="light"]')
    ->element_exists('meta[name="color-scheme"][content="light"]');
  $t->post_ok('/theme');
  $t->get_ok('/')->element_exists('html[data-theme="dark"]');
  $t->get_ok('/js/theme.js')->status_is(200);
};

done_testing;
