# Build AGS2 Menu
# ---------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-11
#
# A PowerShell script to build AGS2 menu with screenshots.
#


# 7-zip:
# http://7-zip.org/download.html
# http://7-zip.org/a/7z1514-x64.exe
#
# Image Magick:
# http://www.imagemagick.org/script/binary-releases.php
# http://www.imagemagick.org/download/binaries/ImageMagick-6.9.3-7-Q8-x64-dll.exe
#
# XnView with NConvert
# http://www.xnview.com/en/xnview/#downloads
# http://download3.xnview.com/XnView-win-full.exe
# 
# Python for imgtoiff:
# https://www.python.org/downloads/
# https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi
# 
# Pillow for imgtoiff:
# https://pypi.python.org/pypi/Pillow/2.7.0
# https://pypi.python.org/packages/2.7/P/Pillow/Pillow-2.7.0.win32-py2.7.exe#md5=a776412924049796bf34e8fa7af680db

Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadGamesPath,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$true)]
	[string]$mode
)


# check id mode is aga or ocs
if ($mode -notmatch '^(aga|ocs)')
{
	Write-Error "Unsupported mode '$mode'"
	exit 1
}

# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


# programs 
$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
$nconvertPath = "${Env:ProgramFiles(x86)}\XnView\nconvert.exe"
$imageMagickConvertPath = "$env:ProgramFiles\ImageMagick-6.9.3-Q8\convert.exe"
$imgToIffAgaPath = [System.IO.Path]::Combine($scriptPath, "ags2_iff\imgtoiff-aga.py")
$imgToIffOcsPath = [System.IO.Path]::Combine($scriptPath, "ags2_iff\imgtoiff-ocs.py")


# input and output paths
#$whdloadGamesPath = [System.IO.Path]::Combine($scriptPath, "whdload_games")
$whdownloadGamesSlaveIndexPath = [System.IO.Path]::Combine($scriptPath, "whdownload_games_slave_index")
#$outputPath = [System.IO.Path]::Combine($scriptPath, "ags2_menu")
$ags2MenuIndexPath = [System.IO.Path]::Combine($outputPath, "ags2_menu.csv")


# screenshot paths
$screenshotPath = [System.IO.Path]::Combine($scriptPath, "screenshots")
$troelsDkIffScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "iGameUpdatePackTroelsDK")
$igameGameplayIffScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "iGame_Gameplay_Shots_256")
$amigaGameBasePngScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "GameBase Amiga v1.6 Screenshots")
$amsBootMenuIffScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "AMS BootMenu")


