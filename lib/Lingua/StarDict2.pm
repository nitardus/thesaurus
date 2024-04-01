package Lingua::StarDict2;

use v5.16;
use strict;
use warnings;
use Carp;
# use Data::Dumper;
use Encode qw(encode decode);
use utf8;
use Unicode::Normalize;
use open qw(:std :encoding(UTF-8));


=head1 NAME

Lingua::StarDict2

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This module is a pure perl interface to the StarDict Dictionary
format. It has been developed as backend for the thesaurus command
line utility and is still in early development.

    use Lingua::StarDict2;

    my $dict = Lingua::StarDict2->new();
    my ($results, $nearest_hits)  = $dict->search("foo");
    for my $entry (@results) {
       say "$entry->{dictionary} entry #$entry->{no}";
       say $entry->{lemma};
       say $entry->{corpus};
    }

    my $entries = $dict->loopup(30..50);

As of now, it only works with uncompressed StarDict dictionaries
(contained a .ifo, a .idx and a .dict file, which must be in the same
directory).


 METHODS

=head2 new(name => $name, path => $path, ...)

Connect to one Stardict dictionary with name $name and found in $path.
It supports the following boolean options, which influence the
matching behaviour of the search() method:

=over 4

=item * normalize:
make matching diacritics insensitive

=item * foldcase:
uses Unicode foldcase in matching

=item * regexp
treats query term as a regular expression

=back

=cut

sub new {
  my $proto = shift;
  my $type  = ref $proto || $proto;
  my $self  = { path => '',
		name => '',
		normalize => 0,
		regexp    => 0,
		foldcase  => 0,
		@_
	      };
  croak "No name specified for $type\n" unless $self->{name};
  bless $self, $type;

  croak "Unknown arguments in constructor for $proto!\n" if %$self > 5;
  $self->{ifo_file}  = File::Spec->catfile($self->{path}, $self->{name} . '.ifo');
  $self->{idx_file}  = File::Spec->catfile($self->{path}, $self->{name} . '.idx');
  $self->{dict_file} = File::Spec->catfile($self->{path}, $self->{name} . '.dict');
  die "I cannot find $self->{ifo_file}!"  unless -f $self->{ifo_file};
  die "I cannot find $self->{idx_file}!"  unless -f $self->{idx_file};
  die "I cannot find $self->{dict_file}!" unless -f $self->{dict_file};
  $self->{info}     = $self->parse_ifo();
  $self->{index}    = $self->parse_idx();
  # print Dumper $self->{info};
  # $self->{Collator} = Unicode::Collate->new( normalization => undef,
  # 					     level => 1);

  return $self;
}

=head2 Methods

=head3 normalize

=cut

sub normalize {
  my $self = shift;
  my $arg  = shift // return $self->{normalize};
  my $retval = $self->{normalize};
  $self->{normalize} = $arg;
  return $retval;
}

=head3 foldcase

=cut

sub foldcase {
  my $self = shift;
  my $arg  = shift // return $self->{foldcase};
  my $retval = $self->{foldcase};
  $self->{foldcase} = $arg;
  return $retval;
}

=head3 regex

These three functions are the setters and getters for the thress
attrubutes which influence the object's matching behaviour. When
called, then return the whichever value their attribute hab before the
call, changing it when they are given an argument.

=cut

sub regexp {
  my $self = shift;
  my $arg  = shift // return $self->{regexp};
  my $retval = $self->{regexp};
  $self->{regexp} = $arg;
  return $retval;
}


=head2 search($query)

Find all entries matching $query, returns an arrayref of hashrefs:

   [ { no     => 35,
       lemma  => 'example',
       corpus => 'a thing characteristic of its kind',
       start  => 43553, # offset in .dict file
       length => 300 # length of corpus in bytes
     },
     { ...},
   ]

=cut

sub search {
  my ($self, $query, $count) = @_;
  my ($results, $nearest_hit) = $self->search_index($query, $count);
  $results      = $self->read_dict($results)        if $results;
  $nearest_hit  = $self->read_dict([$nearest_hit])  if $nearest_hit;
  return $results, $nearest_hit;
}

=head2 lookup(@numbers)

Get the contents of all entries whose no property matches the numbers
specified in @numbers.

=cut

