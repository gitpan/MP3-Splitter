package MP3::Splitter;

use 5.005;
use strict;

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $verbose $lax);
@ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use MP3::Splitter ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
%EXPORT_TAGS = ( 'all' => [ qw(
	mp3split
) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw(
	
);

$VERSION = '0.01';
$lax = 0.02;		# close to 1/75 - tolerate terminations that early
$verbose = 1;

# Preloaded methods go here.

use MPEG::Audio::Frame 0.04;

sub piece_open ($$$) {
  my ($fname, $piece, $track) = @_;
  my $callback = $piece->[2] || sub {sprintf "%02d_%s", shift, shift};
  my $name = &$callback($track, $fname, $piece);
  local *OUT;
  open OUT, "> $name" or die "open `$name' for write: $!";
  binmode OUT or die;
  ($name, *OUT);		# Ouch!
}

sub mp3split {
    my $f = shift;

    local *F;
    open F, $f or die("open `$f': $!");
    binmode F;

    my $frame;
    my $trk = 0;		# Before first track

    my ($frames, $piece_frames) = (0, 0);	# frames written
    my ($tlen, $plen) = (0,0);			# total and piece time

    my $piece = shift or return; # start, duration, name-callback, finish-callback, user-data
    my $start = $piece->[0];
    my $end = $start + $piece->[1];

    my $outf;
    my $out;			# name of output file
    my $finished;
    while ( $frame = MPEG::Audio::Frame->read(\*F) or ++$finished) {
	# Check what to do with this frame
	if ( $tlen > $end or $finished ) {	# Need to end the current piece
	    die "Unexpected end of piece" unless $outf;
	    close $outf or die "Error closing `$out' for write: $!";
	    &{$piece->[3]}($f, $piece, $trk, $tlen, $plen) if $piece->[3];
	    undef $outf;
	    die "end of audio file before all the tracks written"
		if $finished and (@_ or $tlen < $end - $lax);
	    last if $finished;
	    $piece = shift or last;
	    $start = $piece->[0];
	    $end = $start + $piece->[1];
	}
	my $len = $frame->seconds;
	$tlen += $len;
	$plen += $len;
	next if $tlen < $start;	# Does not intersect the next interval

	# Need to write this piece
	unless ($outf) {
	    ($out, $outf) = piece_open($f, $piece, ++$trk);
	    $plen = $len;
	    printf STDERR (" %2d \@ %8s  %s\n", $trk, $end, $out) if $verbose;
	}
	# Copy frame data.
	print $outf $frame->asbin;
	$frames++, $piece_frames++;
    }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

MP3::Splitter - Perl extension for splitting MP3 files

=head1 SYNOPSIS

  use MP3::Splitter;
  mp3split('xx.mp3', [3, 356.25], [389, 615]);

=head1 DESCRIPTION

The first argument of mp3split() is a name of MP3 file, the remaining are
descriptions of pieces; they are array references with the start and
duration of the piece (in seconds), and 3 optional elements: the name callback,
finish callback, and arbitrary user data.  The callbacks should be function
references with signatures

  piece_name($pieceNum, $mp3name, $piece);
  do_something($mp3name, $piece, $pieceNum, $total_len, $piece_len)

$pieceNum is 1 for the first piece to write.  The default value of name
callback uses the piece names of the form "03_initial_name.mp3".

=head2 EXPORT

  mp3split

=head1 SEE ALSO

L<mp3cut>, L<Audio::FindChunks>

=head1 AUTHOR

Ilya Zakharevich, E<lt>cpan@ilyaz.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Lousely based on code of C<mp3cut> by Johan Vromans <jvromans@squirrel.nl>.

Copyright (C) 2004 by Ilya Zakharevich

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
