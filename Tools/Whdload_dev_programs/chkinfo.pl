#!/usr/bin/perl -w
# $Id: chkinfo.pl 1.4 2014/10/23 00:43:37 wepl Exp wepl $
# displays all information about an Amiga Icon
# optionally writes all images contained in the icon into separate png picture files (requires perl module GD)
# supports original icon (2.x + MWB + RomIcon palette used), NewIcons and OS3.5 Coloricons

use strict;
use Getopt::Std;
require 'parseinfo.pm';
our (%icontype,@romcols);

#
# check parameters
#
our ($opt_h, $opt_i, $opt_w);
unless (getopts("hiw") and @ARGV > 0 and !$opt_h ) {
	print STDERR 'usage: chkinfo.pl [-iw] infofiles...
	-i display histogramm
	-w write each present image to a png file
';
	exit 1;
}
if ($opt_w) {
	eval { require GD; };
	if ($@) { die "option '-w' requires perl module GD"; }
}

my ($file,$r,%res);
foreach $file (@ARGV) {
	if ($r = &ParseInfo($file,0)) {
		%res = %{$r};
		my (	$magic,$version,$ggnext,$ggleft,$ggtop,$ggwidth,$ggheight,$ggflags,
			$ggacti,$ggtype,$gggadget,$ggselect,$ggtext,$ggmutual,$ggspecial,$ggid,$gguser,
			$type,$pad,$defaulttool,$tooltypes,$currentx,$currenty,$drawerdata,$toolwindow,$stacksize
		) = @{$res{'do'}};
		printf "$file:\n" .
			"	type=$type=$icontype{$type} dt=%x tt=%x x=$currentx y=$currenty " .
			"drawerdata=%x toolwin=$toolwindow stack=$stacksize\n" .
			"	ggnext=$ggnext ggleft=$ggleft ggtop=$ggtop ggwid=$ggwidth " .
			"gghei=$ggheight ggflags=$ggflags ggacti=$ggacti ggtype=$ggtype\n" .
			"	gggadget=%x ggselect=%x ggtext=$ggtext ggmutual=%x ggspecial=$ggspecial ggid=$ggid gguser=%x\n"
			,$defaulttool,$tooltypes,$drawerdata,$gggadget,$ggselect,$ggmutual,$gguser;
		if ($res{'dd'}) {
			my (	$ddoffset,$nwleft,$nwtop,$nwwidth,$nwheight,$nwdpen,$nwbpen,
				$nwidcmp,$nwflags,$nwgadget,$nwcheck,$nwtitle,$nwscreen,$nwbitmap,
				$nwminwidth,$nwminheight,$nwmaxwidth,$nwmaxheight,$nwtype,$ddx,$ddy
			) = @{$res{'dd'}};
			printf "	drawerdata(%x): left=$nwleft top=$nwtop wid=$nwwidth " .
				"hei=$nwheight detailpen=$nwdpen blockpen=$nwbpen idcmp=$nwidcmp\n" .
				"		flags=%x gadget=%x checkmark=$nwcheck title=%x " .
				"screen=$nwscreen bitmap=$nwbitmap\n" .
				"		minwid=$nwminwidth minhei=$nwminheight maxwid=$nwmaxwidth " .
				"maxhei=$nwmaxheight type=$nwtype x=$ddx y=$ddy\n"
				,$ddoffset,$nwflags,$nwgadget,$nwtitle;
		}
		foreach my $i ('gg','gs') {
			if ($res{$i}) {
				my ($ggoffset,$igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,
					$igpick,$igonoff,$ignext,$imgsize,$img) = @{$res{$i}};
				printf "	image$i(%x): left=$igleft top=$igtop width=$igwidth " .
					"height=$igheight depth=$igdepth" .
					" data=%x pick=$igpick onoff=$igonoff next=%x imgsize=$imgsize=\$%x(=%d)\n"
					,$ggoffset,$igdata,$ignext,$imgsize,((($igwidth+15)&~15)*$igheight*$igdepth)/8;
					$opt_w and &WriteGadImage($igwidth,$igheight,$igdepth,$img,"$file.$i.png");
			}
		}
		if ($res{'dt'}) {
			my ($dtoffset,$dt) = @{$res{'dt'}};
			printf "	defaulttool(%x): '$dt'\n",$dtoffset;
		}
		if ($res{'tt'}) {
			my ($ttoffset,$ttcnt,$tt) = @{$res{'tt'}};
			printf "	tooltypes(%x): lines=$ttcnt\n",$ttoffset;
			foreach (@{$tt}) {
				print "		'$_'\n";
			}
		}
		if ($res{'dd2'}) {
			my (	$dd2offset,$dd2flags,$dd2vm) = @{$res{'dd2'}};
			printf "	drawerdata2(%x): flags=%x viewmodes=%x\n",$dd2offset,$dd2flags,$dd2vm;
		}
		foreach my $i (1..2) {
			if ($res{"ni$i"}) {
				my ($n,%n);
				if ($n = &ParseNewIcon($res{"ni$i"})) {
					%n = %{$n};
					printf "	newicon$i: trans=$n{'tr'} width=$n{'wid'} height=$n{'hei'} " .
						"cols=$n{'cc'} depth=$n{'de'} colsize=%d imgsize=%d=\$%xc calcimgsize=%d\n",
						length($n{'cd'}),length($n{'id'}),length($n{'id'}),$n{'wid'}*$n{'hei'};
					$opt_i and &Histogramm($n{'wid'},$n{'hei'},$n{'id'});
					$opt_w and &WriteNewColImage($n{'wid'},$n{'hei'},$n{'cd'},$n{'id'},"$file.new$i.png");
				} else {
					print "newicon$i: couldn't parse data\n";
				}
			}
		}
		if ($res{'ci'}) {
			my ($cioffset,$ci) = @{$res{'ci'}};
			my ($c,%c);
			if ($c = &ParseColIcon($ci)) {
				%c = %{$c};
				printf "	coloricon(%x): flags=$c{'fl'} width=$c{'wid'} height=$c{'hei'} " .
					"aspectx=$c{'ax'} aspecty=$c{'ay'}\n",$cioffset;
				foreach my $i (1..2) {
					if ($c{"de$i"}) {
						printf "		image$i: cols=%d trans=%d depth=%d colsize=%d " .
							"imgsize=%d=\$%xc calcimgsize=%d\n",
						$c{"cc$i"},$c{"ct$i"},$c{"de$i"},length($c{"cd$i"}),length($c{"id$i"}),
							length($c{"id$i"}),$c{'wid'}*$c{'hei'};
						$opt_i and &Histogramm($c{'wid'},$c{'hei'},$c{"id$i"});
						$opt_w and &WriteNewColImage($c{'wid'},$c{'hei'},$c{"cd$i"},$c{"id$i"},"$file.col$i.png");
					}
				}
			} else {
				print "coloricon: couldn't parse data\n";
			}
		}
	}
}

