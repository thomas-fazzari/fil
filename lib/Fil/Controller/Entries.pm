package Fil::Controller::Entries;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Fil::Markdown qw(to_markdown);
use Mojo::DOM;

my @MONTHS = qw(January February March April May June July August September October November December);

my %LISTS = (
  unread    => {title => 'Unread',    empty => 'Nothing unread.',   query => {status  => 'unread'}},
  all       => {title => 'All',       empty => 'Nothing yet.',      query => {status  => ['unread', 'read']}},
  bookmarks => {title => 'Bookmarks', empty => 'No bookmarks yet.', query => {starred => 'true'}},
);

sub bookmark ($self) {
  my $id = $self->param('id');
  $self->miniflux->toggle_bookmark($id);

  # Turbo expects a 303 after a form submission
  $self->res->code(303);
  $self->redirect_to($self->url_with(entry => id => $id));
}

sub list ($self) {
  my $list     = $LISTS{$self->stash('list')};
  my $search   = $self->param('q') // '';
  my $category = $self->id_param('category');
  my $feed     = $self->id_param('feed');

  my %query = ($list->{query}->%*, order => 'published_at', direction => 'desc', limit => 100);
  $query{search}           = $search   if length $search;
  $query{category_id}      = $category if $category;
  $query{feed_id}          = $feed     if $feed;
  $query{globally_visible} = 'true' unless $category || $feed;

  my $entries = $self->miniflux->entries(%query)->{entries};
  $entries = $self->_with_matching_feeds($entries, %query) if length $search && !$feed;

  $self->render(
    groups => _by_month($entries),
    title  => $list->{title},
    empty  => length $search ? 'No results.' : $list->{empty}
  );
}

# Miniflux searches titles and content only,
sub _with_matching_feeds ($self, $entries, %query) {
  my $search = fc delete $query{search};
  my @groups = grep { !$query{category_id} || $_->{id} == $query{category_id} } $self->sidebar->@*;
  my @feeds  = grep { index(fc $_->{title}, $search) >= 0 } map { $_->{feeds}->@* } @groups;

  my @all  = @$entries;
  my %seen = map { $_->{id} => 1 } @all;
  for my $feed (@feeds) {
    for my $entry ($self->miniflux->entries(%query, feed_id => $feed->{id})->{entries}->@*) {
      push @all, $entry unless $seen{$entry->{id}}++;
    }
  }

  @all = sort { $b->{published_at} cmp $a->{published_at} } @all;
  splice @all, $query{limit} if @all > $query{limit};
  return \@all;
}

sub show ($self) {
  my $miniflux = $self->miniflux;
  my $entry    = $miniflux->entry($self->param('id')) or return $self->reply->not_found;
  my $unread   = $entry->{status} eq 'unread';
  $miniflux->mark_read($entry->{id}) if $unread;

  # Some feeds only send a link, so Miniflux fetches the page on the first visit and keeps its text
  my $content = _without_title($entry, $entry->{content});
  if ($unread && _empty($content)) {
    my $fetched = eval { $miniflux->fetch_content($entry->{id}) };
    $self->log->warn($@ =~ s/\n\z//r)           if $@;
    $content = _without_title($entry, $fetched) if defined $fetched;
  }

  $self->render(entry => $entry, content => _empty($content) ? '' : $content, date => _long_date($entry));
}

sub export ($self) {
  my $entry = $self->miniflux->entry($self->param('id')) or return $self->reply->not_found;
  my $name  = substr(lc($entry->{title}) =~ s/[^a-z0-9]+/-/gr =~ s/\A-|-\z//gr, 0, 80) || "entry-$entry->{id}";

  my $markdown = join "\n\n", "# $entry->{title}", "[$entry->{feed}{title}]($entry->{url}) · " . _long_date($entry),
    to_markdown(_without_title($entry, $entry->{content}));
  $self->res->headers->content_disposition(qq{attachment; filename="$name.md"});
  $self->render(text => $markdown, format => 'md');
}

sub _by_month ($entries) {
  my $this_year = (localtime)[5] + 1900;

  my (@groups, %groups);
  for my $entry (@$entries) {
    my ($year, $month, $day) = _date($entry);
    my $group = $groups{"$year-$month"} //= do {
      my $label = $MONTHS[$month - 1] . ($year == $this_year ? '' : " $year");
      push @groups, {label => $label, entries => []};
      $groups[-1];
    };
    push $group->{entries}->@*, {%$entry, day => $day};
  }

  return \@groups;
}

sub _long_date ($entry) {
  my ($year, $month, $day) = _date($entry);
  return "$day $MONTHS[$month - 1] $year";
}

sub _date ($entry) {
  my ($year, $month, $day) = $entry->{published_at} =~ /^(\d{4})-(\d{2})-(\d{2})/;
  return ($year, $month + 0, $day + 0);
}

sub _without_title ($entry, $html) {
  my $dom   = Mojo::DOM->new($html);
  my $title = _words($entry->{title});
  my $first = $dom->at('h1, h2, h3, h4, p');
  $first->remove if length $title && $first && _words($first->all_text) eq $title;
  return $dom->to_string;
}

sub _empty ($html) {
  my $dom = Mojo::DOM->new($html // '');
  return 0 if $dom->at('iframe, img, pre, video');

  # Link aggregators send nothing but a link to the discussion
  $dom->find('a')->map('remove');
  return $dom->all_text !~ /\S/;
}

sub _words ($text) { fc($text) =~ s/[^\p{L}\p{N}]+//gr }

1;
