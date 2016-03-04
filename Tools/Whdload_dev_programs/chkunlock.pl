#!/usr/bin/perl -w
# $Id: chkunlock.pl 1.1 2014/02/01 01:45:36 wepl Exp wepl $
# this script searches the WHDLoad's kickfs SNOOPFS log
# and will display all Lock() and Open() which do not have a
# corresponding UnLock()/Close()
# log file name can be specified or will be take from the prefs
# file
# if there multiple runs logged, only the last one will be checked

$prefs = "s:whdload.prefs";
$path = undef;
$file = ".whdl_log";
$debug = 0;

if (@ARGV == 0) {
	# get log file name from prefs
	open IN,$prefs or die "$prefs:$!";
	while (<IN>) {
		/^CoreDumpPath=(\S+)/i and $path=$1;
	}
	close IN;
	$path or die "no path in prefs found";
	$log = "$path/$file";
} else {
	$log = shift @ARGV;
}

open IN,$log or die "$log:$!";
while (<IN>) {
	if (/KICKFS.*internal lock.*fl=\$([\dA-F]+) </) {
		$debug and print "Open $1\n";
		if ($fh{$1}) {
			print "Double Open: $_";
		} else {
			$fh{$1}=$_;
		}
	}
	if (/KICKFS.*Close.*fha1=\$([\dA-F]+)/) {
		$debug and print "Close $1\n";
		if ($fh{$1}) {
			delete $fh{$1};
		} else {
			print "Close without Open: $_";
		}
	}
	if (/KICKFS.*LOCATE_OBJECT.*\) fl=\$([\dA-F]+)/ and $1) {
		$debug and print "Lock $1\n";
		if ($lock{$1}) {
			print "Double Lock: $_";
		} else {
			$lock{$1}=$_;
		}
	}
	if (/KICKFS.*FREE_LOCK.*fl=\$([\dA-F]+)/) {
		$debug and print "UnLock $1\n";
		if ($lock{$1}) {
			delete $lock{$1};
		} else {
			print "UnLock without Lock: $_";
		}
	}
	if (/^\*{5}/) {
		# reset on new WHDLoad run
		%fh = %lock = ();
	}
}
close IN;

foreach (keys %fh) {
	push @d,substr($fh{$_},0,7) . "missing Close: " . substr($fh{$_},6);
}
foreach (keys %lock) {
	push @d,substr($lock{$_},0,7) . "missing UnLock:" . substr($lock{$_},6);
}
print sort @d;


