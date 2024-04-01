package Lingua::Thesaurus;

use v5.16;
use strict;
use warnings;
use Carp;
use Encode qw(encode decode);
use Term::ReadKey;
use Term::ANSIColor;
use Unicode::Normalize;
use utf8;
use open qw(:std :encoding(UTF-8));
#use Data::Dumper;

(my $terminal_width) = GetTerminalSize();
$terminal_width = $terminal_width - 5;
$terminal_width = 20 if $terminal_width < 20;

use Lingua::StarDict2;

=head1 NAME

Thesaurus - Dictionaries on the Command Line

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This package is the backend for the thesaurus command line utility. It
interfaces with the dictionary backends (only Lingua::StarDict2 at the
time of this writing), buffers, formats and searches its output.

For usage information of the thesaurus frontend, please consult its
man page or use its build-in help: thesaurus -h;

    use Lingua::Thesaurus;

    my $dict = Lingua::Thesaurus->aperi( path => 'my/dict/folder',
                                         name => 'mydict',
                                       );
    my $results  = $dict->quaere("foo");
    for my $entry (@$results) {
       say "$entry->{dictionary} entry #$entry->{no}";
       say $entry->{lemma};
       say $entry->{corpus};
    }
    my $_ordered_entries = $dict->loopup(30..50);
    ...

Each instance of Lingua::Thesaurus corresponds to one single
dictionary (opened by the dictionary backend). To open multiple
dictionaries, create multiple objects.

=head1 METHODS

=head2 aperi

Constructor (aperi lat.: "open!"); expects a path to the directory
containing the files and the dictionaries name. In addition to this,
the following options are valid:

=over 4

=item * normalize: strip diacritics in all unicode comparisons (default 0)
=item * regexp:    all querys become perl regular expressions  (default 0)
=item * foldcase:  all querys use unicode fold case  (default 0)
=item * width      width of the output terminal (default: automatically detected
                   by the ReadKey module)
=item * entryload  number of entries to be loaded if the buffer boundaries are
                   reached (default: 20)
=item * raw:       do not process any HTML in the backend (default 0)
=item * query_raw  do not ignore HTML when searching (default 0)
=item * header     toggle header printing (default: 1)
=item * lmargin    left margin of the printed output
=item * rmargin    right margin of the printed output
=item * strict     use strict mode: searches return only full matches, but all of                    them (nonstrict mode only places the buffer at the first
                   match), deactivates loading of further contents (default 0)

=back

=cut

my %defaults = ( path => '',
		 name => '',
		 normalize => 0,
		 regexp    => 0,
		 foldcase  => 0,
		 raw       => 1,
		 width     => $terminal_width,
		 header    => 1,
		 entryload => 20,
		 query_raw => 0,
		 lmargin   => 4,
		 rmargin   => 4,
		 strict    => 0,
	       );

sub aperi {
  my $proto = shift;
  my $type = ref $proto || $proto;
  my %args; my %passed = @_;
  $args{ validate($_) } = $passed{$_} for keys %passed;
  my $self  = { %defaults, %args };
  bless $self, $type;

  $self->{dict} = Lingua::StarDict2->new
    ( path => $self->{path},
      name => $self->{name},
      normalize => 1,
      regexp    => $self->{regexp},
    );
  my $info = $self->{dict}->get_info();
  $self->{titulus} = $info->{bookname};

  return $self;
}

=head2 quaere

    $dictionary->quaere($query);

Make a new search in the dictionary (quare lat.: "search!") and put
them into an internal buffer. The behaviour of the search is
determined by the strict and regexp properties (see above). On
success, it saves the query term in the quaestio atrribute, puts the
results into an internal buffer and returns a reference to that
internal buffer; on failure, it returns nothing.

=cut

sub quaere {
  my ($self, $query) = @_;
  my $count = $self->{strict} ? undef : 1; # nonstrict gives us only the first hit
  my ($results, $nearest_hits) = $self->{dict}->search($query, $count);
  my $entries;
  if ( $self->{strict} ) { $entries = $results }
  else                   { $entries = $results ? $results : $nearest_hits  }
  $self->{quaestio} = $entries ? $query : '';
  return unless $entries;

  my $linewidth = $self->{width};
  for my $i (0..$#$entries) {
    my $entry = $entries->[$i];
    my $title = $self->format_title( $entry->{lemma} );
    my $text  = $self->format_text ( "<t>$entry->{lemma}</t>, ".
				     "$entry->{corpus}"          );

    $self->{scripta}[$i] = ($self->{header})
      ? [ $title, split "\n", $text ]
      : [         split "\n", $text ];
    $self->{start}    = $self->{end}    = [0,1];
    $self->{start_no} = $self->{end_no} = $entry->{no};
  }
  return $self->{scripta};
}

