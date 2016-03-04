#!/usr/bin/perl -w
# $Id: chkslaves.pl 1.2 2010/12/19 14:43:45 wepl Exp wepl $
# list all slaves recursively
# 03.04.2010	slave reading moved to seprate .pm
# 		updated for Slaves v16

use strict;
require 'parseslave.pm';

if (@ARGV < 0) {
  print STDERR "usage: chkslaves.pl [file/dir...]\n";
  exit 1;
}

@ARGV > 0 or push @ARGV,'.';
my $rootfile;
foreach $rootfile (@ARGV) {
  if (-d $rootfile) {
    &ScanDir($rootfile);
  } else {
    &Check($rootfile);
  }
}

exit;

sub ScanDir {
  my($dir) = @_;			#parameters
  my $file;
  local(*DIR);				#local filehandle
  opendir(DIR,$dir);
  while(defined ($file = readdir(DIR))) {		#for all files
    if ($file !~ /^\./) {		#no dot files!
      $file = "$dir/$file";
      if (-d $file) {			#directory?
        &ScanDir($file);		#recurse
      } else {
        if ($file =~ /\.slave$/i) {	#slave file?
          &Check($file);
        }
      }
    }
  }
  closedir(DIR);
}

sub Check {
  my $filename = shift;
  my ($size,$date,$Version,$Flags,$sFlags,$BaseMemSize,$ExecInstall,$GameLoader,
    	$CurrentDir,$DontCache,$keydebug,$keyexit,$ExpMem,$name,$copy,$info,
	$kickname,$kicksize,$kickcrc);
  print "reading $filename\n";
  if ($_ = &ParseSlave($filename)) {
    ($size,$date,$Version,$Flags,$sFlags,$BaseMemSize,$ExecInstall,$GameLoader,
    	$CurrentDir,$DontCache,$keydebug,$keyexit,$ExpMem,$name,$copy,$info,
	$kickname,$kicksize,$kickcrc) = @$_;
    printf "slave=$filename size=$size date=$date ver=$Version flags=\$%x=($sFlags) " .
    	"basemem=\$%x=$BaseMemSize exec=\$%x curdir=$CurrentDir dontcache=$DontCache",
  	$Flags,$BaseMemSize,$ExecInstall;
    if ($Version >= 4) {
      printf " keydebug=\$%x keyexit=\$%x",$keydebug,$keyexit;
    }
    if ($Version >= 8) {
      printf " expmem=\$%x=$ExpMem",$ExpMem;
    }
    if ($Version >= 10) {
      $info =~ s/\n/',10,'/g;
      $info =~ s/\xff/',-1,'/g;
      $info =~ s/,'',/,/g;
      printf " name='$name' copy='$copy' info='$info'";
    }
    if ($Version >= 16) {
      printf " kickname=$kickname kicksize=\$%x=$kicksize kickcrc=$kickcrc",$kicksize;
    }
    print "\n";
  }
}

