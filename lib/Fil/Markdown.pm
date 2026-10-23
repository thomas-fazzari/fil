package Fil::Markdown;
use Mojo::Base -strict, -signatures;

use Exporter qw(import);
use Mojo::DOM;
use Mojo::Util qw(trim);

our @EXPORT_OK = qw(to_markdown);

my $BLOCKS = qr/\A(?:article|aside|div|figure|footer|header|main|section|table|tbody|thead|tr)\z/;

sub to_markdown ($html) {
  my $markdown = _blocks(Mojo::DOM->new($html)->child_nodes);
  $markdown =~ s/\n{3,}/\n\n/g;
  return trim($markdown) . "\n";
}

sub _blocks ($nodes) {
  join '', map { _block($_) } @$nodes;
}

sub _block ($node) {
  return _inline($node) unless $node->type eq 'tag';

  my $tag = $node->tag;
  return "\n\n" . ('#' x $1) . ' ' . _text($node->child_nodes) . "\n\n" if $tag =~ /\Ah([1-6])\z/;
  return "\n\n" . _text($node->child_nodes) . "\n\n"                    if $tag eq 'p' || $tag eq 'figcaption';
  return "\n\n```\n" . $node->all_text =~ s/\n+\z//r . "\n```\n\n"      if $tag eq 'pre';
  return "\n\n---\n\n"                                                  if $tag eq 'hr';
  return "\n\n" . _list($node, '') . "\n\n"                             if $tag eq 'ul' || $tag eq 'ol';
  return "\n\n" . _quote(_blocks($node->child_nodes)) . "\n\n"          if $tag eq 'blockquote';
  return _blocks($node->child_nodes)                                    if $tag =~ $BLOCKS;
  return _inline($node);
}

sub _quote ($markdown) {
  my @lines = split /\n/, trim($markdown) =~ s/\n{3,}/\n\n/gr;
  return join "\n", map { length ? "> $_" : '>' } @lines;
}

sub _list ($list, $indent) {
  my @lines;
  my $number = 0;
  for my $item ($list->children('li')->each) {
    my $marker = $list->tag eq 'ol' ? ++$number . '.' : '-';
    my @nested = $item->children('ul, ol')->each;
    my @text   = grep { !($_->type eq 'tag' && $_->tag =~ /\A[ou]l\z/) } $item->child_nodes->each;
    push @lines, "$indent$marker " . _text(\@text);
    push @lines, _list($_, "$indent  ") for @nested;
  }
  return join "\n", @lines;
}

# Inline content on one line, with <br> kept as a Markdown line break
sub _text ($nodes) {
  my $text = trim(join('', map { _inline($_) } @$nodes) =~ s/\s+/ /gr);
  return $text =~ s/ ?\x{0} ?/  \n/gr;
}

sub _inline ($node) {
  return $node->content if $node->type eq 'text' || $node->type eq 'raw';
  return '' unless $node->type eq 'tag';

  my $tag  = $node->tag;
  my $text = $tag =~ /\A(?:code|img|br)\z/ ? '' : _text($node->child_nodes);
  return "\x{0}"                                                                     if $tag eq 'br';
  return '`' . $node->all_text . '`'                                                 if $tag eq 'code';
  return '![' . ($node->attr('alt') // '') . '](' . ($node->attr('src') // '') . ')' if $tag eq 'img';
  return length $text ? "**$text**" : '' if $tag eq 'strong' || $tag eq 'b';
  return length $text ? "*$text*"   : '' if $tag eq 'em'     || $tag eq 'i';
  return "[$text](" . $node->attr('href') . ')' if $tag eq 'a' && $node->attr('href');

  # Block tags inside a list item or a link still separate words
  return $tag =~ /\A(?:div|h[1-6]|li|p)\z/ ? " $text " : $text;
}

1;
