# Build WHDLoad Screenshots
# -------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-11
#
# A PowerShell script to build whdload screenshots for iGame and AGS2 in AGA and OCS mode.
#
# Following software is required for running this script.
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
	[string]$whdloadGameSlaveIndexPath,
	[Parameter(Mandatory=$true)]
	[string]$outputPath
)


# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


# programs 
$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
$nconvertPath = "${Env:ProgramFiles(x86)}\XnView\nconvert.exe"
$imageMagickConvertPath = "$env:ProgramFiles\ImageMagick-6.9.3-Q8\convert.exe"
$imgToIffAgaPath = [System.IO.Path]::Combine($scriptPath, "ags2_iff\imgtoiff-aga.py")
$imgToIffOcsPath = [System.IO.Path]::Combine($scriptPath, "ags2_iff\imgtoiff-ocs.py")
$levenshteinDistanceScriptPath = [System.IO.Path]::Combine($scriptPath, "Levenshtein-distance.ps1")


# screenshot paths
$screenshotPath = [System.IO.Path]::Combine($scriptPath, "screenshots")
$troelsDkIffScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "iGameUpdatePackTroelsDK")
$igameGameplayIffScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "iGame_Gameplay_Shots_256")
$amigaGameBasePngScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "GameBase Amiga v2.0 Screenshots")
$openAmigaGameDatabasePngScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "Open Amiga Game Database")
#$amigaGameBasePngScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "GameBase Amiga v1.6 Screenshots")
$amsBootMenuIffScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "AMS BootMenu")




# logs
$logPath = [System.IO.Path]::Combine($scriptPath, "logs")
$logFile = [System.IO.Path]::Combine($logPath, "build_whdload_screenshots_" + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + ".txt")


