use Mojo::Base -strict, -signatures;

use Test::More;
use Fil;
use Fil::Feeds qw(load_feeds);
use Fil::Miniflux;
use Fil::Sync  qw(apply_changes current_state plan_changes);
use Mojo::File qw(tempfile);
use Mojo::Util qw(generate_secret);

my $admin = Fil->new->miniflux;
plan skip_all => 'Start Miniflux with mise run stack:up' unless eval { $admin->me };

# The tests run as a throwaway user, so they leave the real subscriptions alone
my $password = substr generate_secret, 0, 32;
my $user     = $admin->request(POST => '/v1/users', {username => "fil-test-$$", password => $password});
my $miniflux = Fil::Miniflux->new(url => $admin->url, username => $user->{username}, password => $password);
END { $admin->request(DELETE => "/v1/users/$user->{id}") if $user }

my $feed   = 'https://lucumr.pocoo.org/feed.atom';
my $filter = 'EntryTitle=(?i)^never matches$';

sub pending ($toml) {
  plan_changes(load_feeds(tempfile->spew($toml, 'UTF-8')), current_state($miniflux));
}

sub sync ($toml) { apply_changes($miniflux, pending($toml)) }

my $initial = qq{block_filter_entry_rules = '$filter'\n[blogs]\n"$feed" = { title = "Armin" }\n};
is_deeply sync($initial),    [], 'create';
is_deeply pending($initial), [], 'nothing left after create';
is $miniflux->feeds->[0]{category}{title},    'blogs', 'category created';
is $miniflux->feeds->[0]{title},              'Armin', 'title set after create';
is $miniflux->me->{block_filter_entry_rules}, $filter, 'user filter set';

my $changed = <<~"EOF";
  [reading."$feed"]
  crawler = true
  block_filter_entry_rules = '''
  EntryTitle=(?i)webinar
  EntryTitle=(?i)hiring
  '''
  EOF
is_deeply sync($changed),    [], 'update';
is_deeply pending($changed), [], 'nothing left after update';
my ($current) = $miniflux->feeds->@*;
ok $current->{crawler}, 'setting applied';
is $current->{category}{title},               'reading', 'category moved';
is $miniflux->me->{block_filter_entry_rules}, '',        'user filter cleared';

my $entries = $miniflux->request(GET => "/v1/feeds/$current->{id}/entries?limit=1")->{entries};
ok @$entries, 'feed fetched on create';
$miniflux->toggle_bookmark($entries->[0]{id});
like sync('')->[0], qr/bookmarked entries/, q{feed with bookmarked entries kept};
is scalar $miniflux->feeds->@*, 1, 'still subscribed';

$miniflux->toggle_bookmark($entries->[0]{id});
is_deeply sync(''),         [], 'delete';
is_deeply $miniflux->feeds, [], 'unsubscribed';

done_testing;
