#!/usr/bin/perl -w
# $Id: chkdups.pl 1.4 2014/08/12 00:41:27 wepl Exp wepl $
# scans directory hierachies for equal files
# report all equal files
# optional prints formatted strings to a separate file
# if there a lot files of equal length and the file length is greater than
# buflen this script requires a file handle for each file, so it may run out
# of file handles, increasing buflen to avoid the need to hold file handles
# at the cost of memory can help here

use strict;
use Getopt::Std;

my $buflen=64*1024;	# buffer length for file comparison
my $cntinfo = 1000;	# message after scanning cntinfo files

my $dc=0;	# directory count
my $fc=0;	# file count
my $fe=0;	# file error count
my %fs=();	# hash files via filesize, value is reference to array of files
my $fq=0;	# files equal (all)
my $fo=0;	# obsolete files because being duplicate
my $bo=0;	# byte size of obsolete files because being duplicate

#
# check parameters
#
our ($opt_b, $opt_c, $opt_f, $opt_h, $opt_o, $opt_v, $opt_x);
unless (getopts("b:c:f:ho:vx:") and @ARGV >= 0 and !$opt_h and ((!$opt_f and !$opt_o) or ($opt_f and $opt_o))) {
	print STDERR 'usage: chkdups.pl [-hv] [-b buflen] [-c count] [-f format -o outputfile] [-x re ] [file/dir...]
	-b buflen, buffer length for read and compare (default '. $buflen .')
	-c count info, print after count files
	-f format string for messages to write to the output file
		%1 first equal file
		%2 second equal file
	-h help, print this info
	-o output file name to write formatted messages to
	-v verbose, print additional infos
	-x re, ignore files matching the regular expression re, e.g. -x "\.info$"
';
	exit 1;
}
$opt_b and $buflen = $opt_b;
$opt_c and $cntinfo = $opt_c;
@ARGV > 0 or push @ARGV,'.';	# default is actual directory

# open output file
if ($opt_o) {
	-f $opt_o and die "output file '$opt_o' already exists";
	open OUT,">$opt_o" or die "cannot open output file '$opt_o':!";
}

# collect all files to %fs
my $rootfile;
foreach $rootfile (@ARGV) {
	if (-d $rootfile) {
		&ScanDir($rootfile);
	} else {
		&Check($rootfile);
	}
}

# print info
my $fec = int(grep {@{$_} > 1} values %fs);	# files with equal length
print "found $dc directories, $fc files and $fec file sizes with multiple files\n";

