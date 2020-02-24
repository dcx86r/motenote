#!/usr/bin/env perl

use v5.16; # provides __SUB__
use strict;
use warnings;
use Tie::File; # core

sub results {
	my $cacheref = shift;
	foreach (@$cacheref) { 
		$_ =~ s/^#//mg;
		say "$_";
	}
}

# ToDo - highlight searched terms
sub search {
	my $aref = shift;
	my @cache;
	print "Enter search term: ";
	chomp(my $st = <>);
# ToDo - filter regex in $st
	push @cache, (grep m/^(?!#).*$st/im, @$aref);
	results(\@cache);
}

sub hidden_ok {
	print "This note begins with #, "
	. "which makes it unsearchable. " 
	. "Is this OK? [y/n] ";
	while (<>) {
		$_ =~ m/^(y|n)$/ ? () : hidden_ok(); 
		$_ =~ m/^y$/ ? return 1 : ();
		$_ =~ m/^n$/ ? return 0 : ();
	}
}

sub create {
	require Digest::SHA;
	require POSIX;
	my $aref = shift;
	print "Enter note: ";
	chomp(my $note = <>);
	if ($note =~ m/^#/) { exit unless hidden_ok() }

	my $gettime =  POSIX::strftime "%s!%a %b %e %H:%M:%S %Y UTC%z", localtime; 
	my @times = split(/!/, $gettime);
# salting w/ epoch time so identical notes get different hash values
	my $hash = Digest::SHA::sha1_hex("$note" . "$times[1]");

	my $mknote = sub {
		my %data;
		my $chk_hash = sub {
			my $v = shift;
			push my @cache, (grep m/^#@_$/m, @$aref);
			return "@_" unless @cache;
			$v < length($hash) ? __SUB__->($v, substr($hash,0,++$v))
				: die "A full hash collision occurred\n";
			};
		$data{note} = $note;
		$data{hash} = $chk_hash->(4, substr($hash,0,4));
		$data{local_t} = pop @times;
		$data{epoch_t} = pop @times;

		return "#" . "$data{local_t}\n"
			. "#" . "$data{hash}\n"
			. "#" . "$data{epoch_t}\n"
			. "$data{note}\n";
	};

# writing to file in descending order by date
	unshift @$aref, $mknote->();
}

my $sep = "-" x 20 . "\n";
my $file = "notes.txt";
tie my @a, 'Tie::File', $file, recsep => $sep;

# ToDo - for "show" action, take hash value(s) or time frame
my $actions = {
	add => \&create,
	find => \&search,
#	show => \&view
};

$actions->{add}->(\@a) && exit unless @ARGV;

if (defined $actions->{$ARGV[0]}) {
	$actions->{shift @ARGV}->(\@a)
}
