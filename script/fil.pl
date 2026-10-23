#!/usr/bin/env perl
use Mojo::Base -strict;

use Mojo::File qw(curfile);
use lib curfile->dirname->sibling('lib')->to_string;
use Mojolicious::Commands;

Mojolicious::Commands->start_app('Fil');
