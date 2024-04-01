Thesaurus
=========

Thesaurus is a lightweight, curses based command line tool to read and
search dictionaries in the terminal. Its user interface resembles the
UNIX less command. At the time of this writing, it only supports
uncompressed StarDict dictionaries (using its own Lingua::StarDict2
module), but other formats will probably be supported in the future.


Installation
------------
With the exception of the Curses and Term::ReadKey modules, all
dependencies are in perl core and should be installed by default.
Install these two packages either via your system's package manager

    sudo pacman -S perl-curses perl-term-readkey         # Archlinux
    sudo apt install libcurses-perl libterm-readkey-perl # Debian

or via cpan 

	sudo cpan Term::ReadKey Curses

Then install it using the following commands:

	perl Makefile.PL
	make
	make test
	make install

Or, if you have the Build::Install module installed, run the following commands:

	perl Build.PL
	./Build
	./Build test
	./Build install


SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
man or the perldoc command.

    man thesaurus

LICENSE AND COPYRIGHT

This software is Copyright (c) 2024 by Michael Neidhart.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

