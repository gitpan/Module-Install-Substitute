package Module::Install::Substitute;

use vars qw(@ISA);
use Module::Install::Base; @ISA = qw(Module::Install::Base);

use strict;
use warnings;

$Module::Install::Substitute::VERSION = '0.02';

require File::Temp;
require File::Spec;
require Cwd;

=head1 NAME

  Module::Install::Substitute - substitute values into files before install

=head1 SYNOPSIS

  use inc::Module::Install;

  ...
  substitute(
    {
      LESS => '/usr/bin/less',
      APXS => '/usr/bin/apxs2',
    },
    'bin/my-app'
  );

=head1 DESCRIPTION

This is extension for L<Module::Install> system that allow you to substitute
values into files before install, for example paths to libs or binary executables.

=head1 METHODS

=head2 substitute SUBSTITUTIONS [OPTIONS] FILES

Takes has reference with substituations key value pairs, optional
options hash reference and list of files to deal with.

Several options are available:

=over 3

=item sufix

Sufix for source files, for example you can use sufix C<.in> and results of
processing of F<Makefile.in> would be writen into file F<Makefile>. Note
that you don't need to specify sufixes in the list of files.

=item from

Source base dir.

=item to

Destination base dir.

=back

=cut

sub substitute
{
	my $self = shift;
	$self->{__subst} = shift;
	$self->{__option} = {};
	if( UNIVERSAL::isa( $_[0], 'HASH' ) ) {
		my $opts = shift;
		while( my ($k,$v) = each( %$opts ) ) {
			$self->{__option}->{ lc( $k ) } = $v || '';
		}
	}
	$self->_parse_options;

	my @file = @_;
	foreach my $f (@file) {
		$self->_rewrite_file( $f );
	}

	return;
}

sub _parse_options
{
	my $self = shift;
	my $cwd = Cwd::getcwd();
	foreach my $t ( qw(from to) ) {
        $self->{__option}->{$t} = $cwd unless $self->{__option}->{$t};
		my $d = $self->{__option}->{$t};
		die "Couldn't read directory '$d'" unless -d $d && -r _;
	}
}

sub _rewrite_file
{
	my ($self, $file) = @_;
	my $source = File::Spec->catfile( $self->{__option}{from}, $file );
	$source .= $self->{__option}{sufix} if $self->{__option}{sufix};
	unless( -f $source && -r _ ) {
		print STDERR "Couldn't find file '$source'\n";
		return;
	}
	my $dest = File::Spec->catfile( $self->{__option}{to}, $file );
	return $self->__rewrite_file( $source, $dest );
}

sub __rewrite_file
{
	my ($self, $source, $dest) = @_;

	my $mode = (stat($source))[2];

	open my $sfh, "<$source" or die "Couldn't open '$source' for read";
	print "Open input '$source' file for substitution\n";

	my ($tmpfh, $tmpfname) = File::Temp::tempfile('mi-subst-XXXX', UNLINK => 1);
	$self->__process_streams( $sfh, $tmpfh, ($source eq $dest)? 1: 0 );
	close $sfh;

	seek $tmpfh, 0, 0 or die "Couldn't seek in tmp file";

	open my $dfh, ">$dest" or die "Couldn't open '$dest' for write";
	print "Open output '$dest' file for substitution\n";

	while( <$tmpfh> ) {
		print $dfh $_;
	}
	close $dfh;
	chmod $mode, $dest or "Couldn't change mode on '$dest'";
}

sub __process_streams
{
	my ($self, $in, $out, $replace) = @_;
	
	my @queue = ();
	my $subst = $self->{'__subst'};
	my $re_subst = join('|', map {"\Q$_"} keys %{ $subst } );

	while( my $str = <$in> ) {
		if( $str =~ /^###\s*(before|replace|after)\: ?(.*)$/s ) {
			my ($action, $nstr) = ($1,$2);
			$nstr =~ s/\@($re_subst)\@/$subst->{$1}/ge;

			$action = 'before' if !$replace && $action eq 'replace';
			if( $action eq 'before' ) {
				die "no line before 'before' action" unless @queue;
				# overwrite prev line;
				pop @queue;
				push @queue, $nstr;
				push @queue, $str;
			} elsif( $action eq 'replace' ) {
				push @queue, $nstr;
			} elsif( $action eq 'after' ) {
				push @queue, $str;
				push @queue, $nstr;
				# skip one line;
				<$in>;
			}
		} else {
			push @queue, $str;
		}
		while( @queue > 3 ) {
			print $out shift(@queue);
		}
	}
	while( scalar @queue ) {
		print $out shift(@queue);
	}
}

1;