sub lookup {
  my ($self, @numbers) = @_;
  my $results = [];
  for my $number (@numbers) {
    last if $number > $#{ $self->{index} };
    next unless exists $self->{index}[$number];
    my $entry = $self->{index}[$number];
    push @$results, { %$entry };
  }
  return $results = $self->read_dict($results) if @$results;
  return;
}

=head2 get_info;

Get the parsed contents of the .ifo StarDict file

=cut

sub get_info {  my $self = shift; return $self->{info} }


#----------------------------------------------------------------------
# PRIVATE METHODS
#----------------------------------------------------------------------

sub parse_ifo {
  my $self = shift;
  open my $ifo_fh, '<', $self->{ifo_file}
    or die "Cannot open $self->{ifo_file}: $!\n";
  my %ifo;
  while (<$ifo_fh>) {
    chomp;
    next unless /=/;
    my ($key, $value) = split '=', $_;
    $value =~ s/\r//g;
    $ifo{$key} = $value;
  }
  return \%ifo;
}

sub parse_idx {
  my $self = shift;

  use bytes;
  open my $idx_fh, '<', $self->{idx_file}
    or die "Cannot open $self->{idx_file}: $!\n";
  binmode $idx_fh, ':raw';
  my $input;
  local $/ = "\0";
  my @entries;
  while (my $lemma = <$idx_fh>) {
    chomp $lemma;
    read $idx_fh, my $ints, 8;
    my ($start, $length) = unpack "NN", $ints;
    $lemma = decode 'UTF-8', $lemma, Encode::FB_CROAK;
    push @entries, {
		    no     => scalar @entries,
		    lemma  => $lemma,
		    start  => $start,
		    length => $length,
		   };
  }
  close $idx_fh;
  # @entries = sort { $b->{lemma} cmp $a->{lemma} } @entries;
  return \@entries;
}

sub search_index {
  use utf8;
  my ($self, $query, $count) = @_;
  my $full_match = length $query;
  my $best_match = 0;
  my $nearest_hit;
  my $counter = 0;
  $query = strip_diacritics($query) if $self->{normalize};
  $query = fc $query                if $self->{foldcase};
  $query = qr/$query/               if $self->{regexp};

  my $results;
  for my $entry (@{ $self->{index} }) {
    my $lemma = $entry->{lemma};
    $lemma =~ s/\d+//;
    $lemma = strip_diacritics($lemma) if $self->{normalize};
    $lemma = fc $lemma                if $self->{foldcase};
    my $match = $self->{regexp}
      ? $lemma =~ $query
      : $lemma eq $query;
    if ($match) {
      push @$results, { %$entry };
      undef $nearest_hit;
      $best_match = $full_match;
      last if $count and $count == ++$count;
    }

    unless ($results) {
      if ( substr($lemma, 0, $best_match + 1)
	   eq
	   substr($query, 0, $best_match + 1) ) {
	$nearest_hit = { %$entry };
	++$best_match
	  while substr($lemma, 0, $best_match + 1)
	     eq substr($query, 0, $best_match + 1);
      }
      elsif ( $best_match
	      and substr($lemma, 0, $best_match)
	       eq substr($query, 0, $best_match) ) {
	$nearest_hit = { %$entry }
	  if substr($lemma, $best_match, 1)
	  and ord(substr($lemma, $best_match, 1))
	    < ord(substr($query, 0, $best_match));
      }
    }
  }
  return $results, $nearest_hit;
}

sub read_dict {
  use bytes;
  my ($self, $results) = @_;
  open my $dict_fh, '<', $self->{dict_file}
    or die "Cannot open $self->{dict_file}: $!\n";
  binmode $dict_fh, ':raw';
  for my $result (@$results) {
    next if $result->{corpus};
    seek $dict_fh, $result->{start}, 0;
    read $dict_fh, my $corpus, $result->{length};
    $result->{corpus} = decode 'UTF-8', $corpus, Encode::FB_CROAK;
    #$result->{corpus} = $corpus;
  }
  close $dict_fh;
  return $results;
}

sub strip_diacritics {
  my $str = shift || '';
  my $decomposed = NFKD $str;
  $decomposed =~ s/\p{NonspacingMark}//gr;
}

=head1 AUTHOR

Michael Neidhart, C<< <mayhoth at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Lingua::StarDict2


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2024 by Michael Neidhart.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007


=cut

1; # End of Lingua::StarDict2
