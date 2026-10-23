package Fil::Sidebar;
use Mojo::Base -strict, -signatures;

use Exporter   qw(import);
use List::Util qw(sum0);

our @EXPORT_OK = qw(sidebar);

sub sidebar ($miniflux) {
  my $unreads = $miniflux->counters->{unreads};

  my %categories;
  for my $feed ($miniflux->feeds->@*) {
    my ($id, $title) = $feed->{category}->@{qw(id title)};
    my $category = $categories{$id} //= {id => $id, title => $title, feeds => []};
    push $category->{feeds}->@*, {id => $feed->{id}, title => $feed->{title}, unread => $unreads->{$feed->{id}} // 0};
  }

  for my $category (values %categories) {
    $category->{feeds}->@* = sort { fc $a->{title} cmp fc $b->{title} } $category->{feeds}->@*;
    $category->{unread} = sum0 map { $_->{unread} } $category->{feeds}->@*;
  }

  return [sort { fc $a->{title} cmp fc $b->{title} } values %categories];
}

1;
