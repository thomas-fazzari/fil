package Fil::Feeds;
use Mojo::Base -strict, -signatures;

use Exporter   qw(import);
use JSON::PP   ();
use Mojo::File qw(path);
use Mojo::JSON qw(false true);
use TOML::Tiny qw(from_toml);

our @EXPORT_OK = qw(load_feeds %SETTINGS %USER_SETTINGS);

our %SETTINGS = (
  allow_self_signed_certificates => 'boolean',
  block_filter_entry_rules       => 'string',
  blocklist_rules                => 'string',
  crawler                        => 'boolean',
  disable_http2                  => 'boolean',
  disabled                       => 'boolean',
  fetch_via_proxy                => 'boolean',
  hide_globally                  => 'boolean',
  ignore_entry_updates           => 'boolean',
  ignore_http_cache              => 'boolean',
  keep_filter_entry_rules        => 'string',
  keeplist_rules                 => 'string',
  no_media_player                => 'boolean',
  rewrite_rules                  => 'string',
  scraper_rules                  => 'string',
  title                          => 'string',
  urlrewrite_rules               => 'string',
  user_agent                     => 'string',
);

# User filters, declared as root keys of the feeds file
our %USER_SETTINGS = (block_filter_entry_rules => 'string', keep_filter_entry_rules => 'string');

sub load_feeds ($file) {
  my ($data, $error)
    = from_toml(path($file)->slurp('UTF-8'), inflate_boolean => sub ($value) { $value eq 'true' ? true : false });
  die "$file: $error\n" if $error;

  my (@feeds, %seen, %user);
  for my $key (sort keys %$data) {
    my $feeds = $data->{$key};
    if (ref $feeds ne 'HASH') {
      $user{$key} = $feeds;
      next;
    }

    for my $url (sort keys %$feeds) {
      die qq{$file: "$url" is not an HTTP URL\n} unless $url =~ m{^https?://};
      die qq{$file: "$url" is in both "$seen{$url}" and "$key"\n} if $seen{$url};
      $seen{$url} = $key;
      push @feeds,
        {category => $key, url => $url, settings => _settings($file, qq{"$url"}, $feeds->{$url}, \%SETTINGS)};
    }
  }

  return {feeds => \@feeds, user => _settings($file, 'the user', \%user, \%USER_SETTINGS)};
}

sub _settings ($file, $owner, $settings, $known) {
  die qq{$file: settings of $owner must be a table\n} unless ref $settings eq 'HASH';

  my %settings;
  for my $name (sort keys %$settings) {
    my $type  = $known->{$name} or die qq{$file: unknown setting "$name" for $owner\n};
    my $value = $settings->{$name};
    my $valid = $type eq 'boolean' ? JSON::PP::is_bool($value) : !ref $value;
    die qq{$file: "$name" of $owner must be a $type\n} unless $valid;

    # Multiline strings keep their last line break, which Miniflux drops
    $value =~ s/\s+\z// if $type eq 'string';
    $settings{$name} = $value;
  }

  return \%settings;
}

1;