# get archive files using list function in 7-zip
function GetArchiveFiles($archivePath)
{
	$output = & $sevenZipPath l $archivePath

	return $output | Select-String -Pattern "^([^\s]+)\s+([^\s]+)\s+([^\s\d]+)\s+([\d]+)\s+([\d]+)\s+(.+)\s*$" -AllMatches | 
	% { $_.Matches } | 
	% { @{ "Date" = $_.Groups[1].Value; "Time" = $_.Groups[2].Value; "Attr" = $_.Groups[3].Value; "Size" = $_.Groups[4].Value; "Compressed" = $_.Groups[5].Value; "Name" = $_.Groups[6].Value -replace "/", "\" } }
}


# get game index name from first character in game name
function GetGameIndexName($gameName)
{
	if ($gameName -match '^[0-9]') 
	{
		$gameIndexName = "0"
	}
	else
	{
		$gameIndexName = $gameName.Substring(0,1)
	}

	return $gameIndexName
}


# read whdload games index
function ReadWhdloadGamesIndex($whdloadGameIndexFile)
{
	$index = @{}

	ForEach($line in (Get-Content $whdloadGameIndexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$index.Set_Item($columns[0], $columns[1])
	}
	
	return $index
}


# read whdload games slave index
function ReadWhdloadGamesSlaveIndex($whdloadGameSlaveIndexFile)
{
	$index = @{}

	ForEach($line in (Get-Content $whdloadGameSlaveIndexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$index.Set_Item($columns[0], $columns)
	}

	return $index
}

# read ags2 menu index
function ReadAgs2MenuIndex($ags2MenuIndexPath)
{
	$index = @{}

	ForEach($line in (Get-Content $ags2MenuIndexPath | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$index.Set_Item($columns[0], $columns)
	}

	return $index
}


# simplify name by removing "the" word, special characters and converting roman numbers
function SimplifyName($name)
{
	return $name -replace "[\(\)\&,_\-!':]", " " -replace "the", "" -replace "[-_ ]vii", " 7 " 	-replace "[-_ ]vi", " 6 " -replace "[-_ ]v", " 5 " -replace "[-_ ]iv", " 4 " -replace "[-_ ]iii", " 3 " -replace "[-_ ]ii", " 2 " -replace "[-_ ]i", " 1 " -replace "\s+", " "
}


# make comparable name by simplifying name, removing whitespaces and non-word characters
function MakeComparableName($name)
{
    return ((SimplifyName $name) -replace "\s+", "" -replace "[^\w]", "").ToLower()
}


# build screenshot index from files
function BuildScreenshotIndex($path, $useDirectoryName)
{
	Write-Output "Building screenshot index from files in '$path'..."

	$screenshotFiles = Get-ChildItem -include *.iff,*.png -File -recurse -Path $path | Sort-Object $_.FullName

	$screenshots = @()
	
	ForEach ($screenshotFile in $screenshotFiles)
	{
		if ($useDirectoryName)
		{
			$screenshotName = [System.IO.Path]::GetFileName($screenshotFile.Directory)
		}
		else
		{
			$screenshotName = [System.IO.Path]::GetFileNameWithoutExtension($screenshotFile.FullName)
		}

		if ($screenshotName -match '_\d+$')
		{
			$screenshotName = $screenshotName -replace "_\d+$", ""
		}
		
		$comparableName = MakeComparableName $screenshotName
		
		$screenshots += @{ "Name" = $comparableName; "File" = $screenshotFile.FullName }
	}
	
	return $screenshots
}


# 1. check if 7-zip is installed, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}


# 2. check if nconvert is installed, exit if not
if (!(Test-Path -path $nconvertPath))
{
	Write-Error "nconvert is not installed at '$nconvertPath'"
	Exit 1
}


# 3. check if nconvert is installed, exit if not
if (!(Test-Path -path $imageMagickConvertPath))
{
	Write-Error "image magick is not installed at '$imageMagickConvertPath'"
	Exit 1
}


# 4. Get whdload game files
Write-Output "Reading whdload games from '$whdloadGamesPath'..."
$whdloadGameFiles = Get-ChildItem -recurse -Path $whdloadGamesPath -exclude *.html,*.csv -File
Write-Output "$($whdloadGameFiles.Count) entries"
Write-Output ""


# 5. Build troels dk iff screenshot index
Write-Output "Building screenshot index from '$troelsDkIffScreenshotPath'..."
$troelsDkIffScreenshotIndex = BuildScreenshotIndex $troelsDkIffScreenshotPath $true
Write-Output "$($troelsDkIffScreenshotIndex.Count) entries"
Write-Output ""


# 6. Build igame gameplay iff screenshot index
Write-Output "Building screenshot index from '$igameGameplayIffScreenshotPath'..."
$igameGameplayIffScreenshotIndex = BuildScreenshotIndex $igameGameplayIffScreenshotPath $true
Write-Output "$($igameGameplayIffScreenshotIndex.Count) entries"
Write-Output ""


# 7. Build amiga gamebase png screenshot index
Write-Output "Building screenshot index from '$amigaGameBasePngScreenshotPath'..."
$amigaGameBasePngScreenshotIndex = BuildScreenshotIndex $amigaGameBasePngScreenshotPath $false
Write-Output "$($amigaGameBasePngScreenshotIndex.Count) entries"
Write-Output ""


# 8. Build ams boot menu iff screenshot index
Write-Output "Building screenshot index from '$amsBootMenuIffScreenshotPath'..."
$amsBootMenuIffScreenshotIndex = BuildScreenshotIndex $amsBootMenuIffScreenshotPath $false
Write-Output "$($amsBootMenuIffScreenshotIndex.Count) entries"
Write-Output ""


# 9. Read whdload games index
$whdloadGameIndexFile = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_games_index.csv")
Write-Output "Reading whdload games index file '$whdloadGameIndexFile'..."
$whdloadGameIndex = ReadWhdloadGamesIndex $whdloadGameIndexFile
$whdloadGameIndex.Count


# 10. Read whdload games index
$whdloadGameSlaveIndexFile = [System.IO.Path]::Combine($whdownloadGamesSlaveIndexPath, "whdload_slave_index.csv")
Write-Output "Reading whdload game slave index file '$whdloadGameSlaveIndexFile'..."
$whdloadGameSlaveIndex = ReadWhdloadGamesSlaveIndex $whdloadGameSlaveIndexFile
$whdloadGameSlaveIndex.Count


# 11. Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


# 12. Add header to ags2 menu index, if index doesn't exist
if(!(test-path -path $ags2MenuIndexPath))
{
	Add-Content $ags2MenuIndexPath  "WhdloadGameFileName;WhdloadGameName;Ags2GameFileName;WhdloadGamePath;WhdloadGameSlaveFile;ScreenshotFile"
}


# 13. Read ags2 menu index
$ags2GameIndex = ReadAgs2MenuIndex $ags2MenuIndexPath


# 13. Process whdload game files
ForEach ($whdloadGameFile in $whdloadGameFiles)
{
	Write-Output "$($whdloadGameFile.Name)"
	
	$whdloadGameBaseName = [System.IO.Path]::GetFileNameWithoutExtension($whdloadGameFile.FullName) -split "_" | Select-Object -first 1


	$whdownloadGameIndexName = GetGameIndexName $whdloadGameFile.Name
	$ags2GameIndexMenuPath = [System.IO.Path]::Combine($outputPath, $whdownloadGameIndexName + ".ags")
	
	if(!(Test-Path -Path $ags2GameIndexMenuPath))
	{
		md $ags2GameIndexMenuPath | Out-Null
	}
	
	$whdloadGameSlave = $whdloadGameSlaveIndex.Get_Item($whdloadGameFile.Name)

	# get whdload game slave file name and copy columns
	$whdloadGameSlaveFileName = $whdloadGameSlave[1]
	$whdloadGameSlaveCopy = $whdloadGameSlave[3]
	
	# find whdload game slave file from whdownload file
	$whdloadGameSlaveFile = GetArchiveFiles $whdloadGameFile.FullName | Where { ([System.IO.Path]::GetFileName($_.Name)) -eq $whdloadGameSlaveFileName } | Select-Object -first 1

	# write error, if slave doesn't exist in whdownload file
	if (!$whdloadGameSlaveFile)
	{
		Write-Error "Slave doesn't exist in whdownload file '$($whdloadGameFile.Name)'"
	}

	# get whdload game slave directory from whdload game slave file
	$whdloadGameSlaveDirectory = [System.IO.Path]::GetDirectoryName($whdloadGameSlaveFile.Name)

	# get whdload game from index
	$whdloadGameName = $whdloadGameIndex.Get_Item($whdloadGameFile.Name)
	
	
	# make ags 2 game file name, removes invalid file name characters
	$ags2GameFileName = $whdloadGameName -replace "!", "" -replace ":", "" -replace """", "" -replace "/", "-" -replace "\?", ""

	# if ags 2 game file name is longer than 26 characters, then trim it to 26 characters (default filesystem compatibility with limit of ~30 characters)
	if ($ags2GameFileName.length -gt 26)
	{
		$ags2GameFileName = $ags2GameFileName.Substring(0,26).Trim()
	}

	# build new ags2 game file name, if it already exists in index
	if ($ags2GameIndex.ContainsKey($ags2GameFileName))
	{
		$count = 1
		
		do
		{
			$newAgs2GameFileName = $ags2GameFileName.Substring(0,$ags2GameFileName.length - $count.ToString().length) + $count
			$count++
		} while ($ags2GameIndex.ContainsKey($newAgs2GameFileName))
		$ags2GameFileName = $newAgs2GameFileName
	}
	
	# add ags2 game file name to index
	$ags2GameIndex.Set_Item($ags2GameFileName, $true)
	
	
	# ags2 game files
	$ags2GameRunFile = [System.IO.Path]::Combine($ags2GameIndexMenuPath, "$($ags2GameFileName).run")
	$ags2GameTxtFile = [System.IO.Path]::Combine($ags2GameIndexMenuPath, "$($ags2GameFileName).txt")
	$ags2GameIffFile = [System.IO.Path]::Combine($ags2GameIndexMenuPath, "$($ags2GameFileName).iff")
	
	
	$whdloadGamePath = "$($whdownloadGameIndexName)/$($whdloadGameSlaveDirectory)"
	
	
	
	# write ags 2 game run file in ascii encoding
	[System.IO.File]::WriteAllText($ags2GameRunFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes("cd A-Games:$($whdloadGamePath)`nwhdload $($whdloadGameSlaveFileName)`n")), [System.Text.Encoding]::ASCII)

	# write ags 2 game txt file in ascii encoding
	[System.IO.File]::WriteAllText($ags2GameTxtFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes("$($whdloadGameName)`n$($whdloadGameSlaveCopy)`n")), [System.Text.Encoding]::ASCII)

	
	# make comparable whdload game slave directory and whdload base name
	$whdloadGameSlaveDirectoryComparableName = MakeComparableName $whdloadGameSlaveDirectory
	$whdloadGameBaseNameComparableName = MakeComparableName $whdloadGameBaseName

	
	# find troels dk screenshot
	$screenshots = $troelsDkIffScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

	if ($screenshots.Count -eq 0)
	{
		$screenshots = $troelsDkIffScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }
	}

	
	# find igame gameplay screenshot, if no screenshots are found
	if ($screenshots.Count -eq 0)
	{
		$screenshots = $igameGameplayIffScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

		if ($screenshots.Count -eq 0)
		{
			$screenshots = $igameGameplayIffScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }
		}
	}
	
	
	# find amiga gamebase screenshot, if no screenshots are found
	if ($screenshots.Count -eq 0)
	{
		# get screenshots with exact name
		$screenshots = $amigaGameBasePngScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }

		# if screenshots with exact name is less than or equal to 1, then get screenshots where name starts with identical name
		if ($screenshots.Count -le 1)
		{
			$screenshots = $amigaGameBasePngScreenshotIndex | Where { $_.Name -match "^$($whdloadGameBaseNameComparableName)" }
		}
	}

	
	# find ams boot menu screenshot, if no screenshots are found
	if ($screenshots.Count -eq 0)
	{
		$screenshots = $amsBootMenuIffScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

		if ($screenshots.Count -eq 0)
		{
			$screenshots = $amsBootMenuIffScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }
		}
	}

	# get last screenshot file
	$screenshot = $screenshots | Select-Object -last 1

	
	# get screenshot file name
	if ($screenshot)
	{
		$screenshotFileName = $screenshot.File.Replace($screenshotPath + "\", "")
	}
	else
	{
		$screenshotFileName = ""
	}

	
	# add to ags2 menu index
	Add-Content $ags2MenuIndexPath "$($whdloadGameFile.Name);$whdloadGameName;$ags2GameFileName;$whdloadGamePath;$whdloadGameSlaveFileName;$screenshotFileName"
	
	
	# skip, if no screenshot
	if (!$screenshot)
	{
		continue
	}
	
	
	# set temp path using drive Z:\ (ramdisk), if present
	if (Test-Path -path "Z:\")
	{
		$tempPath = [System.IO.Path]::Combine("Z:\", [System.IO.Path]::GetRandomFileName())
	}
	else
	{
		$tempPath = [System.IO.Path]::Combine("$env:SystemDrive\Temp", [System.IO.Path]::GetRandomFileName())
	}


	# create temp path
	md $tempPath | Out-Null


	# set ags2 game screenshot to screenshot file
	$ags2GameScreenshotFile = $screenshot.File

	# convert screenshot to png, if it's iff
	if ($screenshot.File -match '\.iff$')
	{
		# use nconvert to convert screenshot from iff to png
		$nconvertScreenshotFile = [System.IO.Path]::Combine($tempPath, "nconvert-from-iff.png")
		$nconvertPngArgs = "-out png -o ""$($nconvertScreenshotFile)"" ""$($ags2GameScreenshotFile)"""
		$nconvertPngProcess = Start-Process $nconvertPath $nconvertPngArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

		# exit, if nconvert fails
		if ($nconvertPngProcess.ExitCode -ne 0)
		{
			Write-Error "Failed to run nconvert png for '$($screenshot.File)'"
			exit 1
		}
		
		# set ags2 game screenshot to nconvert screenshot file
		$ags2GameScreenshotFile = $nconvertScreenshotFile
	}


	$imageMagickConvertScreenshotFile = [System.IO.Path]::Combine($tempPath, "imagemagick-resized.png")

	# set image magick for aga or ocs 
	if ($mode -eq "aga")
	{
		$imageMagickConvertArgs = """$ags2GameScreenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 200 ""$imageMagickConvertScreenshotFile"""
	}
	if ($mode -eq "ocs")
	{
		$imageMagickConvertArgs = """$ags2GameScreenshotFile"" -resize 320x128! -filter Point -depth 4 -colors 11 ""$imageMagickConvertScreenshotFile"""
	}
	
	# use image magick convert to resize screenshot to 320 x 128, decrease bit depth 8 and 200 colors. The remaining 55 colors will be used by AGS2 background 
	$imageMagickConvertProcess = Start-Process $imageMagickConvertPath $imageMagickConvertArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

	# exit, if image magick fails
	if ($imageMagickConvertProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to run imagemagick convert for '$($screenshot.File)'"
		exit 1
	}
			
	# set ags2 game screenshot to nconvert screenshot file
	$ags2GameScreenshotFile = $imageMagickConvertScreenshotFile
	

	# set imgtoiff for aga or ocs 
	if ($mode -eq "aga")
	{
		$imgToIffArgs = """$imgToIffAgaPath"" --aga --pack 1 ""$($ags2GameScreenshotFile)"" ""$($ags2GameIffFile)"""
	}
	if ($mode -eq "ocs")
	{
		$imgToIffArgs = """$imgToIffOcsPath"" --ocs --pack 1 ""$($ags2GameScreenshotFile)"" ""$($ags2GameIffFile)"""
	}

	# use imgtoiff to generate ags2 game screenshot file
	$imgToIffProcess = Start-Process python $imgToIffArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul
	
	# exit, if imgtoiff fails
	if ($imgToIffProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to run imgtoiff for '$($screenshot.File)'"
		exit 1
	}

	
	# remove temp path
	remove-item $tempPath -recurse
}


#NOTE: For any future use of nconvert to make iff's, args are kept here
#$nconvertIffArgs = "-out iff -c 1 -o ""$($ags2GameIffFile)"" ""$($ags2GameScreenshotFile)"""
#$nconvertIffProcess = Start-Process $nconvertPath $nconvertIffArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul
#if ($nconvertIffProcess.ExitCode -ne 0)
#{
#	Write-Error "Failed to run nconvert iff for '$($screenshot.File)'"
#	exit 1
#}
