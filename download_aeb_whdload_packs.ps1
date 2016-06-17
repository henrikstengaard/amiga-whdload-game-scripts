# Download Amiga English Board WHDLoad Packs
# ------------------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-06-17
#
# A PowerShell script to download whdload packs from Amiga English Board ftp server.
# The script downloads games and demoes whdload packs, uncompress archives and copies whdload packs with update packs in combined folders.

# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

# output
$outputPath = [System.IO.Path]::Combine($scriptPath, "aeb_whdload_packs")

# aeb ftp server
$hostname = "grandis.nu"
$username = "ftp"
$password = "ftp"



# find 7-zip in program files
$sevenZipPath = Get-ChildItem $Env:ProgramFiles -recurse -filter "7z.exe" | %{ $_.FullName } | Select-Object -First 1

# find 7-zip in program files x86, if not found in program files
if (!$sevenZipPath)
{
	$sevenZipPath = Get-ChildItem ${Env:ProgramFiles(x86)} -recurse -filter "7z.exe" | %{ $_.FullName } | Select-Object -First 1
}

# Check if 7-zip is present, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}



Function MD5($text)
{
	$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	$utf8 = new-object -TypeName System.Text.UTF8Encoding
	return [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($text)))
}

Function GetFtpDirectory($hostname, $username, $password, $remotePath, $cachePath)
{
	$url = "ftp://$($hostname)$($remotePath)"
	$hash = MD5 $url
	$ftpDirectoryFile = [System.IO.Path]::Combine($cachePath, $hash)

	if (!(Test-Path -Path $ftpDirectoryFile))
	{
		Write-Host "Downloading ftp directory from '$url'..."

		# ftp request
		$ftpRequest = [System.Net.FtpWebRequest]::Create($url)
		$ftpRequest.Credentials = New-Object System.Net.NetworkCredential($username, $password)
		$ftpRequest.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails
		$ftpRequest.UseBinary = $false
		$ftpRequest.KeepAlive = $false

		# send ftp request
		$ftpResponse = $ftpRequest.GetResponse()
		
		# get response stream
		$responseStream = $ftpResponse.GetResponseStream()

		# Create a nice Array of the detailed directory listing
		$streamReader = New-Object System.IO.Streamreader $responseStream
		$ftpDirectory = $streamReader.ReadToEnd()
		$streamReader.Close()

		# Close the FTP connection so only one is open at a time
		$ftpResponse.Close()
		
		[System.IO.File]::WriteAllText($ftpDirectoryFile, $ftpDirectory, [System.Text.Encoding]::UTF8)

		Write-Host "Done"
	}
	else
	{
		$ftpDirectory = [System.IO.File]::ReadAllText($ftpDirectoryFile, [System.Text.Encoding]::UTF8)
	}
	
	$dirListing = $ftpDirectory -split [Environment]::NewLine
	
    # Remove first two elements ( . and .. ) and last element (\n)
    $dirListing = $dirListing[1..($dirListing.Length-2)] 

    # This array will hold the final result
    $files = @()

    # Loop through the listings
    foreach ($CurLine in $dirListing) {

        # Split line into space separated array
        $LineTok = ($CurLine -split '\ +')

        # Get the filename (can even contain spaces)
        $CurFile = $LineTok[8..($LineTok.Length-1)]

        # Figure out if it's a directory. Super hax.
        $DirBool = $LineTok[0].StartsWith("d")

        # Determine what to do next (file or dir?)
        If ($DirBool) {
            # Recursively traverse sub-directories
            #$files += ,(Get-FtpDirectory "$($Directory)$($CurFile)/")
        } Else {
            # Add the output to the file tree
            $files += ,"$($Directory)$($CurFile)"
        }
    }
    
    Return $files
}

