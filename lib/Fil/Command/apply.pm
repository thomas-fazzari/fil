package Fil::Command::apply;
use Mojo::Base 'Mojolicious::Command', -signatures;

use Fil::Feeds qw(load_feeds);
use Fil::Sync  qw(apply_changes current_state describe plan_changes);

has description => 'Update Miniflux feeds and user filters to match the feeds file';
has usage       => sub ($self) { $self->extract_usage };

sub run ($self, $file = $ENV{FIL_FEEDS}) {
  die "Pass the feeds file, or set FIL_FEEDS\n" unless $file;
  binmode STDOUT, ':encoding(UTF-8)';
  my $declared = load_feeds($file);
  die "$file lists no feeds, so apply would delete them all\n" unless $declared->{feeds}->@*;

  my $miniflux = $self->app->miniflux;
  my $changes  = plan_changes($declared, current_state($miniflux));
  return say 'Miniflux matches the feeds file.' unless @$changes;

  say describe($_) for @$changes;
  my $failures = apply_changes($miniflux, $changes);
  die "\nFailed:\n", map {"  $_"} @$failures if @$failures;
}

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: APPLICATION apply [FILE]

    ./script/fil.pl apply
    ./script/fil.pl apply ../feeds.toml

  FILE defaults to the FIL_FEEDS environment variable. Apply never deletes
  a feed that has bookmarked entries.

=cut