=head2 erade

    $dictionary->erade();

Clear the internal buffer (erade lat.: erase)

=cut


sub erade {
  my $self = shift;
  $self->{scripta} = $self->{start} = $self->{end} = $self->{quaestio} = undef;
}

=head2 exscribe

    $dictionary->exscribe();

Dump the whole of the internal buffer

=cut


sub exscribe {
  my $self = shift;
  return join("\n", @{ $self->{scripta}[ $self->{end}[0] ] }) . "\n";
}


=head2 lege_lineas

Format and print a portion of the buffer to output.

    $dictionary->lege_lineas($digit);
    $dictionary->lege_lineas($digit, $increment);

If used with one argument, it prints $digit lines starting from the
current end position; if $digit is negative, is prints $digit lines in
reverse, starting from the current start position. It then sets start
and end to the boundaries of the lines printed. If a second argument
is used, it prints $digit lines, but starting at the start position of
the last print plus $increment (thereby moving the buffer only by
$increment; thus, the one-argument call is equivalent to a two
argument call with twice the same argument).

=cut

sub lege_lineas {
  my $self       = shift;
  my $count      = shift || $self->{count} || croak "I cannot print 0 lines!\n";
  $self->{count} = $count;
  my $increment = shift || 0;

  my $out = '';
  unless ($increment) {
    # Forward movement
    if ($count > 0) {
      return if $self->{end}[0] > $#{ $self->{scripta} };
      $self->{start} = [ @{ $self->{end} } ];

      my $header = $self->{scripta}[ $self->{end}[0] ][0];
      return unless defined $header;
      my $header_length = () = $header =~ /\n/gsm;
      if (($count -= $header_length) > 0) {
	$out .= $header
      }
      else {
	$count += $header_length
      }

      # entries left in dictionary
    ENTRY: while ($count>0) {
	# entries left in buffer
	until ( $self->{end}[0] > $#{ $self->{scripta} } ) {
	  my $text = '';
	  # lines left in entry
	  until ( $self->{end}[1] > $#{ $self->{scripta}[ $self->{end}[0] ] } ) {
	    $out .= $self->{scripta}[ $self->{end}[0] ][ $self->{end}[1] ] . "\n";
	    last ENTRY unless --$count;
	    ++$self->{end}[1];
	  }
	  ++$self->{end}[0]; $self->{end}[1] = 1;
	}
	if ( ! $self->{strict} and $self->load( $self->{entryload} ) ) {
	  next ENTRY;
	}

	# $self->{end}[0] = $#{ $self->{scripta} };
	# $self->{end}[1] = $#{ $self->{scripta}[ $self->{end}[0] ] };
	last ENTRY;
      }
    }
    # Backward movement
    else {
      $self->{end} = [ @{ $self->{start} } ];

      # entries left in dictionary
    ENTRY: while ($count<0) {
	# entries left in buffer
	until ( $self->{start}[0] < 0 ) {
	  my $text = '';
	  # lines left in entry
	  until ( $self->{start}[1] < 1 ) {
	    $out = $self->{scripta}[ $self->{start}[0] ][ $self->{start}[1] ]
	      ."\n" . $out;
	    last ENTRY unless ++$count;

	    my $header = $self->{scripta}[ $self->{start}[0] ][0];
	    return unless defined $header;
	    my $header_length = () = $header =~ /\n/gsm;
	    if ($count + $header_length == 0) {
	      $out = $header . $out;
	      last ENTRY;
	    }

	    --$self->{start}[1];
	  }
	  --$self->{start}[0];
	  $self->{start}[1] = $#{ $self->{scripta}[ $self->{start}[0] ] }
	    unless $self->{start}[0] < 0;
	}
	if ( ! $self->{strict} and
	     my $new_entries = $self->load( -$self->{entryload} )
	   ) {
	  $self->{start}[0] += $new_entries + 1;
	  $self->{end}[0]   += $new_entries + 1;
	  next ENTRY;
	}

	$self->{start}[0] = 0;
	$self->{start}[1] = 1;
	$out = $self->lege_lineas(-$self->{count});
	last ENTRY;
      }
    }
    $self->{out} = $out;
  }
  else {
    $count = ($count > 0) ? $count : -$count;
    if ($increment>0) {
      $self->{end} = [ @{ $self->{start} } ];
      $self->lege_lineas( $increment + 1);
      $out = $self->lege_lineas( $count );
    }
    else {
      $self->{end} = [ @{ $self->{start} } ];
      $self->lege_lineas( $increment - 1);
      $self->{end} = [ @{ $self->{start} } ];
      $out = $self->lege_lineas( $count );
    }
  }

  return $out;
}

