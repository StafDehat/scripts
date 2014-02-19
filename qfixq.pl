#!/usr/bin/perl -w
#
# qfixq
# John Simpson <jms1@jms1.net> 2003-10-17
#
# repairs a messed-up qmail queue structure.
#
# *********************************************************************
# ***                                                               ***
# ***                    DANGER! DANGER! DANGER!                    ***
# ***                                                               ***
# *** DO NOT RUN THIS WHILE ANY QMAIL-RELATED PROGRAMS ARE RUNNING! ***
# ***                                                               ***
# ***                    DANGER! DANGER! DANGER!                    ***
# ***                                                               ***
# *********************************************************************
#
# 2004-01-20 jms1 - fixed an issue with directory/file permissions being set
#   incorrectly in some cases
#
# 2004-01-21 jms1 - fixed issue where /v/q/queue/lock/trigger was being set
#   to the wrong owner, causing queue slowdowns as detailed here:
#   http://lifewithqmail.org/lwq.html#trigger
#
# 2004-01-22 jms1 - fixed a REALLY minor issue- mess/*/* files were being
#   forced to perm 0640, where their native state in a correct queue is 0644.
#   the old way did no damage (the ownership was correct so it didn't really
#   matter) but it was dumping a lot of un-necessary warnings when it ran,
#   which may make people think there was a problem when there wasn't one.
#
# 2004-10-13 jms1 - at least one version of perl considers mkdir() with
#   only one argument to be an error, so i've added specific permissions to
#   all mkdir() calls. i've also added a specific umask() call, just because
#   it's a good idea for any program which creates files or directories which
#   shouldn't be world-readable when they're first created. thanks go to
#   Tom Clegg for the suggestion.
#
# 2005-04-11 jms1 - (no code changed.) changed the copyright notice to
#   specify that the license is the GPL VERSION 2 ONLY. i'm not comfortable
#   with the "or future versions" clause until i know what these "future
#   versions" will look like.
#
# 2005-04-14 jms1 - (no code changed.) added comments to show which lines
#   are to be changed for configuring the script to work on non-standard
#   machines.
#
# 2005-04-20 jms1 - once upon a time, there was a guy who had a queue with
#   over 200 buckets. we don't know why, maybe his server handles millions
#   of message per day, but whatever... he downloaded this script, and even
#   though he had been specifically told to fix the bucket count first, he
#   ran it without fixing the bucket count first. in doing so he destroyed
#   his queue so badly that qmail-send wouldn't work- it started spewing
#   "unable to open info/24, sleeping..." over and over again.
#
#   so now the script will run qmail-showctl and figure out how many buckets
#   to use automatically.
#
# 2005-04-21 jms1 - again in the interest of safety, i'm adding an extra
#   safety feature to the script which will allow it to FIND problems, but
#   not fix them unless you run the script as "qfixq live".
#
# 2005-04-22 jms1 - to protect people from thinking they've fixed a problem
#   which still exists, now if the script is not running in live mode, it
#   will print a reminder at the end of the output as well as the beginning.
#
# 2005-08-30 jms1 - fixed two minor permissions issues. thanks to Michael
#   Martinell for spotting the problem. i keep saying i shouldn't write
#   code when i'm tired...
#
# 2005-11-15 jms1 - adding a "empty" option which will delete any files
#   relating to individual messages. this should leave you with an
#   empty queue.
#
#   i also removed "default number of buckets" as an option- basically,
#   if "qmail-showctl" can't give you the right answer, it would be too
#   dangerous to even think of trying to run this script- because that
#   would mean that there's a lot more wrong than just your queue being
#   corrupted.
#
# 2009-02-03 jms1 - fixing non-code-related typo ("Remving" -> "Removing")
#   thanks to Jussi Nikula for letting me know about it.
#   also changing license from "GPLv2 only" to "GPLv2 or v3".
#
###############################################################################
#
# Copyright (C) 2003,2004,2005,2009 John Simpson.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 or version 3 of the
# license, at your option.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

require 5.003 ;
use strict ;

###############################################################################
#
# configuration here

