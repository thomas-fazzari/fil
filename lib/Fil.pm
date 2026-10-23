package Fil;
use Mojo::Base 'Mojolicious', -signatures;

use Fil::Miniflux;
use Fil::Sidebar qw(sidebar);
use Mojo::ByteStream;
use Mojo::URL;
use Mojo::Util qw(generate_secret trim);

has miniflux => sub { Fil::Miniflux->new };

sub startup ($self) {
  push $self->commands->namespaces->@*, 'Fil::Command';
  $self->types->type(md => 'text/markdown;charset=UTF-8');
  push $self->static->paths->@*, $self->home->child('node_modules/@hotwired/turbo/dist')->to_string;
  $self->helper(miniflux       => sub ($c) { $c->app->miniflux });
  $self->helper(sidebar        => sub ($c) { $c->stash->{'fil.sidebar'} //= sidebar($c->miniflux) });
  $self->helper(sidebar_hidden => sub ($c) { ($c->cookie('fil_sidebar') // '') eq 'hidden' });
  $self->helper(
    theme => sub ($c) {
      ($c->cookie('fil_theme') // '') eq 'light' ? 'light' : 'dark';
    }
  );

  # Filters take ids only, anything else shows the whole list
  $self->helper(
    id_param => sub ($c, $name) {
      my $value = $c->param($name) // '';
      return $value =~ /\A[0-9]+\z/ ? $value : undef;
    }
  );

  $self->helper(
    asset => sub ($c, $path) {
      my $file = $c->app->static->file($path =~ s{^/}{}r);
      return $file ? "$path?" . $file->mtime : $path;
    }
  );

  my %icons;
  $self->helper(
    icon => sub ($c, $name) {
      $icons{$name} //= do {
        my $svg = $self->home->child('icons', "$name.svg")->slurp('UTF-8');
        $svg =~ s/<!--.*?-->\s*//s;
        $svg =~ s/class="[^"]*"/class="icon" aria-hidden="true"/;
        trim($svg =~ s/\s+/ /gr);
      };
      return Mojo::ByteStream->new($icons{$name});
    }
  );

  # Miniflux serves http images from its own origin. The nonce covers the <style> of Turbo's progress bar
  $self->hook(
    before_dispatch => sub ($c) {
      my $nonce    = substr generate_secret(), 0, 32;
      my $miniflux = $c->miniflux->url;
      $c->stash(csp_nonce => $nonce);
      $c->res->headers->content_security_policy("default-src 'none'; script-src 'self'; connect-src 'self'; "
          . "style-src 'self' 'nonce-$nonce'; font-src 'self'; img-src https: data: $miniflux; media-src https: $miniflux; "
          . "frame-src https://www.youtube-nocookie.com; form-action 'self'; frame-ancestors 'none'");
    }
  );

  my $r = $self->routes;
  $r->get('/')->to('entries#list', list => 'unread')->name('unread');
  $r->get('/all')->to('entries#list', list => 'all')->name('all');
  $r->get('/bookmarks')->to('entries#list', list => 'bookmarks')->name('bookmarks');
  $r->get('/entries/<id:num>')->to('entries#show')->name('entry');
  $r->get('/entries/<id:num>/markdown')->to('entries#export')->name('export');

  my $same_origin = $r->under(sub ($c) {
    my $headers = $c->req->headers;
    my $site    = $headers->header('Sec-Fetch-Site');
    my $origin  = $headers->origin;
    my $allowed
      = defined $site   ? $site eq 'same-origin' || $site eq 'none'
      : defined $origin ? (Mojo::URL->new($origin)->host_port // '') eq ($c->req->url->to_abs->host_port // '')
      :                   1;
    return 1 if $allowed;
    $c->render(text => 'Cross-site request', status => 403);
    return undef;
  });
  $same_origin->post('/entries/<id:num>/bookmark')->to('entries#bookmark')->name('bookmark');
  $same_origin->post('/sidebar')->to('preferences#toggle_sidebar')->name('toggle_sidebar');
  $same_origin->post('/theme')->to('preferences#toggle_theme')->name('toggle_theme');
}

1;
