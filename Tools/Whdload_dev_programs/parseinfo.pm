# $Id: parseinfo.pm 1.3 2014/12/01 21:38:30 wepl Exp wepl $
# decode Amiga .info file and provide all information
# 13.08.2014	extracted from chkinfo.pl
# 06.10.2014	finished
# 01.12.2014	imgsize on plain icons fixed

use strict;
our %icontype = (1,'Disk',2,'Drawer',3,'Tool',4,'Project',5,'Garbage',6,'Device',7,'Kick',8,'AppIcon');
our @romcols = (
	153,153,153,	0,0,0,		240,240,240,	85,119,170,
	123,123,123,	175,175,175,	170,144,124,	255,169,151,
	0,0,255,	50,50,50,	96,128,96,	226,209,119,
	255,212,203,	122,96,72,	210,210,210,	229,93,93);

# parse Amiga icon files
# arguments:
#	filename
#	nowarn	if ne don't print warning messages if file isn't an icon
# returns reference to hash of keys:
#	'do'	reference to array of disk object items:
#			$magic,$version,$ggnext,$ggleft,$ggtop,$ggwidth,$ggheight,$ggflags,
#			$ggacti,$ggtype,$gggadget,$ggselect,$ggtext,$ggmutual,$ggspecial,$ggid,$gguser,
#			$type,$pad,$defaulttool,$tooltypes,$currentx,$currenty,$drawerdata,$toolwindow,$stacksize
#	'dd'	reference to array of optional drawer data:
#			$ddoffset,$nwleft,$nwtop,$nwwidth,$nwheight,$nwdpen,$nwbpen,$nwidcmp,$nwflags,$nwgadget,$nwcheck,$nwtitle,
#			$nwscreen,$nwbitmap,$nwminwidth,$nwminheight,$nwmaxwidth,$nwmaxheight,$nwtype,$ddx,$ddy
#	'dd2'	reference to array of optional drawer data OS2.x:
#			$dd2flags,$dd2vm
#	'gg'	reference to array of image data:
#			$ggoffset,$igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,$igpick,$igonoff,$ignext,$imgsize,$img
#	'gs'	reference to array of optional selected image data:
#			$ggoffset,$igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,$igpick,$igonoff,$ignext,$imgsize,$img
#	'dt'	reference to array of optional defaulttool data:
#			$dtoffset,$dt
#	'tt'	reference to array of optional tooltype data:
#			$ttoff,$ttcnt,\@tt
#	'ni1'	reference to array of optional newicon data, unselected image:
#			@ni1
#	'ni2'	reference to array of optional newicon data, selected image:
#			@ni2
#	'ci'	reference to array of optional coloricon data:
#			$cioff,$ci
# or undef on error 