my $vq		= "/var/qmail" ;
my $qmailq	= getpwnam ( "qmailq" ) ;
my $qmailr	= getpwnam ( "qmailr" ) ;
my $qmails	= getpwnam ( "qmails" ) ;
my $qmail	= getgrnam ( "qmail"  ) ;

###############################################################################
#
# it should not be necessary to change anything below this point, however
# if you do find a bug or have an idea to make it work better, please let
# me know.
#
###############################################################################

umask ( 077 ) ;

my %dirown =
(
	"bounce" => $qmails ,
	"info"   => $qmails ,
	"intd"   => $qmailq ,
	"local"  => $qmails ,
	"mess"   => $qmailq ,
	"remote" => $qmails ,
	"todo"   => $qmailq ,
) ;

my %dirperm =
(
	"bounce" => 0700 ,
	"info"   => 0700 ,
	"intd"   => 0700 ,	
	"local"  => 0700 ,
	"mess"   => 0750 ,
	"remote" => 0700 ,
	"todo"   => 0750 ,
) ;

my %fileperm =
(
	"bounce" => 0600 ,
	"info"   => 0600 ,
	"intd"   => 0644 ,	
	"local"  => 0600 ,
	"mess"   => 0644 ,
	"remote" => 0600 ,
	"todo"   => 0644 ,
) ;

my %dirbuckets =
(
	"bounce" => 0 ,
	"info"   => 1 ,
	"intd"   => 0 ,	
	"local"  => 1 ,
	"mess"   => 1 ,
	"remote" => 1 ,
	"todo"   => 0 ,
) ;

my $vqq = "$vq/queue" ;
my $live = 0 ;
my $empty = 0 ;

my ( %file , %msg , %ren , %del , $buckets ) ;

$| = 1 ;

###############################################################################
#
# fix/set ownership and permissions on a file

sub chownmod($$$@)
{
	my $uid = shift ;
	my $gid = shift ;
	my $prm = shift ;

	while ( my $f = shift )
	{
		my @s = stat $f ;

		if ( ( $s[4] != $uid ) || ( $s[5] != $gid ) )
		{
			if ( $s[4] != $uid )
			{
				printf "Fixing uid of $f (%d s/b %d)\n" ,
					$s[4] , $uid ;
			}

			if ( $s[5] != $uid )
			{
				printf "Fixing gid of $f (%d s/b %d)\n" ,
					$s[5] , $gid ;
			}

			$live && chown ( $uid , $gid , $f ) ;
		}

		if ( ( $s[2] & 0777 ) != ( $prm & 0777 ) )
		{
			printf "Fixing permissions on $f (%04o s/b %04o)\n" ,
				( $s[2] & 0777 ) , ( $prm & 0777 ) ;
			$live && chmod ( ( $prm & 0777 ) , $f ) ;
		}
	}
}

###############################################################################
###############################################################################
###############################################################################
#
# sanity checks

$< && die "This program requires root privileges.\n" ;

while ( my $z = shift @ARGV )
{
	if ( $z eq "live" )
	{
		$live = 1 ;
	}
	elsif ( $z eq "empty" )
	{
		$empty = 1 ;
	}
}

if ( $live && $empty )
{
	print <<EOF ;
Running in LIVE and EMPTY mode. All messages WILL BE DELETED from the 
queue.

EOF
}
elsif ( $live )
{
	print <<EOF ;
Running in LIVE mode. All fixes will be written to the disk.

EOF
}
elsif ( $empty )
{
	print <<EOF ;
Running in EMPTY mode, but not LIVE mode. Messages will NOT actually be
deleted.

If you wish to entirely empty the queue, use "$0 live empty".

EOF
}
else
{
	print <<EOF ;
Running in FIND mode. Any fixes described will NOT be written to the disk.

If you wish to run in LIVE mode and fix problems, use "$0 live".

If you wish to entirely empty the queue, use "$0 live empty".

EOF
}

###############################################################################
#
# figure out how many buckets we have to play with