my ($size,$file);
foreach $size (keys %fs) {
	if (@{$fs{$size}} > 1) {
		my @name = @{$fs{$size}};	# array of file names
		my $cnt = int(@name);		# amount of files
		my $s = $size;			# size to read left
		my ($i,@fh,@eq,$sa,$e);
		my @dat;			# array of file content for each file
		$opt_v and print "checking $cnt files size=$size\n";
		# open/read all files
		for ($i=0; $i<$cnt; $i++) {
			local *FH;
			$opt_v and print "\t$name[$i]\n";
			$e = 0;
			if (open(FH,$name[$i])) {
				if ($size <= $buflen) {
					if (sysread(FH,$dat[$i],$size) != $size) {
						warn "read error on file '$name[$i]':$!";
						$e++;
					}
					close FH;
				} else {
					push @fh,*FH;
				}
			} else {
				warn "cannot open file '$name[$i]':$!";
				$e++;
			}
			if ($e) {
				$fe++;			# file error count
				splice @name,$i,1;	# remove name from array
				$i--;
				$cnt--;
			}
		}
		# set all equal, one group with all files
		@eq = ([0..$#name]);
		# compare the files
		for (; @eq and $s; $s -= $sa) {		# as long as there are equal ones and size left
			$sa = $s > $buflen ? $buflen : $s;	# actual read size
			# read all files
			for ($i=0; $i<$cnt; $i++) {
				if ($fh[$i]) {
					# print "reading $name[$i] s=$s sa=$sa\n";
					if (sysread($fh[$i],$dat[$i],$sa) != $sa) {
						warn "read error on file '$name[$i]':$!";
						$fe++;
						close $fh[$i]; $fh[$i] = undef;
						# remove $i from all groups
						my (@neq,$g);
						foreach (@eq) {
							@_ = grep {$_ != $i} @$g;
							@_ > 1 and push @neq,[@_];
						}
						@eq = @neq;
					}
				}
			}
			# compare
			my ($g, @g, $a, @a, $b, @b);
			for ($g=0; $g<@eq; $g++) {	# foreach group
				@g = @{$eq[$g]};
				$a = shift @g;		# number a
				@a = ($a);		# group a, contains all equal to file a
				@b = ();		# group b, contains all not equal to file a
				$opt_v and print join(" ",map("(" . join(" ",@{$_}) . ")",@eq)) ."\n";
				while (@g) {
					$b = shift @g;	# number b
					if ($dat[$a] eq $dat[$b]) {
						$opt_v and print "checking g=$g a=$a b=$b ->eq\n";
						push @a,$b;
					} else {
						$opt_v and print "checking g=$g a=$a b=$b ->ne\n";
						push @b,$b;
					}
				}
				# if files were unequal to a
				if (@b) {
					if (@a > 1) {
						# replace actual group
						$opt_v and print "replace group g=$g @a\n";
						$eq[$g] = [@a];
					} else {
						# delete actual group
						$opt_v and print "delete group g=$g\n";
						splice @eq,$g,1;
						$g--;
					}
					if (@b > 1) {
						# create new group with unequal files
						$opt_v and print "new group @b\n";
						push @eq,[@b];
					}
				}
			}
		}
		# close all files
		for ($i=0; $i<$cnt; $i++) {
			$fh[$i] and close $fh[$i];
		}
		# process found equal files
		my ($g);
		foreach $g (@eq) {
			print "equal " . int(@$g) . " files size=$size\n";
			my $first;
			foreach (@$g) {
				$fq++;
				$fo++;
				$bo += $size;
				print "\t$name[$_]\n";
				if ($opt_o) {
					if (!$first) {
						$first = $name[$_];
					} else {
						my $s = $opt_f;
						$s =~ s/%1/$first/g;
						$s =~ s/%2/$name[$_]/g;
						printf OUT $s . "\n";
					}
				}
			}
			$fo--;
			$bo -= $size;
		}
	}
}

# close output file
if ($opt_o) {
	close OUT;
	$fq or unlink $opt_o;
}

# print info
print "found $fq equal files, making $fo obsolete files with a sum of " . &fmtint($bo) . " bytes\n";

exit;

sub ScanDir {
	$dc++;
	my $dir = shift;
	my $file;
	local(*DIR);		# local filehandle
	if (opendir(DIR,$dir)) {
		while(defined ($file = readdir(DIR))) {
			next if $file eq '.';
			next if $file eq '..';
			$opt_x and $file =~ /$opt_x/ and next;
			if ($dir =~ /:$/) {
				# Amiga volume specification
				$file = "$dir$file";
			} else {
				$file = "$dir/$file";
			}
			if (-d $file) {		# directory?
				&ScanDir($file);	# recurse
			} else {
				&Check($file);
			}
		}
		closedir(DIR);
	} else {
		warn "cannot open $dir:$!";
	}
}

sub Check {
	$fc++;
	$fc % $cntinfo or print "collected $fc files\n";
	my $name = shift;
	my $size = (stat($name))[7];
	if (! defined $size) {
		warn "could not stat file '$name':$!";
		return;
	}
	if ($fs{$size}) {
		push @{$fs{$size}},$name;
	} else {
		$fs{$size} = [$name];
	}
}

# add thousand separator
sub fmtint ($) {
	$_ = shift;
	s/(\d{1,3}?)(?=(\d{3})+$)/$1,/g;
	return $_;
}
	
