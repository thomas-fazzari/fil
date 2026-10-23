requires 'perl', '5.040';

requires 'Mojolicious', '== 9.51';
requires 'TOML::Tiny',  '== 0.22';

on develop => sub {
  requires 'Perl::Tidy', '== 20260826';
};