open ( B , "$vq/bin/qmail-showctl |" )
	or die "Can\'t run $vq/bin/qmail-showctl: $!\n" ;
while ( my $line = <B> )
{
	next unless ( $line =~ /split\: (\d+)/ ) ;
	$buckets = $1 ;
	last ;
}
close B ;

if ( $buckets )
{
	print "Using $buckets buckets as ordered by qmail-showctl.\n" ;
}
else
{
	die <<EOF ;

Cannot determine how many buckets to use, cannot continue.

EOF
}

###############################################################################
#
# fix directory ownerships and permissions

chownmod ( $qmailq , $qmail , 0750 , $vqq ) ;
chownmod ( $qmailq , $qmail , 0750 , "$vqq/lock" ) ;
chownmod ( $qmails , $qmail , 0600 , "$vqq/lock/sendmutex" ) ;
chownmod ( $qmailr , $qmail , 0644 , "$vqq/lock/tcpto" ) ;
chownmod ( $qmails , $qmail , 0622 , "$vqq/lock/trigger" ) ;
chownmod ( $qmailq , $qmail , 0700 , "$vqq/pid" ) ;

for my $dir ( sort keys %dirown )
{
	unless ( -d "$vqq/$dir" )
	{
		print "Creating missing directory $vqq/dir\n" ;
		$live && mkdir ( "$vqq/$dir" , 0700 ) ;
	}

	chownmod ( $dirown{$dir} , $qmail , $dirperm{$dir} , "$vqq/$dir" ) ;

	if ( $dirbuckets{$dir} )
	{
		for my $n ( 0 .. ( $buckets - 1 ) )
		{
			unless ( -d "$vqq/$dir/$n" )
			{
				print "Creating missing bucket $vqq/$dir/$n\n" ;
				$live && mkdir ( "$vqq/$dir/$n" , 0700 ) ;
			}

			chownmod ( $dirown{$dir} , $qmail , $dirperm{$dir} ,
				"$vqq/$dir/$n" ) ;		
		}
	}
}

# dunno what to do with files in "pid"... delete? ignore? anyone?
# thought about deleting, ignoring them for now...
# rm -r $vqq/pid/*

########################################
# make a list of what files exist for each message

for my $dir ( sort keys %dirown )
{
	print "Reading $vqq/$dir\n" ;

	open ( L , "find $vqq/$dir -type f |" )
		or die "Can\'t run [find $vqq/$dir -type f]: $!\n" ;

	while ( my $line = <L> )
	{
		chomp $line ;
		$line =~ m|.*/(.*)| ;
		my $n = $1 ;

		if ( $empty )
		{
			$file{"$n:$dir"} = $line ;
			$msg{$n} = "" ;
			$del{$n} = "" ;
			next ;
		}

		chownmod ( $dirown{$dir} , $qmail , $fileperm{$dir} , $line ) ;

		my @s = stat $line ;

		unless ( $s[7] )
		{
			print "Removing zero-byte file $line\n" ;
			$live && unlink $line ;
			next ;
		}

		if ( exists $file{"$n:$dir"} )
		{
			# duplicate names (i.e. info/3/101 and info/5/101) ???
			print "Duplicate [$n:$dir] message will be killed\n" ;
			print "\tRemoving $line\n" ;
			$live && unlink $line ;
			$del{$n} = 1 ;
			next ;
		}

		$file{"$n:$dir"} = $line ;
		$msg{$n} = "" ;

		if ( $dirbuckets{$dir} )
		{
			$line =~ m|.*/(.*?)/$n| ;
			my $b = $1 ;
			if ( $b != ( $n % $buckets ) )
			{
				print "$n is in the wrong bucket\n" ;
				$ren{$n} ||= $n ;
			}
		}

		if ( $dir eq "mess" )
		{
			if ( $n != $s[1] )
			{
				print "$n should be $s[1]\n" ;
				$ren{$n} = $s[1] ;
			}
		}
	}

	close L ;
}

###############################################################################
#
# kill off any messages which need to be deleted

