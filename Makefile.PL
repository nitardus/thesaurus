use v5.14;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs =
  (
   NAME             => 'Thesaurus',
   AUTHOR           => q{Michael Neidhart <mayhoth@gmail.com>},
   VERSION_FROM     => 'lib/Lingua/Thesaurus.pm',
   ABSTRACT_FROM    => 'lib/Lingua/Thesaurus.pm',
   LICENSE          => 'gpl_3',
   MIN_PERL_VERSION => 'v5.14',
   CONFIGURE_REQUIRES => {
			  'ExtUtils::MakeMaker' => '0',
			 },
   TEST_REQUIRES => {
		     'Test::More' => '0',
		    },
   PREREQ_PM => {
		 'Carp'               => 0,
		 'Config'             => 0,
		 'Curses'             => 0,
		 'Encode'             => 0,
		 'File::Basename'     => 0,
		 'File::Spec'         => 0,
		 'FindBin'            => 0,
		 'Term::ReadKey'      => 0,
		 'Term::ANSIColor'    => 0,
		 'Unicode::Normalize' => 0,
		},
   EXE_FILES => [ qw( script/thesaurus ) ],
   dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
   clean => { FILES => 'Thesaurus-*' },
  );

# Compatibility with old versions of ExtUtils::MakeMaker
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 }) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$build_requires} = values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