Function DownloadFtpFile($hostname, $username, $password, $remotePath, $localPath)
{
	$url = "ftp://$($hostname)$($remotePath)"

	Write-Host "Downloading '$url' to '$localPath'..."

    # ftp request
    $ftpRequest = [System.Net.FtpWebRequest]::Create($url)
    $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($username, $password)
    $ftpRequest.Method = [System.Net.WebRequestMethods+FTP]::DownloadFile
    $ftpRequest.UseBinary = $true
    $ftpRequest.KeepAlive = $false

	# send ftp request
	$ftpResponse = $ftpRequest.GetResponse() 
 
	# get response stream
	$responseStream = $ftpResponse.GetResponseStream() 
	 
	# create local file
	$localFile = New-Object IO.FileStream ($localPath,[IO.FileMode]::Create) 
	[byte[]]$readBuffer = New-Object byte[] 4096 

	# download
	do{ 
		$readLength = $responseStream.Read($readBuffer,0,4096) 
		$localFile.Write($readBuffer,0,$readLength) 
	} 
	while ($readLength -ne 0) 

	$responseStream.Close()
    $ftpResponse.Close()
	$localFile.close() 
	
	Write-Host "Done"
}

function GetFtpFile($hostname, $username, $password, $remotePath, $localPath)
{
	if (Test-Path -Path $localPath)
	{
		return
	}
	
	DownloadFtpFile $hostname $username $password $remotePath $localPath
}

function UncompressFile($archiveFile)
{
	$workingDirectory = [System.IO.Path]::GetDirectoryName($archiveFile)
	Write-Host "Uncompressing file '$archiveFile' to directory '$workingDirectory'..."
	
	# extract using 7-zip
	$sevenZipExtractInstallArgs = "x ""$archiveFile"" -aoa"
	$sevenZipExtractInstallProcess = Start-Process $sevenZipPath $sevenZipExtractInstallArgs -WorkingDirectory $workingDirectory -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

	# write error, if 7-zip extract fails
	if ($sevenZipExtractInstallProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to extract '$archiveFile'"
		exit 1
	}

	Write-Host "Done"
}