for my $m ( sort keys %del )
{
	print "Killing message $m\n" ;

	for my $dir ( sort keys %dirown )
	{
		if ( exists $file{"$m:$dir"} )
		{
			my $f = $file{"$m:$dir"} ;
			print "\tRemoving $f\n" ;

			$live && unlink $f ;

			delete $file{"$m:$dir"} ;
		}
	}

	if ( exists $ren{$m} )
	{
		delete $ren{$m} ;
	}

	delete $del{$m} ;
	delete $msg{$m} ;
}

###############################################################################
#
# analyze the lists, find and delete mesages with missing pieces

print "Analyzing the results...\n" ;

for my $m ( sort keys %msg )
{
	if ( exists $file{"$m:bounce"} ) { $msg{$m} .= "B" ; }
	if ( exists $file{"$m:intd"}   ) { $msg{$m} .= "D" ; }
	if ( exists $file{"$m:info"}   ) { $msg{$m} .= "F" ; }
	if ( exists $file{"$m:local"}  ) { $msg{$m} .= "L" ; }
	if ( exists $file{"$m:mess"}   ) { $msg{$m} .= "M" ; }
	if ( exists $file{"$m:remote"} ) { $msg{$m} .= "R" ; }
	if ( exists $file{"$m:todo"}   ) { $msg{$m} .= "T" ; }

	next if (    ( $msg{$m} eq "DMT" )	# waiting to be processed
		  || ( $msg{$m} eq "FLM" )	# waiting on local delivery
		  || ( $msg{$m} eq "FMR" )	# waiting on remote delivery
		  || ( $msg{$m} eq "BFLM" )	# bounce from local delivery
		  || ( $msg{$m} eq "BFMR" )	# bounce from remote delivery
		) ;

	print "$m: [$msg{$m}] illegal file combination, removing\n" ;

	for my $dir ( sort keys %dirown )
	{
		if ( exists $file{"$m:$dir"} )
		{
			my $f = $file{"$m:$dir"} ;
			print "\tRemoving $f\n" ;

			$live && unlink $f ;

			delete $file{"$m:$dir"} ;
		}
	}

	if ( exists $ren{$m} )
	{
		delete $ren{$m} ;
	}

	delete $msg{$m} ;
}

###############################################################################
#
# handle any renaming that needs to be done, either because "mess" filenames
# are not the same as the inode numbers, or because the files are in the
# wrong buckets.
#
# we do this as two passes, just in case a message's
# new filename already exists.

########################################
# first pass: all files get ".temp" added first

for my $m ( sort keys %ren )
{
	for my $dir ( sort keys %dirown )
	{
		if ( exists $file{"$m:$dir"} )
		{
			my $f = $file{"$m:$dir"} ;
			my $n = "$f.temp" ;

			print "Renaming(1) $f to $n\n" ;
			$live && rename ( $f , $n ) ;

			$file{"$m:$dir"} = $n ;
		}
	}
}

########################################
# second pass: the ".temp" files get their final names

for my $m ( sort keys %ren )
{
	########################################
	# these directories use a bucket number
	# which must be part of the final filename

	for my $dir ( sort keys %dirown )
	{
		if ( exists $file{"$m:$dir"} )
		{
			my $f = $file{"$m:$dir"} ;
			my $n = "$vqq/$dir/$ren{$m}" ;

			if ( $dirbuckets{$dir} )
			{
				my $b = $ren{$m} % $buckets ;
				$n = "$vqq/$dir/$b/$ren{$m}" ;
			}

			print "Renaming(2) $f to $n\n" ;
			$live && rename ( $f , $n ) ;

			delete $file{"$m:$dir"} ;
			$file{"$ren{$m}:$dir"} = $n ;
		}
	}

	$msg{$ren{$m}} = $msg{$m} ;
	delete $msg{$m} ;
}

###############################################################################
#
# in case they missed it the first time...

unless ( $live )
{
	print <<EOF

******************************************************************************

This was not LIVE mode.
Anything described above was NOT written to the disk.

If you wish to run in live mode, use "$0 live".

If you wish to entirely empty the queue, use "$0 live empty".

******************************************************************************

EOF
}
