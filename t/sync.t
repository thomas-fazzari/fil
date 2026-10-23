use Mojo::Base -strict, -signatures;

use Test::More;
use Fil::Sync  qw(apply_changes describe plan_changes);
use Mojo::JSON qw(false true);

sub declared ($url, $category, %settings) { {url => $url, category => $category, settings => \%settings} }

sub current ($id, $url, $category, %settings) {
  return {
    id                       => $id,
    feed_url                 => $url,
    category                 => {title => $category},
    crawler                  => false,
    disabled                 => false,
    block_filter_entry_rules => '',
    user_agent               => '',
    %settings
  };
}

my %user = (id => 9, block_filter_entry_rules => '', keep_filter_entry_rules => '');

subtest 'Plan feeds' => sub {
  my $changes = plan_changes(
    {
      user  => {},
      feeds => [
        declared('https://new.example/feed',   'blogs', crawler => true),
        declared('https://same.example/feed',  'blogs'),
        declared('https://moved.example/feed', 'rust', block_filter_entry_rules => 'EntryTitle=x'),
      ]
    },
    {
      user  => \%user,
      feeds => [
        current(1, 'https://same.example/feed',  'blogs'),
        current(2, 'https://moved.example/feed', 'blogs', crawler => true),
        current(3, 'https://gone.example/feed',  'blogs'),
      ]
    }
  );

  is_deeply [map {"$_->{action} $_->{url}"} @$changes],
    ['create https://new.example/feed', 'update https://moved.example/feed', 'delete https://gone.example/feed'],
    'unchanged feeds are left out';
  is_deeply $changes->[1]{diff},
    {category => ['blogs', 'rust'], crawler => [true, false], block_filter_entry_rules => ['', 'EntryTitle=x']},
    'undeclared settings go back to their default';
  is $changes->[2]{id}, 3, 'delete keeps the Miniflux id';
};

subtest 'Plan titles' => sub {
  my $current = {user => \%user, feeds => [current(1, 'https://a.example/feed', 'blogs', title => 'A: Newest')]};

  is_deeply plan_changes({user => {}, feeds => [declared('https://a.example/feed', 'blogs')]}, $current), [],
    'feed title kept when undeclared';
  is_deeply plan_changes({user => {}, feeds => [declared('https://a.example/feed', 'blogs', title => 'A')]}, $current)
    ->[0]{diff}, {title => ['A: Newest', 'A']}, 'declared title replaces it';
};

subtest 'Plan categories' => sub {
  my $current = {user => \%user, feeds => [current(1, 'https://a.example/feed', 'blogs')]};
  is_deeply plan_changes({user => {}, feeds => [declared('https://a.example/feed', 'Blogs')]}, $current), [],
    'Miniflux ignores case in category titles';
};

subtest 'Plan user settings' => sub {
  my $changes = plan_changes(
    {user => {block_filter_entry_rules       => 'EntryDate=max-age:30d'}, feeds => []},
    {user => {%user, keep_filter_entry_rules => 'EntryTitle=x'},          feeds => []}
  );

  is_deeply $changes,
    [{
    action => 'user',
    id     => 9,
    diff => {block_filter_entry_rules => ['', 'EntryDate=max-age:30d'], keep_filter_entry_rules => ['EntryTitle=x', '']}
    }],
    'declared filters set, others cleared';
};

subtest 'Describe' => sub {
  is describe({action => 'create', url => 'https://a.example/feed', category => 'blogs'}),
    '+ https://a.example/feed (blogs)', 'create';
  is describe({action => 'delete', url => 'https://a.example/feed'}), '- https://a.example/feed', 'delete';
  is describe({action => 'update', url => 'https://a.example/feed', diff => {crawler => [false, true]}}),
    "~ https://a.example/feed\n    crawler: false -> true", 'update';
  is describe({action => 'user', id => 9, diff => {block_filter_entry_rules => ['', 'x']}}),
    qq{~ user settings\n    block_filter_entry_rules: "" -> "x"}, 'user settings';
};

package FakeMiniflux {
  use Mojo::Base -base, -signatures;

  has calls      => sub { [] };
  has bookmarked => 0;
  has failing    => '';

  sub categories ($self) { [{id => 1, title => 'blogs'}] }

  sub create_category ($self, $title) {
    push $self->calls->@*, ['create_category', $title];
    return {id => 2, title => $title};
  }

  sub create_feed ($self, $feed) {
    die "unreachable\n" if $feed->{feed_url} eq $self->failing;
    push $self->calls->@*, ['create_feed', $feed];
    return {feed_id => 4};
  }

  sub delete_feed    ($self, $id)           { push $self->calls->@*, ['delete_feed', $id] }
  sub bookmark_count ($self, $id)           { $self->bookmarked }
  sub update_feed    ($self, $id, $request) { push $self->calls->@*, ['update_feed', $id, $request] }
  sub update_user    ($self, $id, $request) { push $self->calls->@*, ['update_user', $id, $request] }
}

subtest 'Apply' => sub {
  my $miniflux = FakeMiniflux->new;
  my $failures = apply_changes(
    $miniflux,
    [
      {action => 'user', id => 9, diff => {block_filter_entry_rules => ['', 'EntryDate=max-age:30d']}},
      {
        action   => 'create',
        url      => 'https://a.example/feed',
        category => 'rust',
        settings => {crawler => true, title => 'A'}
      },
      {action => 'update', id => 5, url => 'https://b.example/feed', diff => {category => ['rust',  'Blogs']}},
      {action => 'update', id => 7, url => 'https://d.example/feed', diff => {category => ['blogs', 'Rust']}},
      {action => 'delete', id => 6, url => 'https://c.example/feed'},
    ]
  );

  is_deeply $failures, [], 'no failures';
  is_deeply $miniflux->calls,
    [
    ['update_user',     9, {block_filter_entry_rules => 'EntryDate=max-age:30d'}],
    ['create_category', 'rust'],
    ['create_feed',     {feed_url => 'https://a.example/feed', category_id => 2, crawler => true}],
    ['update_feed',     4, {feed_url    => 'https://a.example/feed', title => 'A'}],
    ['update_feed',     5, {category_id => 1}],
    ['update_feed',     7, {category_id => 2}],
    ['delete_feed',     6],
    ],
    'missing category created once, title set after create';

  $miniflux = FakeMiniflux->new(failing => 'https://a.example/feed');
  $failures = apply_changes(
    $miniflux,
    [
      {action => 'create', url => 'https://a.example/feed', category => 'blogs', settings => {}},
      {action => 'delete', id  => 6, url => 'https://c.example/feed'},
    ]
  );
  is_deeply $failures,        ["create https://a.example/feed: unreachable\n"], 'API error reported';
  is_deeply $miniflux->calls, [['delete_feed', 6]],                             'next change still applied';

  $miniflux = FakeMiniflux->new(bookmarked => 1);
  $failures = apply_changes($miniflux, [{action => 'delete', id => 6, url => 'https://c.example/feed'}]);
  like $failures->[0], qr/^delete https:\/\/c.example\/feed: it has bookmarked entries/, q{bookmarked feed kept};
  is_deeply $miniflux->calls, [], 'nothing deleted';
};

done_testing;