# set temp path using drive Z:\ (ramdisk), if present
if (Test-Path -path "Z:\")
{
	$tempPath = [System.IO.Path]::Combine("Z:\", [System.IO.Path]::GetRandomFileName())
}
else
{
	$tempPath = [System.IO.Path]::Combine("$env:SystemDrive\Temp", [System.IO.Path]::GetRandomFileName())
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


# read whdload games slave index
function ReadWhdloadGamesSlaveIndex($whdloadGameSlaveIndexFile)
{
	$index = @()

	ForEach($line in (Get-Content $whdloadGameSlaveIndexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$index += , $columns
	}

	return $index
}

# read whdload screenshot index
function ReadWhdloadScreenshotIndex($whdloadScreenshotIndexPath)
{
	$index = @{}

	if(Test-path -path $whdloadScreenshotIndexPath)
	{
		ForEach($line in (Get-Content $whdloadScreenshotIndexPath | Select-Object -Skip 1))
		{
			$columns = $line -split ";" | % { $_  -replace "^""", "" -replace """$", "" }
			
			$index.Set_Item($columns[0] + $columns[1], @{ "WhdloadGameFileName" = $columns[0]; "WhdloadGameSlaveFile" = $columns[1]; "WhdloadGameName" = $columns[2]; "ScreenshotFileName" = $columns[3] })
		}
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

function MakeKeywords([string]$text)
{
	# change odd chars to space
	$text = $text -creplace "[&\-_\(\):\.,!+]", " "

	# remove the and demo
	$text = $text -replace "the", " " -replace "demo", " "
	
	# replace roman numbers
	$text = $text -replace "[-_ ]vii", " 7 " -replace "[-_ ]vi", " 6 " -replace "[-_ ]v", " 5 " -replace "[-_ ]iv", " 4 " -replace "[-_ ]iii", " 3 " -replace "[-_ ]ii", " 2 " -replace "[-_ ]i", " 1 "
	
	# remove odd chars
	$text = $text -creplace "[']", ""

	# add space between number and letters, if not the character 'D'
	$text = $text -creplace "(\d+)([^D\d])", "`$1 `$2"
	
	# add space before and after 3D or 4D
	$text = $text -replace "([34]D)", " `$1 "
	
	# add space between lower and upper case letters or numbers
	$text = $text -creplace "([a-z])([A-Z0-9])", "`$1 `$2"
	
	# replace multiple space with a single space
	$text = $text -replace "\s+", " "
	
	return , ($text.ToLower().Trim() -split " ")
}

# build screenshot index from files
function BuildScreenshotIndex($path, $useDirectoryName, $priority, $filter)
{
	$screenshotFiles = Get-ChildItem -include *.iff,*.png -File -recurse -Path $path | Sort-Object $_.FullName

	if ($filter)
	{
		$screenshotFiles = $screenshotFiles | Where {$_.FullName -match $filter}
	}
	
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
		
		$screenshots += @{ "Name" = $comparableName; "Priority" = $priority; "File" = $screenshotFile.FullName; "Keywords" = (MakeKeywords $screenshotName) }
	}
	
	return $screenshots
}


function FindBestMatchingScreenshotInIndex($name, $screenshotIndex)
{
	$comparableName = MakeComparableName $name
	$nameKeywords = MakeKeywords $name

	$matchingScreenshots = @()
	
	$screenshotIndex | Where { $_.Name -eq $comparableName  } | % { $matchingScreenshots += @{ "Screenshot" = $_; "Rank" = 100; } }

	if ($matchingScreenshots.Count -eq 0)
	{
		ForEach($screenshot in $screenshotIndex)
		{
			# if ($screenshot.Name -match 'train')
			# {
				# Write-Host "name keywords", $nameKeywords
				# Write-Host "screenshot keywords", $screenshot.Keywords
			# }
		
			# skip, if no keywords match
			#If ((Compare-Object $nameKeywords $screenshot.Keywords -IncludeEqual -ExcludeDifferent -PassThru).Count -eq 0)
			#{
			#	continue
			#}
		
			$exactMatchingKeywords = 0
			
			# find first name keyword index in screenshot keywords
			$nameKeywordsIndex = 0
			$screenshotKeywordsIndex = $screenshot.Keywords.IndexOf($nameKeywords[0])
			
			#Write-Host $nameKeywords[0], "found screenshot at index", $screenshotKeywordsIndex, "for", $name
			
			For (; $nameKeywordsIndex -lt $nameKeywords.Count -and $screenshotKeywordsIndex -lt $screenshot.Keywords.Count; $nameKeywordsIndex++, $screenshotKeywordsIndex++)
			{
				If ($nameKeywords[$nameKeywordsIndex] -eq $screenshot.Keywords[$screenshotKeywordsIndex])
				{
					$exactMatchingKeywords++
				}
			}

			$containKeywords = 0;
			
			ForEach($nameKeyword in $nameKeywords)
			{
				ForEach($screenshotKeyword in $screenshot.Keywords)
				{
					if ($nameKeyword -match $screenshotKeyword -or $screenshotKeyword -match $nameKeyword)
					{
						$containKeywords++
					}
				}
			}
			
			
			
			#$levenshteinDistance = (& "$levenshteinDistanceScriptPath" -first $comparableName -second $screenshot.Name -ignoreCase)
			#$rank = $levenshteinDistance * -1
		
		
			$matchingKeywords = (Compare-Object $nameKeywords $screenshot.Keywords -IncludeEqual -ExcludeDifferent -PassThru).Count
			$notMatchingKeywords = (Compare-Object $nameKeywords $screenshot.Keywords -PassThru).Count
		
			# calculate rank
			$rank = ($exactMatchingKeywords * 2) + $matchingKeywords + $containKeywords - $notMatchingKeywords

			# boost rank, if contains the same
			if ($screenshot.Name -match $comparableName -or $comparableName -match $screenshot.Name)
			{
				$rank += 20
			}
			
			# add screenshot, if it has at least one macthing keyword
			if ($rank -ge 1)
			{
				$matchingScreenshots += @{ "Screenshot" = $screenshot; "Rank" = $rank; "Matching" = $exactMatchingKeywords; "NotMatching" = $notMatchingKeywords }
			}
		}
	}
	
	$rankedScreenshots = @()
	
	$matchingScreenshots | sort @{expression={$_.Rank};Ascending=$false},@{expression={$_.Screenshot.File};Ascending=$true} | % { $rankedScreenshots += @{ "Priority" = $_.Screenshot.Priority; "Rank" = $_.Rank; "Matching" = $_.Matching; "NotMatching" = $_.NotMatching; "Name" = $_.Screenshot.Name; "File" = $_.Screenshot.File } }
	
	return $rankedScreenshots;
}


# 1. Create log path, if it doesn't exist
if(!(test-path -path $logPath))
{
	md $logPath | Out-Null
}


# 2. check if 7-zip is installed, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}


# 3. check if nconvert is installed, exit if not
if (!(Test-Path -path $nconvertPath))
{
	Write-Error "nconvert is not installed at '$nconvertPath'"
	Exit 1
}


# 4. check if nconvert is installed, exit if not
if (!(Test-Path -path $imageMagickConvertPath))
{
	Write-Error "image magick is not installed at '$imageMagickConvertPath'"
	Exit 1
}



MakeKeywords "laigle-dor-le-retour"
MakeKeywords "AigleDOr"



# 12. Read whdload screenshot index
$whdloadScreenshotIndexPath = [System.IO.Path]::Combine($outputPath, "whdload_screenshots.csv")
Write-Output "Reading whdload screenshot index from '$whdloadScreenshotIndexPath'..."
$whdloadScreenshotIndex = ReadWhdloadScreenshotIndex $whdloadScreenshotIndexPath $false 
Write-Output "$($whdloadScreenshotIndex.Count) entries"
Write-Output ""


# 5. Build troels dk iff screenshot index
Write-Output "Building screenshot index from '$troelsDkIffScreenshotPath'..."
$troelsDkIffScreenshotIndex = BuildScreenshotIndex $troelsDkIffScreenshotPath $true 1
Write-Output "$($troelsDkIffScreenshotIndex.Count) entries"
Write-Output ""


# 6. Build igame gameplay iff screenshot index
Write-Output "Building screenshot index from '$igameGameplayIffScreenshotPath'..."
$igameGameplayIffScreenshotIndex = BuildScreenshotIndex $igameGameplayIffScreenshotPath $true 4
Write-Output "$($igameGameplayIffScreenshotIndex.Count) entries"
Write-Output ""


# 7. Build amiga gamebase png screenshot index
Write-Output "Building screenshot index from '$amigaGameBasePngScreenshotPath'..."
$amigaGameBasePngScreenshotIndex = BuildScreenshotIndex $amigaGameBasePngScreenshotPath $false 2 "_\d+\.[^\.]+`$"
Write-Output "$($amigaGameBasePngScreenshotIndex.Count) entries"
Write-Output ""


Write-Output "Building screenshot index from '$openAmigaGameDatabasePngScreenshotPath'..."
$openAmigaGameDatabasePngScreenshotIndex = BuildScreenshotIndex $openAmigaGameDatabasePngScreenshotPath $true 3 "_\d+[2-9]\.[^\.]+`$"
Write-Output "$($openAmigaGameDatabasePngScreenshotIndex.Count) entries"
Write-Output ""


$lemonAmigaScreenshotPath = "c:\Work\First Realize\amiga-game-database\lemonamiga"
Write-Output "Building screenshot index from '$lemonAmigaScreenshotPath'..."
$lemonAmigaScreenshotIndex = BuildScreenshotIndex $lemonAmigaScreenshotPath $true 4 "_\d+[2-9]\.[^\.]+`$"
Write-Output "$($lemonAmigaScreenshotIndex.Count) entries"
Write-Output ""



# 8. Build ams boot menu iff screenshot index
Write-Output "Building screenshot index from '$amsBootMenuIffScreenshotPath'..."
$amsBootMenuIffScreenshotIndex = BuildScreenshotIndex $amsBootMenuIffScreenshotPath $false 5
Write-Output "$($amsBootMenuIffScreenshotIndex.Count) entries"
Write-Output ""


# 9. Read whdload games index
$whdloadGameSlaveIndexFile = [System.IO.Path]::Combine($whdloadGameSlaveIndexPath, "whdload_slave_index.csv")
Write-Output "Reading whdload game slave index file '$whdloadGameSlaveIndexFile'..."
$whdloadGameSlaves = ReadWhdloadGamesSlaveIndex $whdloadGameSlaveIndexFile
$whdloadGameSlaves.Count


# 10. Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


function Test($name)
{
	Write-Host "Name: $name"
	Write-Host "----------"
	$screenshots = @()
	$screenshots += (FindBestMatchingScreenshotInIndex $name $troelsDkIffScreenshotIndex)
	$screenshots += (FindBestMatchingScreenshotInIndex $name $amigaGameBasePngScreenshotIndex)
	$screenshots += (FindBestMatchingScreenshotInIndex $name $openAmigaGameDatabasePngScreenshotIndex)
	$screenshots = $screenshots | sort @{expression={$_.Rank};Ascending=$false},@{expression={$_.Priority};Ascending=$true},@{expression={$_.File};Ascending=$true}
	$screenshots = $screenshots | Select-Object -First 5
	return $screenshots
}
#  | Where { $_.Rank -ge -5 }

#Test "AllTerrainRacing"
#Test "Academy"
#Test "ATrain&ConstructionSet"
#Test "ACSYSDemo aga"
#Test "ACSYSDemoAGA"
#Test "4DSportsDriving&MasterTracks"
#Test "AlienBreedTowerAssault11.Aga"
#Test "AigleDOr"


#exit 0


$screenshotsCache = @{}



# 13. Process whdload game files
ForEach ($whdloadGameSlave in $whdloadGameSlaves)
{
	# get whdload game slave file name and slave file columns
	$whdloadGameFileName = $whdloadGameSlave[0]
	$whdloadGameSlaveFile = $whdloadGameSlave[1]


	$isCd32 = $whdloadGameFileName -match '_cd32'
	$isAga = $whdloadGameFileName -match '_aga'
	$isCdtv = $whdloadGameFileName -match '_cdtv'

	$hardware = ""
	
	if ($isCd32)
	{
		$hardware = "cd32"
	}
	if ($isAga)
	{
		$hardware = "aga"
	}
	if ($isCdtv)
	{
		$hardware = "cdtv"
	}

	$whdloadGameBaseName = [System.IO.Path]::GetFileNameWithoutExtension($whdloadGameFileName) -split "_" | Select-Object -first 1

	$whdloadGameName = $whdloadGameBaseName
	
	if ($hardware)
	{
		$whdloadGameName += ".$hardware" 
	}

	
	$whdloadScreenshotPath = [System.IO.Path]::Combine($outputPath, $whdloadGameName)

	
	
	# get whdload game slave directory from whdload game slave file
	$whdloadGameSlaveDirectory = [System.IO.Path]::GetDirectoryName($whdloadGameSlaveFile)

	# make comparable whdload game slave directory and whdload base name
	$whdloadGameSlaveDirectoryComparableName = MakeComparableName $whdloadGameSlaveDirectory
	$whdloadGameBaseNameComparableName = MakeComparableName $whdloadGameBaseName

	
	
	
	$screenshotGameName = $whdloadGameBaseName
	$screenshotGameComparableName = MakeComparableName $whdloadGameBaseName

	if ($hardware -match '(aga|cd32)')
	{
		$screenshotGameName += " aga"
	}


	
	if ($screenshotsCache.ContainsKey($screenshotGameName))
	{
		$screenshots = $screenshotsCache.Get_Item($screenshotGameName)
	}
	else
	{
		$screenshots = @()
		$screenshots += (FindBestMatchingScreenshotInIndex $screenshotGameName $troelsDkIffScreenshotIndex)
		$screenshots += (FindBestMatchingScreenshotInIndex $screenshotGameName $amigaGameBasePngScreenshotIndex)
		$screenshots += (FindBestMatchingScreenshotInIndex $screenshotGameName $openAmigaGameDatabasePngScreenshotIndex)
		$screenshots += (FindBestMatchingScreenshotInIndex $screenshotGameName $lemonAmigaScreenshotIndex)
		
		$screenshotsCache.Set_Item($screenshotGameName, $screenshots)
	}
	
	

	#$rank = (MakeKeywords $screenshotGameName).Count
	#$minimumRank = 1
	
	# if ($rank -lt 2)
	# {
		# $minimumRank = $rank - ($rank / 2) + 1
	# }
	
	# find screenshot with highest rank
	#do
	#{
	#	$screenshot = $screenshots | Where { $_.Rank -ge $rank } | Select-Object -First 1
	#	$rank -= 1
	#} while (!$screenshot -and $rank -ge $minimumRank)

	
	
	$screenshot = $screenshots | sort @{expression={$_.Rank};Ascending=$false},@{expression={$_.Priority};Ascending=$true},@{expression={$_.File};Ascending=$false} | Select-Object -First 1
	
	
	# if no screenshot, take best matching and priority regardless of rank
	#if (!$screenshot)
	#{
		#$screenshot = $screenshots | sort @{expression={$_.Matching};Ascending=$false},@{expression={$_.Priority};Ascending=$false},@{expression={$_.File};Ascending=$true} | Select-Object -First 1
	#	$screenshot = $screenshots | Where { $_.Name -match "^$screenshotGameComparableName" } | sort @{expression={$_.Priority};Ascending=$false},@{expression={$_.File};Ascending=$true} | Select-Object -First 1
	#}
	
	# find troels dk screenshot
	# $screenshots = $troelsDkIffScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

	# if ($screenshots.Count -eq 0)
	# {
		# $screenshots = $troelsDkIffScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }
	# }

	
	# find amiga gamebase screenshot, if no screenshots are found
	# if ($screenshots.Count -eq 0)
	# {
		# # get screenshots with exact name
		# $screenshots = $amigaGameBasePngScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }

		# # if screenshots with exact name is less than or equal to 1, then get screenshots where name starts with identical name
		# if ($screenshots.Count -le 1)
		# {
			# $screenshots = $amigaGameBasePngScreenshotIndex | Where { $_.Name -match "^$($whdloadGameBaseNameComparableName)" }
		# }
	# }


	# find open amiga game database screenshot, if none or one screenshot is found
	# if ($screenshots.Count -le 1)
	# {
		# $screenshots = $openAmigaGameDatabasePngScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

		# if ($screenshots.Count -eq 0)
		# {
			# $screenshots = $openAmigaGameDatabasePngScreenshotIndex | Where { $_.Name -match "^$($whdloadGameBaseNameComparableName)" }
		# }
	# }
	

	# find igame gameplay screenshot, if no screenshots are found
	# if ($screenshots.Count -eq 0)
	# {
		# $screenshots = $igameGameplayIffScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

		# if ($screenshots.Count -eq 0)
		# {
			# $screenshots = $igameGameplayIffScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }
		# }
	# }
		
	
	# find ams boot menu screenshot, if no screenshots are found
	# if ($screenshots.Count -eq 0)
	# {
		# $screenshots = $amsBootMenuIffScreenshotIndex | Where { $whdloadGameSlaveDirectoryComparableName -eq $_.Name }

		# if ($screenshots.Count -eq 0)
		# {
			# $screenshots = $amsBootMenuIffScreenshotIndex | Where { $whdloadGameBaseNameComparableName -eq $_.Name }
		# }
	# }

	
	
	
	# get last screenshot file
	#$screenshot = $screenshots | Select-Object -First 1
	
	# skip, if no screenshot
	if (!$screenshot)
	{
		#Write-Host $screenshots.Count + " screenshots found for '$whdloadGameBaseName'"
		Write-Host "skipping $whdloadGameFileName, $whdloadGameSlaveFile, no screenshots found"
		#Add-Content $logFile "skipping $whdloadGameFileName, $whdloadGameSlaveFile, no screenshots found"
		continue
	}

	
	# get screenshot file name
	$screenshotFileName = $screenshot.File.Replace($screenshotPath + "\", "")
	
	$whdloadScreenshot = $whdloadScreenshotIndex.Get_Item($whdloadGameFileName + $whdloadGameSlaveFile)

	# skip screenshot, if it exists and is identical
	if ($whdloadScreenshot -and $whdloadScreenshot.ScreenshotFileName -eq $screenshotFileName)
	{
		#Write-Host "skipping $whdloadGameFileName, new screenshots not found (" + $whdloadScreenshot.ScreenshotFileName + " <-> " + $screenshotFileName + ")"
		continue
	}


	# write game name
	Write-Host "$whdloadGameName (", $whdloadScreenshot.ScreenshotFileName, "<->", $screenshotFileName, ")"


	# create temp path
	if(!(test-path -path $tempPath))
	{
		md $tempPath | Out-Null
	}


	# set screenshot file
	$screenshotFile = $screenshot.File

	# convert screenshot to png, if it's iff
	if ($screenshotFile -match '\.iff$')
	{
		# use nconvert to convert screenshot from iff to png
		$nconvertPngScreenshotFile = [System.IO.Path]::Combine($tempPath, "nconvert-from-iff.png")
		$nconvertPngArgs = "-out png -o ""$nconvertPngScreenshotFile"" ""$screenshotFile"""
		$nconvertPngProcess = Start-Process $nconvertPath $nconvertPngArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

		# continue, if nconvert fails
		if ($nconvertPngProcess.ExitCode -ne 0)
		{
			Write-Error "Failed to run nconvert png for '$screenshotFile' with arguments '$nconvertPngArgs'"
			continue
		}
		
		# set ags2 game screenshot to nconvert screenshot file
		$screenshotFile = $nconvertPngScreenshotFile
	}


	# use image magick convert screenshot to iGame screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors)
	$imageMagickConvertiGameScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame.png")
	$imageMagickConvertiGameArgs = """$screenshotFile"" -resize 320x128! -filter Point -depth 8 ""$imageMagickConvertiGameScreenshotFile"""
	$imageMagickConvertiGameProcess = Start-Process $imageMagickConvertPath $imageMagickConvertiGameArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

	# continue, if image magick convert fails
	if ($imageMagickConvertiGameProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to run imagemagick convert for '$screenshotFile' with arguments '$imageMagickConvertiGameArgs'"
		continue
	}

	
	# use nconvert to convert iGame screenshot to iff
	$nconvertiGameScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame.iff")
	$nconvertiGameArgs = "-out iff -c 1 -colors 256 -o ""$nconvertiGameScreenshotFile"" ""$imageMagickConvertiGameScreenshotFile"""
	$nconvertiGameProcess = Start-Process $nconvertPath $nconvertiGameArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

	# continue, if nconvert fails
	if ($nconvertiGameProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to run nconvert iff for '$imageMagickConvertiGameScreenshotFile' with arguments '$nconvertiGameArgs'"
		continue
	}

	
	# use image magick convert screenshot to AGS2 AGA screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors) and limit colors to 200
	$imageMagickConvertAgs2AgaScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga.png")
	$imageMagickConvertAgs2AgaArgs = """$screenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 200 ""$imageMagickConvertAgs2AgaScreenshotFile"""
	$imageMagickConvertAgs2AgaProcess = Start-Process $imageMagickConvertPath $imageMagickConvertAgs2AgaArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

	# continue, if image magick convert fails
	if ($imageMagickConvertAgs2AgaProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to run imagemagick convert for '$screenshotFile' with arguments '$imageMagickConvertAgs2AgaArgs'"
		continue
	}
	

	# use imgtoiff to generate AGS2 AGA Game screenshot file
	$imgToIffAgs2AgaScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga.iff")
	$imgToIffAgs2AgaArgs = """$imgToIffAgaPath"" --aga --pack 1 ""$imageMagickConvertAgs2AgaScreenshotFile"" ""$imgToIffAgs2AgaScreenshotFile"""
	$imgToIffAgs2AgaProcess = Start-Process python $imgToIffAgs2AgaArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul
	
	# continue, if imgtoiff fails
	if ($imgToIffAgs2AgaProcess.ExitCode -ne 0)
	{
		Write-Error "Failed to run imgtoiff for '$screenshotFile' with arguments '$imgToIffAgs2AgaArgs'"
		continue
	}
	

	# generate ocs screenshot, if game is not cd32 or aga hardware
	if ($hardware -notmatch 'cd32' -and $hardware -notmatch 'aga')
	{
		# use image magick convert screenshot to AGS2 OCS screenshot: Resize to 320 x 128 pixels, set bit depth to 4 (16 colors) and limit colors to 11
		$imageMagickConvertAgs2OcsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs.png")
		$imageMagickConvertAgs2OcsArgs = """$screenshotFile"" -resize 320x128! -filter Point -depth 4 -colors 11 ""$imageMagickConvertAgs2OcsScreenshotFile"""
		$imageMagickConvertAgs2OcsProcess = Start-Process $imageMagickConvertPath $imageMagickConvertAgs2OcsArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul

		# continue, if image magick convert fails
		if ($imageMagickConvertAgs2OcsProcess.ExitCode -ne 0)
		{
			Write-Error "Failed to run imagemagick convert for '$screenshotFile' with arguments '$imageMagickConvertAgs2OcsArgs'"
			continue
		}

		# use imgtoiff to generate AGS2 OCS Game screenshot file
		$imgToIffAgs2OcsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs.iff")
		$imgToIffAgs2OcsArgs = """$imgToIffOcsPath"" --ocs --pack 1 ""$imageMagickConvertAgs2OcsScreenshotFile"" ""$imgToIffAgs2OcsScreenshotFile"""
		$imgToIffAgs2OcsProcess = Start-Process python $imgToIffAgs2OcsArgs -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul
		
		# continue, if imgtoiff fails
		if ($imgToIffAgs2OcsProcess.ExitCode -ne 0)
		{
			Write-Error "Failed to run imgtoiff for '$screenshotFile' with arguments '$imgToIffAgs2OcsArgs'"
			continue
		}
	}
	

	# create whdload screenshot path
	if(!(test-path -path $whdloadScreenshotPath))
	{
		md $whdloadScreenshotPath | Out-Null
	}


	# whdload screenshot files
	$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "screenshot.png")
	$whdloadiGameScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "igame.iff")
	$whdloadAgs2AgaScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "ags2aga.iff")
	$whdloadAgs2OcsScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "ags2ocs.iff")

	# copy whdload screenshot files
	Copy-Item $screenshotFile $whdloadScreenshotFile -force
	Copy-Item $nconvertiGameScreenshotFile $whdloadiGameScreenshotFile -force
	Copy-Item $imgToIffAgs2AgaScreenshotFile $whdloadAgs2AgaScreenshotFile -force

	# copy AGS2 OCS screenshot, if it exists
	if(test-path -path $imgToIffAgs2OcsScreenshotFile)
	{
		Copy-Item $imgToIffAgs2OcsScreenshotFile $whdloadAgs2OcsScreenshotFile -force
	}
	

	# remove temp path
	remove-item $tempPath -recurse

	
	# update index
	if ($whdloadScreenshot)
	{
		$whdloadScreenshot.ScreenshotFileName = $screenshotFileName
	}
	else
	{
		$whdloadScreenshotIndex.Set_Item($whdloadGameFileName + $whdloadGameSlaveFile, @{ "WhdloadGameFileName" = $whdloadGameFileName; "WhdloadGameSlaveFile" = $whdloadGameSlaveFile; "WhdloadGameName" = $whdloadGameName; "ScreenshotFileName" = $screenshotFileName})
	}
}

	# remove temp path
	remove-item $tempPath -recurse
}

# write whdload screenshot list
[System.IO.File]::WriteAllLines($whdloadScreenshotIndexPath, $whdloadScreenshotList, [System.Text.Encoding]::UTF8)


