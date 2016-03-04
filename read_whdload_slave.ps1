# Read WHDLoad Slave
# ------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-04
#
# A PowerShell script to read and print whdload slave information.

Param(
	[Parameter(Mandatory=$true)]
	[string]$path
)

# read little endian unsigned short from offset in bytes
function ReadLittleEndianUnsignedShort($bytes, $offset)
{
	$shortBytes = New-Object byte[](2);
	[Array]::Copy($bytes, $offset, $shortBytes, 0, 2);
	[Array]::Reverse($shortBytes)
	return [System.BitConverter]::ToUInt16($shortBytes, 0)
}

# read little endian unsigned long from offset in bytes
function ReadLittleEndianUnsignedLong($bytes, $offset)
{
	$longBytes = New-Object byte[](4);
	[Array]::Copy($bytes, $offset, $longBytes, 0, 4);
	[Array]::Reverse($longBytes)
	return [System.BitConverter]::ToUInt32($longBytes, 0)
}

# read a string with fixed length from offset in bytes
function ReadStringWithLength($bytes, $offset, $length)
{
	$stringBytes = New-Object byte[]($length)
	[Array]::Copy($bytes, $offset, $stringBytes, 0, $length)
	return [System.Text.Encoding]::ASCII.GetString($stringBytes)
}

# read a string with variable length from offset in bytes
function ReadString($bytes, $offset)
{
	if ($offset -eq 0)
	{
		return ""
	}

	For ($length = 0; $length -lt $bytes.length; $length++)
	{
		if ($bytes[$offset + $length] -eq 0)
		{
			break
		}
	}

	return ReadStringWithLength $bytes $offset $length
}

# read and print whdload slave information
function ReadWhdloadSlave($whdloadSlavePath)
{
	# return false, if whdload slave path doesn't exist
	if (!(Test-Path -path $whdloadSlavePath))
	{
		Write-Error "File doesn't exist '$whdloadSlavePath'"
		return
	}

	$whdloadSlaveItem = (Get-Item $whdloadSlavePath)

	# get slave size
	$size = $whdloadSlaveItem.Length
	$date = $whdloadSlaveItem.CreationTime

	# header offset and calculate data length
	$headerOffset = 0x020;
	$dataLength = $size - $headerOffset;

	# array for data bytes
	$dataBytes = New-Object byte[]($dataLength);

	# open binary reader
	$binaryReader = New-Object System.IO.BinaryReader([System.IO.File]::Open($whdloadSlavePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))

	# seek header offset. Return false, if seek doesn't match header offset
	if ($binaryReader.BaseStream.Seek($headerOffset, [System.IO.SeekOrigin]::Begin) -ne $headerOffset)
	{
		Write-Error "Failed to seek header offset in '$whdloadSlavePath'"
		return
	}

	# read data bytes to array. Return false, if bytes read doesn't match data length
	if ($dataLength -ne $binaryReader.Read($dataBytes, 0, $dataLength))
	{
		Write-Error "Failed to read data from '$whdloadSlavePath'"
		return
	}

	# close binary reader
	$binaryReader.Close()

	# read header from data bytes
	$security = ReadLittleEndianUnsignedLong $dataBytes 0
	$id = ReadStringWithLength $dataBytes 4 8
	$version = ReadLittleEndianUnsignedShort $dataBytes 12
	$flagsValue = ReadLittleEndianUnsignedShort $dataBytes 14
	$baseMemSize = ReadLittleEndianUnsignedLong $dataBytes 16
	$execInstall = ReadLittleEndianUnsignedLong $dataBytes 20
	$gameLoader = ReadLittleEndianUnsignedShort $dataBytes 24
	$currentDirOffset = ReadLittleEndianUnsignedShort $dataBytes 26
	$dontCacheOffset = ReadLittleEndianUnsignedShort $dataBytes 28
	$keyDebug = $dataBytes[30]
	$keyExit = $dataBytes[31]
	$expMem = ReadLittleEndianUnsignedLong $dataBytes 32
	$nameOffset = ReadLittleEndianUnsignedShort $dataBytes 36
	$copyOffset = ReadLittleEndianUnsignedShort $dataBytes 38
	$infoOffset = ReadLittleEndianUnsignedShort $dataBytes 40
	$kicknameOffset = ReadLittleEndianUnsignedShort $dataBytes 42
	$kicksize = ReadLittleEndianUnsignedLong $dataBytes 44
	$kickcrc = ReadLittleEndianUnsignedShort $dataBytes 48
	$configOffset = ReadLittleEndianUnsignedShort $dataBytes 50

	# return false, if id is not valid
	if ($id -ne 'WHDLOADS')
	{
		Write-Error "Failed to read header: Id is not valid '$id'"
		return
	}

	# add flags enum type
	Add-Type -TypeDefinition @"
	[System.Flags]
	public enum FlagsEnum
	{
		Disk = 1,
		NoError = 2,
		EmulTrap = 4,
		NoDivZero = 8,
		Req68020 = 16,
		ReqAGA = 32,
		NoKbd = 64,
		EmulLineA = 128,
		EmulTrapV = 256,
		EmulChk = 512,
		EmulPriv = 1024,
		EmulLineF = 2048,
		ClearMem = 4096,
		Examine = 8192,
		EmulDivZero = 16384,
		EmulIllegal = 32768
	}
"@

	# convert flags value to flags enum
	$flags = [FlagsEnum]$flagsValue

	$currentDir = ReadString $dataBytes $currentDirOffset
	$dontCache = ReadString $dataBytes $dontCacheOffset

	# print default information
	Write-Output "Size = '$size'"
	Write-Output "Date = '$date'"
	Write-Output "Version = '$version'"
	Write-Output "Flags = '$flags'"
	Write-Output "ExecInstall = '$execInstall'"
	Write-Output "GameLoader = '$gameLoader'"
	Write-Output "CurrentDir = '$currentDir'"
	Write-Output "DontCache = '$dontCache'"

	if ($version -ge 4)
	{
		# print key debug and exit information
		Write-Output "KeyDebug = '$([String]::Format("{0:x}", $keyDebug))'"
		Write-Output "KeyExit = '$([String]::Format("{0:x}", $keyExit))'"
	}
	if ($version -ge 8)
	{
		# print exp mem information
		Write-Output "ExpMem = '$expMem'"
	} 
	if ($version -ge 10)
	{
		# print name, copy and info information
		$name = ReadString $dataBytes $nameOffset
		$copy = ReadString $dataBytes $copyOffset
		$info = ReadString $dataBytes $infoOffset
		Write-Output "Name = '$name'"
		Write-Output "Copy = '$copy'"
		Write-Output "Info = '$info'"
	}
	if ($version -ge 16)
	{
		$kickstuff = ReadLittleEndianUnsignedShort $dataBytes $kicknameOffset
		
		if ($kickcrc -eq 0xffff)
		{
			# Need to find a slave file for testing!
		} 
		else
		{
			$kickname = ReadString $dataBytes $kicknameOffset
			Write-Output "Kickname = '$kickname'"
			Write-Output "Kicksize = '$kicksize'"
		}
		Write-Output "Kickcrc = '$kickcrc'"
	} 	
	if ($version -ge 17)
	{
		# print config information
		$config = ReadString $dataBytes $configOffset
		Write-Output "Config = '$config'"
	}
}

# read and print whdload slave information
ReadWhdloadSlave $path