sub WriteGadImage($$$$$) {
	my ($width,$height,$depth,$img,$name) = @_;
	my $image = new GD::Image($width,$height);
	my (@c,$r,$g,$b,$x,$y,$d,$di,@d,$wl,$wp,$hc);
	@c = @romcols;
	while (($r,$g,$b) = splice(@c,0,3)) {
		$image->colorAllocate($r,$g,$b);
	}
	$wl = (($width+15)&~15)/8;	# width of a line in bytes
	$wp = $wl * $height;		# width of a plane in bytes
	# print "w=$width h=$height d=$depth wl=$wl wp=$wp\n";
	for ($y = 0; $y < $height; $y++) {
		for ($x = 0; $x < $width; $x++) {
			if (! ($x & 15)) {	# get next image data 16-bit word
				@d = (0) x 16;
				for ($d = $depth-1; $d >= 0; $d--) {
					$di = 0;
					foreach $_ (split('',unpack("B16",substr($img,$d*$wp + $y*$wl + $x/8,2)))) {
						$d[$di] <<= 1; $d[$di++] += $_;
					}
				}
				# printf "y=$y x=$x o=%x @d\n",($d+1)*$wp + $y*$wl + $x/8;
			}
			# print "x=$x y=$y $d[0]\n";
			if (!$hc and $d[0] > 15) { print "warning colors above 15 used ($d[0])\n"; $hc++ }
			$image->setPixel($x,$y,shift @d);
		}
	}
	if (!open(OUT,">$name")) {
		warn "$name:$!";
	} else {
		binmode OUT;
		print OUT $_ = $image->png;
		close OUT;
		print "$name written\n";
	}
}

sub WriteNewColImage($$$$$) {
	my ($width,$height,$cols,$img,$name) = @_;
	my $image = new GD::Image($width,$height);
	my (@c,$r,$g,$b,$x,$y,@d);
	@c = unpack("C*",$cols);
	while (($r,$g,$b) = splice(@c,0,3)) {
		# print "rgb: $r,$g,$b\n";
		$image->colorAllocate($r,$g,$b);
	}
	@d = unpack("C*",$img);
	for ($y = 0; $y < $height; $y++) {
		for ($x = 0; $x < $width; $x++) {
			#print "pic: $x,$y $i[0]\n";
			$image->setPixel($x,$y,shift @d);
		}
	}
	if (!open(OUT,">$name")) {
		warn "$name:$!";
	} else {
		binmode OUT;
		print OUT $_ = $image->png;
		close OUT;
		print "$name written\n";
	}
}

sub Histogramm($$$) {
	my ($width,$height,$img) = @_;
	my ($x,$y,@d,%c);
	@d = unpack("C*",$img);
	for ($y = 0; $y < $height; $y++) {
		for ($x = 0; $x < $width; $x++) {
			$c{shift @d}++;
		}
	}
	print "		histogramm: used=" . int(keys %c);
	foreach (sort {$a <=> $b} keys %c) {
		print " $_=$c{$_}";
	}
	print "\n";
}