# get archive files using list function in 7-zip
function GetArchiveFiles($archivePath)
{
	$output = & $sevenZipPath l $archivePath

	return $output | Select-String -Pattern "^([^\s]+)\s+([^\s]+)\s+([^\s\d]+)\s+([\d]+)\s+([\d]+)\s+(.+)\s*$" -AllMatches | `
	% { $_.Matches } | `
	% { @{ "Date" = $_.Groups[1].Value; "Time" = $_.Groups[2].Value; "Attr" = $_.Groups[3].Value; "Size" = $_.Groups[4].Value; "Compressed" = $_.Groups[5].Value; "Name" = $_.Groups[6].Value -replace "/", "\" } }
}



function CombineArchiveFiles($archiveFile)
{
	$directoryName = GetArchiveFiles $archiveFile | Select-Object -First 1 | % { $_.Name } | Select-String -Pattern '^([^\\/]+)' -AllMatches| % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -First 1
	
	$workingDirectory = [System.IO.Path]::GetDirectoryName($archiveFile)
	$sourcePath = [System.IO.Path]::Combine($workingDirectory, $directoryName)
	$destinationPath = [System.IO.Path]::Combine($workingDirectory, "combined")

	if(!(test-path -path $destinationPath))
	{
		md $destinationPath | Out-Null
	}
	
	Write-Host "Copying '$sourcePath' to '$destinationPath'..."
	
	# robocopy
	$robocopyProcessArgs = """$sourcePath"" ""$destinationPath"" /S /E /NJH /NJS /NS /NC /NFL /NDL"
	$robocopyProcess = Start-Process "robocopy" $robocopyProcessArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

    # if %ERRORLEVEL% EQU 16 echo ***FATAL ERROR*** & goto end
    # if %ERRORLEVEL% EQU 15 echo OKCOPY + FAIL + MISMATCHES + XTRA & goto end
    # if %ERRORLEVEL% EQU 14 echo FAIL + MISMATCHES + XTRA & goto end
    # if %ERRORLEVEL% EQU 13 echo OKCOPY + FAIL + MISMATCHES & goto end
    # if %ERRORLEVEL% EQU 12 echo FAIL + MISMATCHES& goto end
    # if %ERRORLEVEL% EQU 11 echo OKCOPY + FAIL + XTRA & goto end
    # if %ERRORLEVEL% EQU 10 echo FAIL + XTRA & goto end
    # if %ERRORLEVEL% EQU 9 echo OKCOPY + FAIL & goto end
    # if %ERRORLEVEL% EQU 8 echo FAIL & goto end
    # if %ERRORLEVEL% EQU 7 echo OKCOPY + MISMATCHES + XTRA & goto end
    # if %ERRORLEVEL% EQU 6 echo MISMATCHES + XTRA & goto end
    # if %ERRORLEVEL% EQU 5 echo OKCOPY + MISMATCHES & goto end
    # if %ERRORLEVEL% EQU 4 echo MISMATCHES & goto end
    # if %ERRORLEVEL% EQU 3 echo OKCOPY + XTRA & goto end
    # if %ERRORLEVEL% EQU 2 echo XTRA & goto end
    # if %ERRORLEVEL% EQU 1 echo OKCOPY & goto end
    # if %ERRORLEVEL% EQU 0 echo No Change & goto end	
	
	# write error, if robocopy fails
	if ($robocopyProcess.ExitCode -eq 4 -or $robocopyProcess.ExitCode -eq 8 -or $robocopyProcess.ExitCode -eq 10 -or $robocopyProcess.ExitCode -eq 12 -or $robocopyProcess.ExitCode -eq 14 -or $robocopyProcess.ExitCode -eq 16)
	{
		Write-Error "Failed to copy files in archive file '$archiveFile'. Robocopy returned error code", $robocopyProcess.ExitCode
		exit 1
	}
	
	Write-Host "Done"
}



# get whdload games files
# -----------------------
$whdloadGamesRemotePath = "/Commodore_Amiga/WHDLoad_Packs/Games_WHDLoad"
$whdloadGamesLocalPath = [System.IO.Path]::Combine($outputPath, "games_whdload")
$whdloadGamesFiles = GetFtpDirectory $hostname $username $password $whdloadGamesRemotePath $outputPath



# download whdload games files
# ----------------------------
if(!(test-path -path $whdloadGamesLocalPath))
{
	md $whdloadGamesLocalPath | Out-Null
}

$whdloadGamesLocalFiles = @()

foreach ($file in ($whdloadGamesFiles | Where { $_ -match '^Games_WHDLoad' } | sort))
{
	$remotePath = $whdloadGamesRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadGamesLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath
	
	if ($file -match 'part0?1\.rar')
	{
		$whdloadGamesLocalFiles += , $localPath
	}
}



# get whdload update packs files
# ------------------------------
$whdloadUpdatePacksRemotePath = "/Commodore_Amiga/WHDLoad_Packs/Update_Packs"
$whdloadUpdatePacksRemoteFiles = GetFtpDirectory $hostname $username $password $whdloadUpdatePacksRemotePath $outputPath



# download games whdload update packs files
# -----------------------------------------
foreach ($file in ($whdloadUpdatePacksRemoteFiles | Where { $_ -match '_Games_WHDLoad.rar$' } | sort))
{
	$remotePath = $whdloadUpdatePacksRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadGamesLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath

	$whdloadGamesLocalFiles += , $localPath
}



# get games whdload aga files
# ---------------------------
$whdloadGamesAgaRemotePath = "/Commodore_Amiga/WHDLoad_Packs/Games_WHDLoad_AGA"
$whdloadGamesAgaLocalPath = [System.IO.Path]::Combine($outputPath, "games_whdload_aga")
$whdloadGamesAgaRemoteFiles = GetFtpDirectory $hostname $username $password $whdloadGamesAgaRemotePath $outputPath



# download games whdload aga files
# --------------------------------
if(!(test-path -path $whdloadGamesAgaLocalPath))
{
	md $whdloadGamesAgaLocalPath | Out-Null
}

$whdloadGamesAgaLocalFiles = @()

foreach ($file in ($whdloadGamesAgaRemoteFiles | Where { $_ -match '^Games_WHDLoad_AGA' } | sort))
{
	$remotePath = $whdloadGamesAgaRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadGamesAgaLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath

	if ($file -match 'part0?1\.rar')
	{
		$whdloadGamesAgaLocalFiles += , $localPath
	}
}



# download games whdload aga update packs files
# ---------------------------------------------
foreach ($file in ($whdloadUpdatePacksRemoteFiles | Where { $_ -match '_Games_WHDLoad_AGA.rar$' } | sort))
{
	$remotePath = $whdloadUpdatePacksRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadGamesAgaLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath

	$whdloadGamesAgaLocalFiles += , $localPath
}



# get demos whdload files
# -----------------------
$whdloadDemosRemotePath = "/Commodore_Amiga/WHDLoad_Packs/Demos_WHDLoad"
$whdloadDemosLocalPath = [System.IO.Path]::Combine($outputPath, "demos_whdload")
$whdloadDemosRemoteFiles = GetFtpDirectory $hostname $username $password $whdloadDemosRemotePath $outputPath



# download demos whdload files
# ----------------------------
if(!(test-path -path $whdloadDemosLocalPath))
{
	md $whdloadDemosLocalPath | Out-Null
}

$whdloadDemosLocalFiles = @()

foreach ($file in ($whdloadDemosRemoteFiles | Where { $_ -match '^Demos_WHDLoad' } | sort))
{
	$remotePath = $whdloadDemosRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadDemosLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath

	if ($file -match 'part0?1\.rar')
	{
		$whdloadDemosLocalFiles += , $localPath
	}
}



# download demos whdload update packs files
# -----------------------------------------
foreach ($file in ($whdloadUpdatePacksRemoteFiles | Where { $_ -match '_Demos_WHDLoad.rar$' } | sort))
{
	$remotePath = $whdloadUpdatePacksRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadDemosLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath

	$whdloadDemosLocalFiles += , $localPath
}



# get games whdload unpack on amiga files
# ---------------------------------------
$whdloadGamesUnpackOnAmigaRemotePath = "/Commodore_Amiga/WHDLoad_Packs/Games_WHDLoad_UnpackOnAmiga"
$whdloadGamesUnpackOnAmigaLocalPath = [System.IO.Path]::Combine($outputPath, "games_whdload_unpackonamiga")
$whdloadGamesUnpackOnAmigaRemoteFiles = GetFtpDirectory $hostname $username $password $whdloadGamesUnpackOnAmigaRemotePath $outputPath



# download games whdload unpack on amiga files
# --------------------------------------------
if(!(test-path -path $whdloadGamesUnpackOnAmigaLocalPath))
{
	md $whdloadGamesUnpackOnAmigaLocalPath | Out-Null
}

foreach ($file in $whdloadGamesUnpackOnAmigaRemoteFiles)
{
	$remotePath = $whdloadGamesUnpackOnAmigaRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadGamesUnpackOnAmigaLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath
}



# get demos whdload unpack on amiga files
# ---------------------------------------
$whdloadDemosUnpackOnAmigaRemotePath = "/Commodore_Amiga/WHDLoad_Packs/Games_WHDLoad_UnpackOnAmiga/Demos"
$whdloadDemosUnpackOnAmigaLocalPath = [System.IO.Path]::Combine($outputPath, "demos_whdload_unpackonamiga")
$whdloadDemosUnpackOnAmigaRemoteFiles = GetFtpDirectory $hostname $username $password $whdloadDemosUnpackOnAmigaRemotePath $outputPath


# download demos whdload unpack on amiga files
# --------------------------------------------
if(!(test-path -path $whdloadDemosUnpackOnAmigaLocalPath))
{
	md $whdloadDemosUnpackOnAmigaLocalPath | Out-Null
}

foreach ($file in $whdloadDemosUnpackOnAmigaRemoteFiles)
{
	$remotePath = $whdloadDemosUnpackOnAmigaRemotePath + "/" + $file
	$localPath = [System.IO.Path]::Combine($whdloadDemosUnpackOnAmigaLocalPath, $file)
	
	GetFtpFile $hostname $username $password $remotePath $localPath
}



# Uncompress and combine whdload games files
# ------------------------------------------
foreach($whdloadGamesLocalFile in $whdloadGamesLocalFiles)
{
	UncompressFile $whdloadGamesLocalFile
	CombineArchiveFiles $whdloadGamesLocalFile
}



# Uncompress and combine whdload games aga files
# ----------------------------------------------
foreach($whdloadGamesAgaLocalFile in $whdloadGamesAgaLocalFiles)
{
	UncompressFile $whdloadGamesAgaLocalFile
	CombineArchiveFiles $whdloadGamesAgaLocalFile
}



# Uncompress and combine whdload demos files
# ------------------------------------------
foreach($whdloadDemosLocalFile in $whdloadDemosLocalFiles)
{
	UncompressFile $whdloadDemosLocalFile
	CombineArchiveFiles $whdloadDemosLocalFile
}
