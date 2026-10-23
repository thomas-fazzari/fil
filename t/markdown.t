use Mojo::Base -strict, -signatures;

use Test::More;
use Fil::Markdown qw(to_markdown);

is to_markdown(
  '<h2>Intro</h2><p>Some <strong>bold</strong>, <em>it</em> and <a href="https://x.y">a link</a>.<br>Next</p>'),
  "## Intro\n\nSome **bold**, *it* and [a link](https://x.y).  \nNext\n", 'headings and inline';

is to_markdown(
  '<ul><li>one</li><li>two<ul><li>nested</li></ul></li></ul><ol><li><p>first</p></li><li>second</li></ol>'),
  "- one\n- two\n  - nested\n\n1. first\n2. second\n", 'lists';

is to_markdown("<pre><code>my \$x = 1 &lt; 2;\n</code></pre><p>Use <code>a &amp; b</code></p>"),
  "```\nmy \$x = 1 < 2;\n```\n\nUse `a & b`\n", 'code';

is to_markdown('<blockquote><p>quoted</p><p>twice</p></blockquote><figure><img src="a.png" alt="A"></figure><hr>'),
  "> quoted\n>\n> twice\n\n![A](a.png)\n\n---\n", 'quotes, images and rules';

done_testing;
