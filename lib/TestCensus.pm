#!/usr/bin/perl

package MyCPAN::Indexer::TestCensus;
use strict;

use warnings;
no warnings;

use subs qw(get_caller_info);
use vars qw($VERSION);
use base qw(MyCPAN::Indexer);

$VERSION = '0.15_02';

=head1 NAME

MyCPAN::Indexer::TestCensus - Count the Test modules used in test suites

=head1 SYNOPSIS

	use MyCPAN::Indexer;

=head1 DESCRIPTION

This module implements the indexer_class and reporter_class components
to allow C<backpan_indexer.pl> to count the test modules used in the
indexed distributions. 

It runs through the indexing and prints a report at the end of the run.
You probably

=cut

use Carp qw(croak);
use Cwd qw(cwd);

use Log::Log4perl qw(:easy);

__PACKAGE__->run( @ARGV ) unless caller;

=head2 Indexer class

=over 4

=item examine_dist

Given a distribution, unpack it, look at it, and report the findings.
It does everything except the looking right now, so it merely croaks.
Most of this needs to move out of run and into this method.

=cut

{
my @methods = (
	#    method                error message                  fatal
	[ 'unpack_dist',        "Could not unpack distribtion!",     1 ],
	[ 'find_dist_dir',      "Did not find distro directory!",    1 ],
	[ 'find_tests',         "Could not find tests!",             0 ],
	);

sub examine_dist
	{
#	TRACE( sub { get_caller_info } );

	foreach my $tuple ( @methods )
		{
		my( $method, $error, $die_on_error ) = @$tuple;
		DEBUG( "examine_dist calling $method" );
		
		unless( $_[0]->$method() )
			{
			ERROR( $error );
			if( $die_on_error ) # only if failure is fatal
				{
				ERROR( "Stopping: $error" );
				$_[0]->set_run_info( 'fatal_error', $error );
				return;
				}
			}
		}
	
	{
	my @file_info = ();
	foreach my $file ( @{ $_[0]->dist_info( 'tests' ) } )
		{
		DEBUG( "Processing test $file" );
		my $hash = $_[0]->get_test_info( $file );
		push @file_info, $hash;
		}

	$_[0]->set_dist_info( 'test_info', [ @file_info ] );
	}

	return 1;
	}
}

=item setup_run_info

Like C<setup_run_info> in C<MyCPAN::Indexer>, but it remembers fewer
things. The test census really just cares about statements in the test
files, so the details about the run aren't as interesting.

=cut

sub setup_run_info
	{
#	TRACE( sub { get_caller_info } );

	require Config;
	
	my $perl = Probe::Perl->new;
	
	$_[0]->set_run_info( 'root_working_dir', cwd()   );
	$_[0]->set_run_info( 'run_start_time',   time    );
	$_[0]->set_run_info( 'completed',        0       );
	$_[0]->set_run_info( 'pid',              $$      );
	$_[0]->set_run_info( 'ppid',             getppid );

	$_[0]->set_run_info( 'indexer',          ref $_[0] );
	$_[0]->set_run_info( 'indexer_versions', $_[0]->VERSION );

	return 1;
	}


=item setup_dist_info

Like C<setup_dist_info> in C<MyCPAN::Indexer>, but it remembers fewer
things. The test census really just cares about statements in the test
files, so the details about the distribution aren't as interesting.

=cut

sub setup_dist_info
	{
#	TRACE( sub { get_caller_info } );

	my( $self, $dist ) = @_;

	DEBUG( "Setting dist [$dist]\n" );
	$self->set_dist_info( 'dist_file',     $dist                   );
		
	return 1;
	}

=back

=head2 Reporter class

=over 4

=item get_reporter( $Notes )

C<get_reporter> sets the C<reporter> key in the C<$Notes> hash reference. The
value is a code reference that takes the information collected about a distribution
and counts the modules used in the test files.

See L<MyCPAN::Indexer::Tutorial> for details about what C<get_reporter> expects
and should do.

=cut

our $file = "test_use";
#unlink $file;

{
sub get_reporter
	{
	#TRACE( sub { get_caller_info } );

	my( $class, $Notes ) = @_;

	$Notes->{reporter} = sub {

		my( $Notes, $info ) = @_;

		my $test_files = $info->{dist_info}{test_info};

		our %DBM;
		dbmopen %DBM, $file, 0755 or die "$!";

		foreach my $test_file ( @$test_files )
			{
			my $uses = $test_file->{uses};
			DEBUG( "Found test modules @$uses" );
			
			foreach my $used_module ( @$uses )
				{
				$DBM{$used_module}++;
				}
			}
		
		dbmclose %DBM;

		};
		
	1;
	}

}

sub final_words
	{	
	my( $class ); 
	DEBUG( "Final words from the Reporter" );
	
	our %DBM;
	dbmopen %DBM, $file, undef;

	print "Found modules:\n";

	foreach my $module (
		sort { $DBM{$b} <=> $DBM{$a} || $a cmp $b } keys %DBM )
		{
		next unless $module =~ m/^Test\b/;
		printf "%6d %s\n", $DBM{$module}, $module;
		}
	
	dbmclose %DBM;
	}
	
=pod

foreach my $file ( glob "*.yml" )
	{
	my $yaml = LoadFile( $file );
	
	my $test_files = $yaml->{dist_info}{test_info};
	
	foreach my $test_file ( @$test_files )
		{
		my $uses = $test_file->{uses};
		
		foreach my $used_module ( @$uses )
			{
			$Seen{$used_module}++;
			}
		}
	}

=cut

=back

=head1 TO DO

=over 4

=item Count the lines in the files

=item Code stats? Lines of code, lines of pod, lines of comments

=back

=head1 SOURCE AVAILABILITY

This code is in Github:

	git://github.com/briandfoy/mycpan-indexer.git

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