=head2 idem


    $dictionary->idem($lines);

Print $digit lines, but start at the position of the last print
(effective for refreshing the screen)

=cut


sub idem {
  my $self = shift;
  my $count = shift || $self->{count} || croak "I cannot print 0 lines!\n";
  $self->{count} = $count;

  if ($count>0) {  $self->{end} = [ @{ $self->{start} } ]  }
  else          {  $self->{start} = [ @{ $self->{end} } ]  }

  return $self->lege_lineas($count);
}

=head2 proximum

    $dictionary->proximum($count, $lines);

Print $lines lines, but move $count entries before doing so

=cut


sub proximum {
  my $self = shift;
  my $count = shift || 0;
  my $lines = shift || $self->{count} || croak "I cannot print 0 lines!\n";
  $self->{count} = $lines;
  $lines = ($lines>0) ? $lines : -$lines;

  $self->{end} = [ @{ $self->{start} } ];
  $self->{end}[0] += $count;
  $self->{end}[1] = 1;

  return $self->lege_lineas( $lines );
}

=head2 quaere_lineas

    $dictionary->quaere_lineas($query);
    $dictionary->quaere_lineas($query, $regexp);

search for $query in the last printed lines, return their indices. An
additional argument which is not 0 or '' turns the query into a
regular expression.

=cut


sub quaere_lineas {
  my $self      = shift;
  my $query     = shift;
  my $regexp    = shift || 0;

  $query = strip_diacritics($query);# if $self->{normalize};
  $query = fc $query;#                if $self->{foldcase};
  if ($regexp) {
    $query = eval { $query = qr/$query/ } ? qr/$query/ : qr/\Q$query\E/;
  }
  else {
    $query = qr/\Q$query\E/;
  }

  # search screen buffer
  my @indices;
  my @lines = split "\n", $self->{out};
  for my $i (0..$#lines) {
    $lines[$i] = strip_diacritics($lines[$i]);# if $self->{normalize};
    $lines[$i] = fc $lines[$i];#                if $self->{foldcase};
    $lines[$i] =~ s#</?[ibt]>##g          unless $self->{query_raw};
    while ($lines[$i] =~ /$query/g) {
      push @indices, [ $i, $-[0], $+[0] ];
    }
  }
  return @indices;
}

=head2 quaestio

=head2 initium

=head2 finis

These are the getters and setters for the quaestio (last successful
query), initum (begin of last print) and finis (end of last print)
attributes.

     my $last_query = $dictionary->quaestio():
     $dictionary->quaestio('');

     my $start = $dictionary->initium();
     $dictionary->initium([0,1]);
     my $end = $dictionary->fins();
     $dictionary->finis([3,12]);

=cut

sub quaestio {
  my $self = shift;
  my $arg = shift || return $self->{quaestio};
  $self->{quaestio} = $arg;
  
}

sub initium {
  my $self  = shift;
  my $entry = shift || return @{ $self->{start} };
  my $line  = shift || 1;
  $self->{start} = [ $entry, $line ];
}

sub finis {
  my $self  = shift;
  my $entry = shift || return @{ $self->{end} };
  my $line  = shift || 1;
  $self->{end} = [ $entry, $line ];
}

=head2 stricte

=head2 regexp

The setters and getters for the strict and regexp properties

=cut

sub stricte {
  my $self = shift;
  my $arg = shift // return $self->{regexp};
  $self->{strict} = $arg;
}

sub regexp {
  my $self = shift ;
  my $arg  = shift // return $self->{regexp};
  $self->{dict}->regexp($arg);
  $self->{regexp} = $arg;
}

#--------------------------------------------------
# PRIVATE METHODS
#--------------------------------------------------

