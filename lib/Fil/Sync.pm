package Fil::Sync;
use Mojo::Base -strict, -signatures;
use feature 'try';

use Exporter   qw(import);
use Fil::Feeds qw(%SETTINGS %USER_SETTINGS);
use Mojo::JSON qw(false to_json);

our @EXPORT_OK = qw(apply_changes current_state describe plan_changes);

sub current_state ($miniflux) { {feeds => $miniflux->feeds, user => $miniflux->me} }

sub plan_changes ($declared, $current) {
  my @changes;
  my $user = _diff(\%USER_SETTINGS, $current->{user}, $declared->{user});
  push @changes, {action => 'user', id => $current->{user}{id}, diff => $user} if %$user;

  my %current  = map { $_->{feed_url} => $_ } $current->{feeds}->@*;
  my %declared = map { $_->{url}      => $_ } $declared->{feeds}->@*;
  for my $feed ($declared->{feeds}->@*) {
    my $existing = $current{$feed->{url}};
    unless ($existing) {
      push @changes, {action => 'create', %$feed};
      next;
    }

    my $diff     = _diff(\%SETTINGS, $existing, $feed->{settings});
    my $category = $existing->{category}{title} // '';
    $diff->{category} = [$category, $feed->{category}] if fc $category ne fc $feed->{category};
    push @changes, {action => 'update', id => $existing->{id}, url => $feed->{url}, diff => $diff} if %$diff;
  }

  for my $feed (sort { $a->{feed_url} cmp $b->{feed_url} } $current->{feeds}->@*) {
    push @changes, {action => 'delete', id => $feed->{id}, url => $feed->{feed_url}}
      unless $declared{$feed->{feed_url}};
  }

  return \@changes;
}

sub apply_changes ($miniflux, $changes) {

  # Miniflux compares category titles ignoring case
  my %categories = map { fc $_->{title} => $_->{id} } $miniflux->categories->@*;
  my sub category_id ($title) { $categories{fc $title} //= $miniflux->create_category($title)->{id} }

  my @failures;
  for my $change (@$changes) {
    my $action = $change->{action};
    try {
      if    ($action eq 'user') { $miniflux->update_user($change->{id}, _targets($change)) }
      elsif ($action eq 'create') {
        my %settings = $change->{settings}->%*;
        my $title    = delete $settings{title};
        my $feed     = {feed_url => $change->{url}, category_id => category_id($change->{category}), %settings};
        my $feed_id  = $miniflux->create_feed($feed)->{feed_id};

        # Miniflux stores the URL a redirect lands on, and the creation request has no title field
        $miniflux->update_feed($feed_id, {feed_url => $change->{url}, defined $title ? (title => $title) : ()});
      }
      elsif ($action eq 'update') {
        my $request = _targets($change);
        $request->{category_id} = category_id(delete $request->{category}) if exists $request->{category};
        $miniflux->update_feed($change->{id}, $request);
      }
      else {
        die "it has bookmarked entries. Remove the bookmarks, or list it again with disabled = true\n"
          if $miniflux->bookmark_count($change->{id});
        $miniflux->delete_feed($change->{id});
      }
    }
    catch ($error) { push @failures, "$action " . _subject($change) . ": $error" }
  }

  return \@failures;
}

sub describe ($change) {
  my $action = $change->{action};
  return "+ $change->{url} ($change->{category})" if $action eq 'create';
  return "- $change->{url}"                       if $action eq 'delete';

  my $diff = $change->{diff};
  return join "\n", '~ ' . _subject($change), map {
    sprintf '    %s: %s -> %s', $_,
      map { to_json $_ }
      $diff->{$_}->@*
  } sort keys %$diff;
}

# A setting the file leaves out goes back to its default
sub _diff ($known, $current, $declared) {
  my %diff;
  for my $name (sort keys %$known) {

    # Miniflux takes the title from the feed, so only a declared title replaces it
    next if $name eq 'title' && !defined $declared->{title};

    my $type = $known->{$name};
    my $from = $current->{$name};
    my $to   = $declared->{$name} // ($type eq 'boolean' ? false : '');
    my $same = $type eq 'boolean' ? !!$from == !!$to : ($from // '') eq $to;
    $diff{$name} = [$from, $to] unless $same;
  }
  return \%diff;
}

sub _subject ($change) { $change->{url} // 'user settings' }

sub _targets ($change) {
  return {map { $_ => $change->{diff}{$_}[1] } keys $change->{diff}->%*};
}

1;
