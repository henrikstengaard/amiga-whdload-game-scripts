#
# $Id: parseslave.pm 1.2 2011/07/31 17:21:01 wepl Exp wepl $
#
# read a WHDLoad Slave and return all infos from the Slave header
# 03.04.2010	extracted from chkslaves.pl
#		updated for WHDLoad Slaves v16
# 26.07.2011	updated for WHDLoad Slaves v17

#
# returns reference to array:
#	size of file
#	timestamp of file
#	version
#	flags value
#	flags text
#	basememsize
#	execinstall
#	gameloader
#	currentdir
#	dontcache
#	:v4+
#	keydebug
#	keyexit
#	:v8+
#	expmem
#	name
#	:v10+
#	copy
#	info
#	:v16+
#	kickname
#	kicksize
#	kickcrc
#	:v17+
#	config

sub ParseSlave ($) {
  my $filename = shift;
  my (@res,$size,$offset,$Security,$ID,$Version,$Flags,$sFlags,$BaseMemSize,
  	$ExecInstall,$GameLoader,$CurrentDir,$DontCache,$keydebug,$keyexit,
	$ExpMem,$name,$copy,$info,$kickname,$kicksize,$kickcrc,$config);
  local(*IN);
  if (!open(IN,$filename)) {
    warn "$filename:$!";
    return;
  }
  binmode IN;			# permit cr/lf transation under M$
  $size = (stat(IN))[7];
  push @res,$size;
  my @t = localtime((stat(IN))[8]);
  push @res,sprintf("%02d.%02d.%d %02d:%02d:%02d",$t[3],$t[4]+1,$t[5]+1900,$t[2],$t[1],$t[0]);
  $offset = 0x020;		# exe header
  if (seek(IN,$offset,0) != 1) {
    warn "$filename:$!";
    return;
  }
  if ($size-$offset != read(IN,$_,$size-$offset)) {
    warn "$filename:$!";
    return;
  }
  close(IN);
  #print "\n$filename loaded";
  $Security = 0;	# avoid warnings
  ($Security,$ID,$Version,$Flags,$BaseMemSize,$ExecInstall,$GameLoader,
  $CurrentDir,$DontCache,$keydebug,$keyexit,$ExpMem,$name,$copy,$info,
  $kickname,$kicksize,$kickcrc,$config) =
  unpack('N a8 n n N N n n n c c N n n n n N n n',$_);
  if ($ID ne 'WHDLOADS') {
    warn "$filename: id mismatch ('$ID')";
    return;
  }
  ($ExpMem) = unpack('l',pack('L',$ExpMem));
  my @flags = ('Disk','NoError','EmulTrap','NoDivZero','Req68020','ReqAGA',
	'NoKbd','EmulLineA','EmulTrapV','EmulChk','EmulPriv','EmulLineF','ClearMem',
	'Examine','EmulDivZero','EmulIllegal');
  my $lFlags = pack('V',$Flags);	# vec() works with little endian!
  my ($i,@vFlags);
  for ($i=0,@vFlags=();$i<16;$i++) {
    vec($lFlags,$i,1) == 1 and push @vFlags,$flags[$i];
  }
  $sFlags = join('|',@vFlags);
  $CurrentDir = &ParseSlaveGetString($CurrentDir);
  $DontCache = &ParseSlaveGetString($DontCache);
  push @res,($Version,$Flags,$sFlags,$BaseMemSize,$ExecInstall,$GameLoader,
	$CurrentDir,$DontCache);
  if ($Version >= 4) {
    push @res,($keydebug,$keyexit);
  }
  if ($Version >= 8) {
    push @res,($ExpMem);
  }
  if ($Version >= 10) {
    $name = &ParseSlaveGetString($name);
    $copy = &ParseSlaveGetString($copy);
    $info = &ParseSlaveGetString($info);
    push @res,($name,$copy,$info);
  }
  if ($Version >= 16) {
    if ($kickcrc == 0xffff) {
      @crc = @name = ();
      while (&ParseSlaveGetWord($kickname)) {
      	push @crc,&ParseSlaveGetWord($kickname);
	$kickname += 2;
	push @name,&ParseSlaveGetString(&ParseSlaveGetWord($kickname));
	$kickname += 2;
      }
      push @res,(join(" ",@name),$kicksize,join(' ',map sprintf("\$%04x",$_),@crc));
    } else {
      push @res,(&ParseSlaveGetString($kickname),$kicksize,sprintf("\$%04x",$kickcrc));
    }
  }
  if ($Version >= 17) {
    push @res, &ParseSlaveGetString($config);
  }
  return \@res;
}

sub ParseSlaveGetString {
  my $offset = shift;
  if ($offset) {
    return unpack("x$offset Z*",$_);
  } else {
    return 0;
  }
}

sub ParseSlaveGetWord {
  my $offset = shift;
  if ($offset) {
    return unpack("x$offset n",$_);
  } else {
    return 0;
  }
}

1;