sub validate {
  my $key = shift;
  $key =~ s/-?(\w+)/\L$1/;
  return $key if exists $defaults{$key};
  croak ("Configuration error in parameter: $key\n");
}

sub load {
  my $self  = shift;
  my $count = shift || return;
  my @numbers = ($count > 0)
    ? $self->{end_no}   + 1      .. $self->{end_no}   + $count
    : $self->{start_no} + $count .. $self->{start_no} - 1;
  my ($results, $nearest_hits) = $self->{dict}->lookup(@numbers);
  my $entries;
  if ( $self->{strict} ) { $entries = $results }
  else                   { $entries = $results ? $results : $nearest_hits  }
  return unless $entries;

  my @scripta;
  for my $entry ( @$entries ) {
    my $title = $self->format_title( $entry->{lemma} );
    my $text  = $self->format_text ( "<t>$entry->{lemma}</t>, $entry->{corpus}" );
    my $scriptum = ($self->{header})
      ? [ $title, split "\n", $text ]
      : [         split "\n", $text ];
    push @scripta, $scriptum;
  }

  if ($count > 0) {
    push @{ $self->{scripta} }, @scripta;
    $self->{end_no}   = $entries->[-1]{no};
  }
  else {
    unshift @{ $self->{scripta} }, @scripta;
    $self->{start_no} = $entries->[0]{no};
  }

  return scalar @$entries;
}

sub format_title {
  my $self  = shift;
  my $lemma = shift;
  my $separator =
    ($self->{strict})
    ? ( $self->{regexp} ? '=' : '-' )
    : ( $self->{regexp} ? '≈' : '~' );
  $lemma = "<t>$lemma</t>";
  my $linewidth = $self->{width};

  my $titulus = $self->{titulus} ? "<t>$self->{titulus}</t>" : '';
  my $title = '';
  $title .= $separator x $linewidth      . "\n";
  $title .= center($titulus, $linewidth) . "\n"
    if $titulus;
  $title .= center($lemma, $linewidth) . "\n";
  $title .= $separator x $linewidth    . "\n\n";

  return $title;
}

sub format_text {
  my $self = shift;
  my $text = shift;
  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;
  $text =~ s/&quot;/'/g;
  $text =~ s/&amp;/&/g;

  $text = typeset( $text,
		   $self->{width} - $self->{rmargin},
		   $self->{lmargin}
		 );
  unless ($self->{raw}) {
    $text =~ s#<t>(.*?)</t>#colored($1, 'bold yellow' )#sge;
    $text =~ s#<b>(.*?)</b>#colored($1, 'bold red' )#sge;
    $text =~ s#<i>(.*?)</i>#colored($1, 'bold green')#sge;
  }
  $text .= "\n\n";

  return $text;
}

sub center {
  my $string    = shift;
  my $linewidth = shift;
  if ( length($string) > $linewidth ) {
    $string = substr( $string, 0, $linewidth - 3 ) . '...';
  }
  my $padding   = $linewidth / 2 - length($string) / 2;
  return ' 'x$padding . $string;
}

sub typeset {
  my $string    = shift;
  my $linewidth = shift;
  my $indent    = shift || 0;
  my @lines;
  my $line = ' ' x $indent;
  my $filled = 0;
  $string =~ s#(</?br>)# $1 #g;
  my @words = split ' ', $string;
  for my $word (@words) {
    if ($word =~ m#</?br>#) {
       push @lines, $line;
      $line = ' ' x (2 * $indent);
      next;
    }

    my $line_length = length $line;
    $line_length -= length($1) while $line  =~ m#(</?[bit]>|
						 </?font.*?>)#gsx;

    if ( $line_length + length($word) <= $linewidth ) {
      $line .= "$word ";
    }
    else {
      chop $line;
      push @lines, $line;
      $line = ' ' x $indent . "$word ";
    }
  }
  return join "\n", @lines, $line;
}

sub strip_diacritics {
  my $decomposed = NFKD $_[0];
  $decomposed =~ s/\p{NonspacingMark}//gr;
}

sub numerically { $a <=> $b }



=head1 AUTHOR

Michael Neidhart, C<< <mayhoth at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-thesaurus at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Thesaurus>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.
    perldoc Thesaurus


Check also the README.md file that comes with this distribution.


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2024 by Michael Neidhart.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007


=cut

1; # End of Lingua::Thesaurus
