package Fil::Command::plan;
use Mojo::Base 'Mojolicious::Command', -signatures;

use Fil::Feeds qw(load_feeds);
use Fil::Sync  qw(current_state describe plan_changes);

has description => 'Show the changes apply would make to Miniflux';
has usage       => sub ($self) { $self->extract_usage };

sub run ($self, $file = $ENV{FIL_FEEDS}) {
  die "Pass the feeds file, or set FIL_FEEDS\n" unless $file;
  binmode STDOUT, ':encoding(UTF-8)';
  my $changes = plan_changes(load_feeds($file), current_state($self->app->miniflux));
  return say 'Miniflux matches the feeds file.' unless @$changes;
  say describe($_) for @$changes;
}

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: APPLICATION plan [FILE]

    ./script/fil.pl plan
    ./script/fil.pl plan ../feeds.toml

  FILE defaults to the FIL_FEEDS environment variable.

=cut
