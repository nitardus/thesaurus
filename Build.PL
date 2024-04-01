use v5.14;
use strict;
use warnings;
use Module::Build;
Module::Build->VERSION('0.4004');

my $builder = Module::Build->new
  (
   module_name         => 'Lingua::Thesaurus',
   license             => 'GPL_3',
   create_license      => 1,
   dist_author         => q{Michael Neidhart <mayhoth@gmail.com>},
   dist_version_from   => 'lib/Lingua/Thesaurus.pm',
   script_files        => 'script/thesaurus',
   release_status      => 'stable',
   configure_requires => {
			  'Module::Build' => '0.4004',
			 },
   test_requires => {
		     'Test::More' => '0',
		    },
   requires => {
		'Carp'               => 0,
		'Config'             => 0,
		'Curses'             => 0,
		'Encode'             => 0,
		'File::Basename'     => 0,
		'File::Spec'         => 0,
		'Term::ReadKey'      => 0,
		'Term::ANSIColor'    => 0,
		'Unicode::Normalize' => 0,
	       },
   add_to_cleanup     => [ 'Thesaurus-*' ],
);

$builder->create_build_script();
