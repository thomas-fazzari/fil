#!/usr/bin/env perl
use v5.36;
use JSON::PP qw(decode_json);

local $ENV{PATH} = join ':', "$ENV{HOME}/.local/share/mise/shims", '/opt/homebrew/bin', $ENV{PATH};

my $input    = decode_json(do { local $/; <> });
my $response = ref $input->{tool_response} eq 'HASH' ? $input->{tool_response} : {};
my @files = grep { defined && -f } $input->{tool_input}{file_path}, ($response->{bashEditDiff}{changedFiles} // [])->@*;

chdir $ENV{CLAUDE_PROJECT_DIR} or exit 0;
for my $file (@files) {
  if ($file =~ /\.(?:pl|pm|t)$/) {
    system 'mise', 'exec', '--', 'perltidy', '--profile=.perltidyrc', '-b', '-bext=/', $file;
  }
  elsif ($file =~ /\.(?:md|json|jsonc|ya?ml|toml|css|m?js)$/) {
    system 'bunx', '--bun', 'oxfmt', '--write', '--no-error-on-unmatched-pattern', $file;
  }
}
