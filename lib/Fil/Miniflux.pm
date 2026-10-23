package Fil::Miniflux;
use Mojo::Base -base, -signatures;

use Mojo::Parameters;
use Mojo::UserAgent;
use Mojo::Util qw(b64_encode);

# The admin that compose.yaml creates, with the same defaults
has password => sub { $ENV{MINIFLUX_PASSWORD} // 'miniflux' };
has url      => sub {
  $ENV{MINIFLUX_URL} // 'http://127.0.0.1:' . ($ENV{MINIFLUX_PORT} // 8080);
};
has username => sub { $ENV{MINIFLUX_USERNAME} // 'admin' };
has ua       => sub { Mojo::UserAgent->new(inactivity_timeout => 60) };

# Miniflux hashes the password on every basic auth call, about 50ms, so the client trades it once for an API key
has token => sub ($self) {
  my $basic = {Authorization => 'Basic ' . b64_encode(join(':', $self->username, $self->password), '')};
  my ($key) = grep { $_->{description} eq 'fil' } $self->_send(GET => '/v1/api-keys', undef, $basic)->@*;
  return ($key // $self->_send(POST => '/v1/api-keys', {description => 'fil'}, $basic))->{token};
};

sub categories ($self) { $self->request(GET => '/v1/categories') }

sub create_category ($self, $title) {
  $self->request(POST => '/v1/categories', {title => $title});
}

sub create_feed ($self, $feed) {
  $self->request(POST => '/v1/feeds', $feed);
}

sub delete_feed ($self, $id) { $self->request(DELETE => "/v1/feeds/$id") }

sub entries ($self, %query) {
  $self->request(GET => '/v1/entries?' . Mojo::Parameters->new(%query));
}

sub entry ($self, $id) { $self->request(GET => "/v1/entries/$id") }

sub fetch_content ($self, $id) {
  return $self->request(GET => "/v1/entries/$id/fetch-content?update_content=true")->{content};
}

sub counters ($self) { $self->request(GET => '/v1/feeds/counters') }

sub feeds ($self) { $self->request(GET => '/v1/feeds') }

sub mark_read ($self, @ids) {
  $self->request(PUT => '/v1/entries', {entry_ids => \@ids, status => 'read'});
}

sub me ($self) { $self->request(GET => '/v1/me') }

sub bookmark_count ($self, $feed_id) {
  return $self->request(GET => "/v1/feeds/$feed_id/entries?starred=true&limit=1")->{total};
}

sub toggle_bookmark ($self, $id) {
  $self->request(PUT => "/v1/entries/$id/bookmark");
}

sub update_feed ($self, $id, $changes) {
  $self->request(PUT => "/v1/feeds/$id", $changes);
}

sub update_user ($self, $id, $changes) {
  $self->request(PUT => "/v1/users/$id", $changes);
}

sub request ($self, $method, $path, $json = undef) {
  return $self->_send($method, $path, $json, {'X-Auth-Token' => $self->token});
}

sub _send ($self, $method, $path, $json, $headers) {
  my $tx  = $self->ua->build_tx($method => $self->url . $path => $headers => defined $json ? (json => $json) : ());
  my $res = $self->ua->start($tx)->result;
  return $res->json if $res->is_success;

  # Miniflux deletes old read entries, so links to them can go missing
  return undef if $method eq 'GET' && $res->code == 404;

  my $error = $res->json('/error_message') // $res->message;
  die sprintf "Miniflux: %s %s failed with %s %s\n", $method, $path, $res->code, $error;
}

1;