sub ParseInfo($$) {
	my $filename = shift;
	my $nowarn = shift;
	local(*IN);
	if (!open(IN,$filename)) {
		warn "$filename:$!";
		return undef;
	}
	my($size,@tt);
	binmode IN;			# permit cr/lf transation under M$
	$size = (stat(IN))[7];
	if ($size != read(IN,$_,$size)) {
		warn "$filename:$!";
		close(IN);
		return undef;
	}
	close(IN);
	my %res;
	my $fullsize = $size;
	# decode structure DiskObject (workbench.i)
	if ($size < 0x4e) {
		$nowarn or warn "$filename: file too small ($size)";
		return undef;
	}
	my (	$magic,$version,$ggnext,$ggleft,$ggtop,$ggwidth,$ggheight,$ggflags,
		$ggacti,$ggtype,$gggadget,$ggselect,$ggtext,$ggmutual,$ggspecial,$ggid,$gguser,
		$type,$pad,$defaulttool,$tooltypes,$currentx,$currenty,$drawerdata,$toolwindow,$stacksize
	) = unpack('n n N n n n n n n n N N N N N n N C C N N N N N N N',$_);
	if ($magic != 0xe310) {
		$nowarn or warn "$filename: magic mismatch ($magic)";
		return undef;
	}
	if ($version != 1) {
		warn "$filename: version mismatch ($version)";
		return undef;
	}
	$currentx == 0x80000000 and $currentx = 'nopos';
	$currenty == 0x80000000 and $currenty = 'nopos';
	$res{'do'} = [$magic,$version,$ggnext,$ggleft,$ggtop,$ggwidth,$ggheight,$ggflags,
		$ggacti,$ggtype,$gggadget,$ggselect,$ggtext,$ggmutual,$ggspecial,$ggid,$gguser,
		$type,$pad,$defaulttool,$tooltypes,$currentx,$currenty,$drawerdata,$toolwindow,$stacksize];
	$_ = substr($_,0x4e);
	$size -= 0x4e;
	if ($drawerdata) {
		# decode structure DrawerData (workbench.i) which includes NewWindow (intuition.i)
		my (	$nwleft,$nwtop,$nwwidth,$nwheight,$nwdpen,$nwbpen,$nwidcmp,$nwflags,$nwgadget,$nwcheck,$nwtitle,
			$nwscreen,$nwbitmap,$nwminwidth,$nwminheight,$nwmaxwidth,$nwmaxheight,$nwtype,$ddx,$ddy
		) = unpack('n n n n c c N N N N N N N n n n n n N N',$_);
		$ddx = unpack('s',pack('S',$ddx));	# convert to unsigned
		$ddy = unpack('s',pack('S',$ddy));	# convert to unsigned
		$res{'dd'} = [$fullsize-$size,$nwleft,$nwtop,$nwwidth,$nwheight,$nwdpen,$nwbpen,$nwidcmp,$nwflags,$nwgadget,$nwcheck,$nwtitle,
			$nwscreen,$nwbitmap,$nwminwidth,$nwminheight,$nwmaxwidth,$nwmaxheight,$nwtype,$ddx,$ddy];
		$_ = substr($_,56);
		$size -= 56;
	}
	if ($gggadget) {
		# decode structure Image (intuition.i)
		my ($igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,$igpick,$igonoff,$ignext) = unpack('n n n n n N c c N',$_);
		$igdepth = unpack('s',pack('S',$igdepth));	# convert to unsigned
		my($imgsize) = int(($igwidth+15)/16)*2 * $igheight * $igdepth;
		$res{'gg'} = [$fullsize-$size,$igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,$igpick,$igonoff,$ignext,$imgsize,substr($_,20,$imgsize)];
		$_ = substr($_,20+$imgsize);
		$size -= 20+$imgsize;
	}
	if ($ggselect) {
		# decode structure Image (intuition.i)
		my ($igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,$igpick,$igonoff,$ignext) = unpack('n n n n n N c c N',$_);
		$igdepth = unpack('s',pack('S',$igdepth));	# convert to unsigned
		my($imgsize) = int(($igwidth+15)/16)*2 * $igheight * $igdepth;
		$res{'gs'} = [$fullsize-$size,$igleft,$igtop,$igwidth,$igheight,$igdepth,$igdata,$igpick,$igonoff,$ignext,$imgsize,substr($_,20,$imgsize)];
		$_ = substr($_,20+$imgsize);
		$size -= 20+$imgsize;
	}
	if ($defaulttool) {
		my ($dtlen,$dt) = unpack('N Z*',$_);
		$res{'dt'} = [$fullsize-$size,$dt];
		$_ = substr($_,4 + $dtlen);
		$size -= 4 + $dtlen;
	}
	my (@ni1,@ni2);
	if ($tooltypes) {
		my ($ttlen,$tt,$i);
		my ($ttoff) = $fullsize-$size;
		my ($ttcnt) = unpack('N',$_) /4 -1;
		$_ = substr($_,4);
		$size -= 4;
		$i = 0;
		while ($i != $ttcnt) {
			($ttlen,$tt) = unpack('N Z*',$_);
			$ttlen != length($tt) + 1 and warn "$filename: tooltype length mismatch, $ttlen != " . length($tt) + 1;
			$_ = substr($_,4 + $ttlen);
			$size -= 4 + $ttlen;
			if ($tt =~ /^IM1=/) {
				push @ni1,substr($tt,4);
			} elsif ($tt =~ /^IM2=/) {
				push @ni2,substr($tt,4);
			} elsif ($tt !~ /\*\*\* DON\'T EDIT THE FOLLOWING LINES!! \*\*\*/ and $tt !~ /^\s*$/) {
				push @tt,$tt;
			}
			$i++;
		}
		$res{'tt'} = [$ttoff,$ttcnt,\@tt];
 	}
 	if (@ni1) {
		$res{'ni1'} = \@ni1;
	}
 	if (@ni2) {
		$res{'ni2'} = \@ni2;
	}
	if ($drawerdata and $gguser & 1) {
		# decode structure DrawerData2 (workbench.i)
		my ($dd2flags,$dd2vm) = unpack('N n',$_);
		$res{'dd2'} = [$fullsize-$size,$dd2flags,$dd2vm];
		$_ = substr($_,6);
		$size -= 6;
	}
	if ($size) {
		if (substr($_,0,4) eq 'FORM') {
			# color icon data in iff structure
			my ($cioff) = $fullsize-$size;
			my ($id,$len) = unpack('N N',$_);
			$res{'ci'} = [$cioff,substr($_,0,8+$len)];
			$_ = substr($_,8+$len);
			$size -= 8+$len;
		}
	}
	if ($size) {
		warn sprintf("$filename: size=$size should be zero! offset=%x",$fullsize-$size);
		hexdump(substr($_,0,16))
	}
	return \%res;
}

