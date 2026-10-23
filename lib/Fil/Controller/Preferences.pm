package Fil::Controller::Preferences;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::URL;

sub toggle_sidebar ($self) {
  $self->_remember(fil_sidebar => $self->sidebar_hidden ? '' : 'hidden');
}

sub toggle_theme ($self) {
  $self->_remember(fil_theme => $self->theme eq 'light' ? 'dark' : 'light');
}

sub _remember ($self, $name, $value) {
  $self->cookie($name => $value, {path => '/', expires => length $value ? time + 10 * 365 * 86400 : 1});

  # Back to the page that holds the button, never to another site
  my $back = Mojo::URL->new($self->req->headers->referrer // '')->path_query;
  $back = '/' unless $back =~ m{\A/(?![/\\])};
  $self->res->code(303);
  $self->redirect_to($back);
}

1;
