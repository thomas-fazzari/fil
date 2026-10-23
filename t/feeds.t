use Mojo::Base -strict, -signatures;

use Test::More;
use Fil::Feeds qw(load_feeds);
use Mojo::File qw(tempfile);

sub load ($toml) { load_feeds(tempfile->spew($toml, 'UTF-8')) }

sub error ($toml) {
  eval { load($toml); 1 } ? undef : $@;
}

subtest 'Feeds with categories and settings' => sub {
  my $loaded = load(<<~'EOF');
    block_filter_entry_rules = "EntryDate=max-age:30d"

    [blogs]
    "https://b.example/feed" = {}
    "https://a.example/feed" = { crawler = true }

    [news."https://c.example/rss"]
    blocklist_rules = '''
    (?i)webinar
    '''
    EOF

  my $feeds = $loaded->{feeds};
  is_deeply [map { $_->{url} } @$feeds], ['https://a.example/feed', 'https://b.example/feed', 'https://c.example/rss'],
    'sorted by category, then URL';
  is $feeds->[0]{category}, 'blogs', 'category from the table';
  ok $feeds->[0]{settings}{crawler}, 'boolean setting';
  isa_ok $feeds->[0]{settings}{crawler}, 'JSON::PP::Boolean';
  is_deeply $feeds->[1]{settings}, {}, 'no settings';
  is $feeds->[2]{settings}{blocklist_rules}, '(?i)webinar', 'trailing line break dropped';
  is_deeply $loaded->{user}, {block_filter_entry_rules => 'EntryDate=max-age:30d'}, 'root keys are user settings';
};

subtest 'Invalid files' => sub {
  like error('[blogs'),                               qr/^\S+: /, 'TOML syntax error names the file';
  like error(qq{blogs = "https://a.example/feed"\n}), qr/unknown setting "blogs" for the user/, 'unknown root key';
  like error(qq{[blogs]\n"a.example/feed" = {}\n}),   qr/"a.example\/feed" is not an HTTP URL/, 'URL without scheme';
  like error(qq{[a]\n"https://a.example/feed" = {}\n[b]\n"https://a.example/feed" = {}\n}),
    qr/"https:\/\/a.example\/feed" is in both "a" and "b"/, 'URL in two categories';
  like error(qq{[blogs]\n"https://a.example/feed" = true\n}),
    qr/settings of "https:\/\/a.example\/feed" must be a table/, 'settings not a table';
  like error(qq{[blogs]\n"https://a.example/feed" = { color = "red" }\n}), qr/unknown setting "color"/,
    'unknown setting';
  like error(qq{[blogs]\n"https://a.example/feed" = { crawler = "yes" }\n}), qr/"crawler" of .* must be a boolean/,
    'string for a boolean';
  like error(qq{[blogs]\n"https://a.example/feed" = { user_agent = false }\n}),
    qr/"user_agent" of .* must be a string/, 'boolean for a string';
  like error(qq{crawler = true\n}), qr/unknown setting "crawler" for the user/, 'feed setting at the root';
};

done_testing;