# parse newicon data
# arguments:
#	newicon data as array of strings from the tooltypes without 'IM[12]='
# returns reference to hash of keys:
#	'tr'	transparency = 0|1
#	'wid'	width = 1..93
#	'hei'	height = 1..93
#	'cc'	color count = 0..x
#	'cd'	color data = 8bit rgb
#	'de'	depth, correlates to cc
#	'id'	image data = chunky picture 8bit per pixel
# or undef on error

sub ParseNewIcon($) {
	my %r = ();
	my @n = @{shift(@_)};
	if (! ($n[0] =~ s/^(.)(.)(.)(.)(.)//)) {
		warn "ParseNewIcon: header invalid";
		return undef;
	}
	if ($1 eq 'B') {
		$r{'tr'} = 0;
	} elsif ($1 eq 'C') {
		$r{'tr'} = 1;
	} else {
		warn "ParseNewIcon: transparency invalid";
		return undef;
	}
	$r{'wid'} = ord($2) - 0x21;
	$r{'hei'} = ord($3) - 0x21;
	my $cols = $r{'cc'} = ((ord($4) - 0x21) << 6) + (ord($5) - 0x21);
	my $depth = 0; $_ = $cols - 1; while ($_) { $depth++; $_ >>= 1 }; $r{'de'} = $depth;
	my $imask = 0; $_ = $depth; while ($_) { $_--; $imask <<= 1; $imask++ }
	$cols *= 3;	# rgb, 3 byte per color
	# print "trans=$r{'tr'} w=$r{'wid'} h=$r{'hei'} cols=$cols depth=$depth imask=$imask\n";
	my ($l,@d,$c,@cols,@img,$bb,$bc);
	foreach $l (@n) {
		# decode a tooltype line into 7-bit values in array @d
		@d = ();
		foreach $c (unpack("C*",$l)) {
			if ($c < 0x20 or ($c > 0x6f and $c < 0xa1)) {
				warn "ParseNewIcon: invalid data byte $c";
				return undef;
			} elsif ($c < 0xa1) {
				push @d,$c - 0x20;
			} elsif ($c < 0xd1) {
				push @d,$c - 0xa1 + 0x50;
			} else {
				$c -= 0xd0; while ($c--) { push @d,0 }
			}
		}
		# print "c=$cols \@d=" . int(@d) . "\n";
		# concatenate the 7-bit values and write colors and image data
		$bb = 0;	# bit buffer
		$bc = 0;	# bits stored in bit buffer actual
		foreach $c (@d) {
			$bb <<= 7; $bb += $c; $bc += 7;
			if ($cols) {
				if ($bc >= 8) {
					push @cols,($bb >> ( $bc - 8 )) & 0xff;
					$bc -= 8;
					$cols--;
					$cols or @d = ();	# image data always starts in new line
				}
			} else {
				while ($bc >= $depth) {
					push @img,($bb >> ( $bc - $depth )) & $imask;
					$bc -= $depth;
				}
			}
		}
	}
	$r{'cd'} = pack("C*",@cols);
	$r{'id'} = pack("C*",@img);
	return \%r;
}

# parse OS3.5 color icon data
# arguments:
#	color icon data as single string
# returns reference to hash of keys:
#	'fl'	flags = 0|1 (bit #0 frameless)
#	'wid'	width = 1..n
#	'hei'	height = 1..n
#	'ax'	aspect x = 0..15
#	'ay'	aspect y = 0..15
#	'cc1','cc2'	color count = 1..n
#	'ct1','ct2'	transparent color = n, -1 if transparency is unused
#	'cd1','cd2'	color data = 8bit rgb
#	'de1','de2'	depth
#	'id1','id2'	image data = chunky picture 8bit per pixel
# or undef on error

sub ParseColIcon($) {
	my %r = ();
	my $d = shift @_;
	my ($form,$folen,$icon,$face,$falen,$width,$height,$flags,$aspect,$maxpal) = unpack('A4 N A4 A4 N C C C C n',$d);
	if ($form ne 'FORM' or $folen != length($d)-8 or $icon ne 'ICON' or $face ne 'FACE' or $falen != 6) {
		warn "ParseColIcon: header invalid";
		hexdump(substr($d,0,12+14));
		return undef;
	}
	$width++; $height++;	# stored - 1
	$r{'wid'} = $width;
	$r{'hei'} = $height;
	$r{'fl'} = $flags;
	$r{'ax'} = $aspect >> 4;
	$r{'ay'} = $aspect & 15;
	# print "folen=$folen icon=$icon face=$face falen=$falen width=$width height=$height flags=$flags aspect=$aspect maxpal=$maxpal\n";
	$d = substr($d,26);
	foreach my $i (1..2) {
		length($d) or next;	# skip if second frame is missing
		my ($imag,$imlen,$trans,$cols,$flags,$if,$pf,$depth,$ilen,$plen) = unpack('A4 N C C C C C C n n',$d);
		if ($imag ne 'IMAG' or $imlen > length($d)-8) {
			warn "ParseColIcon: image header$i invalid";
			hexdump(substr($d,0,18));
			return undef;
		}
		($flags & 2) and $cols++; $ilen++; $plen++;		# stored - 1
		$r{"cc$i"} = $cols;
		$r{"ct$i"} = $flags & 1 ? $trans : -1;	# transparent color
		$r{"de$i"} = $depth;
		# print "imlen=$imlen trans=$trans cols=$cols flags=$flags if=$if pf=$pf depth=$depth ilen=$ilen plen=$plen\n";
		$d = substr($d,18);
		if ($if) {
			# run-length compressed image data
			my (@d,$r,$y,$c,@img,$bb,$bc);
			my $imask = 0; $_ = $depth; while ($_) { $_--; $imask <<= 1; $imask++ }
			# print "imask=$imask\n";
			# decode image data and write to array @img
			$r = 0; $y = 0;
			$bb = 0;	# bit buffer
			$bc = 0;	# bits stored in bit buffer actual
			foreach $c (unpack("C*",substr($d,0,$ilen))) {
				warn "decompression bit count gt > 16" unless $bc < 16;
				$bb <<= 8; $bb += $c; $bc += 8;
				if (!$y and !$r) {			# new mode
					$_ = ($bb >> ( $bc - 8 )) & 0xff; $bc -= 8;
					if ($_ < 0x80) {		# copy the next $y chars
						$y = $_ + 1;
					} elsif ($_ > 0x80) {		# repeat the next char $r times
						$r = 256 - $_ + 1;
					} else {
						warn '0x80 in decompress';
					}
				}
				if ($r and $bc >= $depth) {		# repeat
					push @img,(($bb >> ( $bc - $depth )) & $imask) x $r;
					$bc -= $depth;
					$r = 0;
				}
				while ($y and $bc >= $depth) {		# copy
					push @img,($bb >> ( $bc - $depth )) & $imask;
					$bc -= $depth;
					$y--;
				}
			}
			$r{"id$i"} = pack("C*",@img);
		} else {
			# uncompressed image data
			$r{"id$i"} = substr($d,0,$ilen);
		}
		if (length($r{"id$i"}) != $width*$height) {
			warn "ParseColIcon: wrong image$i data length (got " . length($r{"id$i"}) . " expected " . $width*$height . ")";
			return undef;
		}
		$d = substr($d,$ilen);
		if ($flags & 2) {	# second palette is optional, when missing using first one
			if ($pf) {
				# run-length compressed palette data
				my (@d,$r,$y,$c);
				$r = 0; $y = 0;
				foreach $c (unpack("C*",substr($d,0,$plen))) {
					if ($r) {		# repeat
						push @d,($c) x $r;
						$r = 0;
					} elsif ($y) {		# copy
						push @d,$c;
						$y--;
					} elsif ($c < 0x80) {	# copy the next $y chars
						$y = $c + 1;
					} elsif ($c > 0x80) {	# repeat the next char $r times
						$r = 256 - $c + 1;
					}
				}
				$r{"cd$i"} = pack("C*",@d);
			} else {
				# uncompressed palette data
				$r{"cd$i"} = substr($d,0,$plen);
			}
			if (length($r{"cd$i"}) != $cols * 3) {
				warn "ParseColIcon: wrong color$i data length (got " . length($r{"cd$i"}) . " expected " . $cols*3 . ")";
				return undef;
			}
			$d = substr($d,$plen);
		} else {
			$r{"cd$i"} = $r{"cd1"}; 
		}
		$imlen & 1 and $d = substr($d,1);	# size word aligned
	}
	return \%r;
}

sub hexdump {
    my $offset = 0;
    my(@array,$format);
    foreach my $data (unpack("a16"x(length($_[0])/16)."a*",$_[0])) {
        my($len)=length($data);
        if ($len == 16) {
            @array = unpack('N4', $data);
            $format="0x%08x (%05d)   %08x %08x %08x %08x   %s\n";
        } else {
            @array = unpack('C*', $data);
            $_ = sprintf "%2.2x", $_ for @array;
            push(@array, '  ') while $len++ < 16;
            $format="0x%08x (%05d)" .
               "   %s%s%s%s %s%s%s%s %s%s%s%s %s%s%s%s   %s\n";
        } 
        $data =~ tr/\0-\37\177-\377/./;
        printf $format,$offset,$offset,@array,$data;
        $offset += 16;
    }
}

1;
