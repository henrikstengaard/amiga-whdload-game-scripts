# Update WHDLoad Installs
# -----------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-02
#
# A PowerShell script to update whdload installs.

$whdloadGamesPath = "whdownload_games"
$whdloadInstallsPath = "whdload_installs"

$sevenZipPath = "c:\Program Files\7-Zip\7z.exe"

$tempPath = [System.IO.Path]::GetFullPath("temp")

# Get archive files using list function in 7-zip
function GetArchiveFiles($archivePath)
{
	$output = & $sevenZipPath l $archivePath
	
	return $output | Select-String -Pattern "^([^\s]+)\s+([^\s]+)\s+([^\s\d]+)\s+([\d]+)\s+([\d]+)\s+(.+)\s*$" -AllMatches | % { $_.Matches } | 
		% { New-Object psobject –Prop @{ "Date" = $_.Groups[1].Value; "Time" = $_.Groups[2].Value; "Attr" = $_.Groups[3].Value; "Size" = $_.Groups[4].Value; "Compressed" = $_.Groups[5].Value; "Name" = $_.Groups[6].Value -replace "/", "\" } }
}

function UpdateWhdloadGameWithWhdloadInstall($whdloadGamePath, $whdloadInstallPath, $updatedWhdloadGamePath)
{
	if(Test-Path -Path $tempPath)
	{
		Remove-Item $tempPath -recurse
	}
	
	md $tempPath | Out-Null


	# 1. Get first slave file from whdload game
	$firstWhdloadGameSlaveFile = GetArchiveFiles $whdloadGamePath | Where { $_ -match "[^\\\.]+\.slave" } | Select-Object -first 1

	if (!$firstWhdloadGameSlaveFile)
	{
		Write-Error "No slaves exists in whdload game '$whdloadGamePath'"
		return $false
	}
	
	$whdloadGameSlavePath = [System.IO.Path]::GetDirectoryName($firstWhdloadGameSlaveFile.Name)


	# 2. Create whdload game update directory
	$whdloadGameUpdatePath = [System.IO.Path]::Combine($tempPath, $whdloadGameSlavePath)
	
	if(!(Test-Path -Path $whdloadGameUpdatePath))
	{
		md $whdloadGameUpdatePath | Out-Null
	}		
	
	
	# 3. Create temp whdload install directory
	$tempWhdloadInstallPath = [System.IO.Path]::Combine($tempPath, "whdload_install")
	
	if(!(Test-Path -Path $tempWhdloadInstallPath))
	{
		md $tempWhdloadInstallPath | Out-Null
	}		
	
	
	# 4. Extract whdload install to temp whdload install directory
	$extractInstallArgs = "x ""$whdloadInstallPath"" -aoa"
	$extractInstallProcess = Start-Process $sevenZipPath $extractInstallArgs -WorkingDirectory $tempWhdloadInstallPath -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul | Out-Null
	
	if ($extractInstallProcess.ExitCode -gt 0)
	{
		Write-Error "Failed to extract whdload install from path '$whdloadInstallPath'"
		return $false
	}

	
	# 5. Get first slave file from temp whdload install path
	$firstWhdloadInstallFile = Get-ChildItem -recurse -Path $tempWhdloadInstallPath -filter "*.slave" | Select-Object -first 1

	if (!$firstWhdloadInstallFile)
	{
		Write-Error "No slaves exists in whdload install path '$tempWhdloadInstallPath'"
		return $false
	}
	
	$whdloadInstallSlavePath = $firstWhdloadInstallFile.DirectoryName
	
	
	# 6. Copy whdload install files to whdload game update path
	Copy-Item $whdloadInstallSlavePath\*.* -Destination $whdloadGameUpdatePath -Recurse

	
	# 7. Copy whdload game to update location
	Copy-Item $whdloadGamePath $updatedWhdloadGamePath -force


	# 8. Delete existing slaves in whdload game archive
	$deleteSlavesArgs = "d ""$updatedWhdloadGamePath"" *.slave -r"
	$deleteSlavesProcess = Start-Process $sevenZipPath $deleteSlavesArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul | Out-Null

	if ($deleteSlavesProcess.ExitCode -gt 0)
	{
		Write-Error "Failed to delete slaves from path '$updatedWhdloadGamePath'"
		return $false
	}

		
	# 9. Add whdload install files from install archive to same directory as old slaves
	$addWhdloadInstallArgs = "a ""$updatedWhdloadGamePath"" $whdloadGameSlavePath\*.* -r"
	$addWhdloadInstallProcess = Start-Process $sevenZipPath $addWhdloadInstallArgs -WorkingDirectory $tempPath -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul | Out-Null

	if ($addWhdloadInstallProcess.ExitCode -gt 0)
	{
		Write-Error "Failed to add temp whdload install files"
		return $false
	}
	
	return $true
}

function MakeComparable($name)
{
	return $name.Replace("&", "and").Replace("-", "").ToLower()
}

function MakeKeywords($name)
{
}

function BuildWhdloadInstallIndex($whdloadInstallIndexPath, $whdloadInstallFiles)
{
	if(!(test-path -path $whdloadInstallIndexPath))
	{
		Add-Content $whdloadInstallIndexPath "Whdload Install File;Whdload Install Name"
	}	

	ForEach ($whdloadInstallFile in $whdloadInstallFiles)
	{
		$whdloadInstallFileName = [System.IO.Path]::GetFileName($whdloadInstallFile)

		if (Get-Content $whdloadInstallIndexPath | Select-String -Pattern $whdloadInstallFileName)
		{
			continue;
		}
	
		if(test-path -path $tempPath)
		{
			remove-item $tempPath -recurse
		}
		
		md $tempPath | out-null

		# 4. Extract whdload install to temp whdload install directory
		$extractInstallArgs = "x ""$whdloadInstallFile"" -aoa"
		$extractInstallProcess = Start-Process $sevenZipPath $extractInstallArgs -WorkingDirectory $tempPath -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul | Out-Null
		
		if ($extractInstallProcess.ExitCode -gt 0)
		{
			Add-Content $whdloadInstallIndexPath "$whdloadInstallFileName;FAILED TO EXTRACT"
			continue
		}

		# 2. Get whdload install files
		$readmeFile = Get-ChildItem -recurse -Path $tempPath\* -include readme,*.readme | Select-Object -first 1
		
		if (!$readmeFile)
		{
			Add-Content $whdloadInstallIndexPath "$whdloadInstallFileName;NO README"
			continue
		}
		
		$whdloadInstallName = Get-Content $readmeFile.FullName | Select-String -Pattern  """([^""]+)""" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
		
		if (!$whdloadInstallName)
		{
			Add-Content $whdloadInstallIndexPath "$whdloadInstallFileName;NO WHDLOAD INSTALL NAME"
			continue
		}

		Write-Host $whdloadInstallName
		
		Add-Content $whdloadInstallIndexPath "$whdloadInstallFileName;$whdloadInstallName"
	}	

	return $true
}

function FindWhdloadInstallForWhdloadGame($whdloadGameFiles, $whdloadInstallFiles)
{
	$comparableWhdloadInstalls = @{}

	ForEach ($whdloadInstallFile in $whdloadInstallFiles)
	{
		# extract readme to temp
		
		# regex to get name "this patch applies to "
	
	
		$comparableWhdloadInstallName = MakeComparable ([System.IO.Path]::GetFileNameWithoutExtension($whdloadInstallFile))
		
		$comparableWhdloadInstalls.Set_Item($comparableWhdloadInstallName, $whdloadInstallFile)
	}
	
	$count = 0;
	
	ForEach ($whdloadGameFile in $whdloadGameFiles)
	{
		$whdloadGameFileName = [System.IO.Path]::GetFileNameWithoutExtension($whdloadGameFile)
		
		$whdloadGameSegments = $whdloadGameFileName -split "_"

		$comparableWhdloadGameName = MakeComparable $whdloadGameSegments[0]
		
		if ($comparableWhdloadInstalls.ContainsKey($comparableWhdloadGameName))
		{
			$whdloadInstallFile = $comparableWhdloadInstalls.Get_Item($comparableWhdloadGameName)

			#Write-Host "Found '$whdloadInstallFile'"
		}
		else
		{
			# split into keywords (letters only) and compare
		
			$count++
			Write-Host "No whdload install found for '$whdloadGameFileName'!"
		}
	}
	
	Write-Host $count
}


# 1. Get whdload game files
#$whdloadGameFiles = Get-ChildItem -recurse -Path $whdloadGamesPath -exclude *.html -File

# 2. Get whdload install files
#$whdloadInstallFiles = Get-ChildItem -recurse -Path $whdloadInstallsPath -exclude *.html -File

# 3. Build whdload install index
#BuildWhdloadInstallIndex "whdload_install_index.csv" $whdloadInstallFiles

# 3. Connect whdload game and whdload install
#FindWhdloadInstallForWhdloadGame $whdloadGameFiles $whdloadInstallFiles


function ReadLittleEndianShort($bytes, $offset)
{
	# $shortBytes = $stream.ReadBytes(2)
	# [array]::Reverse($shortBytes)
	# return [System.BitConverter]::ToInt16($shortBytes, 0)

	$shortBytes = New-Object byte[](2);
	[Array]::Copy($bytes, $offset, $shortBytes, 0, 2);
	[Array]::Reverse($shortBytes)
	return [System.BitConverter]::ToInt16($shortBytes, 0)
}

function ReadLittleEndianLong($bytes, $offset)
{
	# $shortBytes = $stream.ReadBytes(4)
	# [array]::Reverse($shortBytes)
	# return [System.BitConverter]::ToInt32($shortBytes, 0)
	
	$longBytes = New-Object byte[](4);
	[Array]::Copy($bytes, $offset, $longBytes, 0, 4);
	[Array]::Reverse($longBytes)
	return [System.BitConverter]::ToInt32($longBytes, 0)
}

function ReadStringWithLength($bytes, $offset, $length)
{
	# $shortBytes = $stream.ReadBytes(2)
	# [array]::Reverse($shortBytes)
	# return [System.BitConverter]::ToInt16($shortBytes, 0)

	$stringBytes = New-Object byte[]($length)
	[Array]::Copy($bytes, $offset, $stringBytes, 0, $length)
	return [System.Text.Encoding]::ASCII.GetString($stringBytes)
}

function ReadString($bytes, $offset)
{
	if ($offset -eq 0)
	{
		return ""
	}

	For ($length = 0; $length -lt $headerBytes.length; $length++)
	{
		if ($headerBytes[$offset + $length] -eq 0)
		{
			break
		}
	}

	return ReadStringWithLength $headerBytes $offset $length
}

function ReadChar($bytes, $offset)
{
	return [Convert]::ToChar($bytes[$offset])
}

function ReadSlave()
{
}


$slavePath = "c:\Work\First Realize\amiga-whdload-game-scripts\temp\ZynapsHD\Zynaps.slave"

$bytes = [System.IO.File]::ReadAllBytes($slavePath)

$size = (Get-Item $slavePath).length

#$slaveStream = New-Object IO.FileStream($slavePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
$slaveStream = New-Object System.IO.BinaryReader([System.IO.File]::Open($slavePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))

$headerOffset = 0x020;
$headerLength = $size - $headerOffset;

# seek header offset
$slaveStream.BaseStream.Seek($headerOffset, [System.IO.SeekOrigin]::Begin)

$headerBytes = New-Object byte[]($headerLength);

if ($headerLength -ne $slaveStream.Read($headerBytes, 0, $headerLength))
{
	Write-Error "failed to read header"
}

$slaveStream.Close()


$security = ReadLittleEndianLong $headerBytes 0
$id = ReadStringWithLength $headerBytes 4 8
$version = ReadLittleEndianShort $headerBytes 12
$flagsValue = ReadLittleEndianShort $headerBytes 14
$baseMemSize = ReadLittleEndianLong $headerBytes 16
$execInstall = ReadLittleEndianLong $headerBytes 20
$gameLoader = ReadLittleEndianShort $headerBytes 24
$currentDirOffset = ReadLittleEndianShort $headerBytes 26
$dontCacheOffset = ReadLittleEndianShort $headerBytes 28
$keyDebug = $headerBytes[30]
$keyExit = $headerBytes[31]
$expMem = ReadLittleEndianLong $headerBytes 32
$nameOffset = ReadLittleEndianShort $headerBytes 36
$copyOffset = ReadLittleEndianShort $headerBytes 38
$infoOffset = ReadLittleEndianShort $headerBytes 40
$kickname = ReadLittleEndianShort $headerBytes 42
$kicksize = ReadLittleEndianLong $headerBytes 44
$kickcrc = ReadLittleEndianShort $headerBytes 48
$configOffset = ReadLittleEndianShort $headerBytes 50

# return, if id doesn't match
if ($id -eq 'WHDLOADS')
{
	Write-Error "Failed to read header: Id mismatch '$id'"
	#return
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

$currentDir = ReadString $headerBytes $currentDirOffset
$dontCache = ReadString $headerBytes $dontCacheOffset

Write-Host "Size = '$size'"
Write-Host "Date = ''"
Write-Host "Version: '$version'"
Write-Host "Flags = '$flags'"
Write-Host "ExecInstall = '$execInstall'"
Write-Host "ExecInstall = '$execInstall'"
Write-Host "GameLoader = '$gameLoader'"
Write-Host "CurrentDir = '$currentDir'"
Write-Host "DontCache = '$dontCache'"

if ($version -ge 4)
{
	Write-Host "KeyDebug = '$([String]::Format("{0:x}", $keyDebug))'"
	Write-Host "KeyExit = '$([String]::Format("{0:x}", $keyExit))'"
}
if ($version -ge 8)
{
	Write-Host "ExpMem = '$expMem'"
} 
if ($version -ge 10)
{
	$name = ReadString $headerBytes $nameOffset
	$copy = ReadString $headerBytes $copyOffset
	$info = ReadString $headerBytes $infoOffset
	Write-Host "Name = '$name'"
	Write-Host "Copy = '$copy'"
	Write-Host "Info = '$info'"
}
if ($version -ge 17)
{
	$config = ReadString $headerBytes $configOffset
	Write-Host "Config = '$config'"
}


# # seek header offset
# $slaveStream.BaseStream.Seek($currentDir, [System.IO.SeekOrigin]::Begin)

# [System.Text.Encoding]::UTF8.GetString($slaveStream.ReadBytes(8))
#$versionBytes = $slaveStream.ReadBytes(2)


#[System.Text.Encoding]::UTF8.GetString($idBytes)

#[array]::Reverse($versionBytes)

#[System.BitConverter]::ToInt16($versionBytes, 0)


  # $Security = 0;	# avoid warnings
  # ($Security,$ID,$Version,$Flags,$BaseMemSize,$ExecInstall,$GameLoader,
  # $CurrentDir,$DontCache,$keydebug,$keyexit,$ExpMem,$name,$copy,$info,
  # $kickname,$kicksize,$kickcrc,$config) =
  # unpack('N a8 n n N N n n n c c N n n n n N n n',$_);
  # if ($ID ne 'WHDLOADS') {
    # warn "$filename: id mismatch ('$ID')";
    # return;
  # }






# 4. Update whdload game with whdload install

#UpdateWhdloadGameWithWhdloadInstall "c:\Work\First Realize\amiga-whdload-game-scripts\whdownload_games\S\SlamTilt_v3.5_AGA_1151.zip" "c:\Work\First Realize\amiga-whdload-game-scripts\whdload_installs\installs\SlamTilt.lha" "c:\Work\First Realize\amiga-whdload-game-scripts\new_SlamTilt.zip"