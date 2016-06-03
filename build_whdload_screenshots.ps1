# Build WHDLoad Screenshots
# -------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-06-03
#
# A PowerShell script to build whdload screenshots for iGame and AGS2 in AGA and OCS mode.
# Lucene is used to index screenshots for better search and matching between games and screenshots
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


using assembly Lucene.Net.dll

using namespace System.IO
using namespace Lucene.Net.Analysis
using namespace Lucene.Net.Analysis.Standard
using namespace Lucene.Net.Documents
using namespace Lucene.Net.Index
using namespace Lucene.Net.QueryParsers
using namespace Lucene.Net.Store
using namespace Lucene.Net.Util
using namespace Lucene.Net.Search

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


# screenshot paths
$screenshotPath = [System.IO.Path]::Combine($scriptPath, "screenshots")
$troelsDkScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "iGameUpdatePackTroelsDK")
$gameBaseAmigaScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "GameBase Amiga v2.0 Screenshots")
$openAmigaGameDatabaseScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "Open Amiga Game Database")
$lemonAmigaScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "Lemon Amiga")
$igameGameplayScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "iGame_Gameplay_Shots_256")
$customScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "Custom")


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


# lucene
$analyzer  = [StandardAnalyzer]::new("LUCENE_CURRENT")
$directory = [RAMDirectory]::new()



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

	if (Test-Path -Path $whdloadGameSlaveIndexFile)
	{
		ForEach($line in (Get-Content $whdloadGameSlaveIndexFile | Select-Object -Skip 1))
		{
			$columns = $line -split ";"
			$index += , $columns
		}
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

# index screenshots
function IndexScreenshots($screenshots)
{
    $writer = [IndexWriter]::new($directory,$analyzer,$true,[IndexWriter+MaxFieldLength]::new(25000))

    foreach ($screenshot in $screenshots)
	{
        $document = [Document]::new()
        $document.Add([Field]::new("Name",$screenshot.Name,"YES","ANALYZED"))
        $document.Add([Field]::new("File",$screenshot.File,"YES","NOT_ANALYZED"))
        $document.Add([Field]::new("Priority",$screenshot.Priority,"YES","NOT_ANALYZED"))
        $writer.AddDocument($document)
    }

    $writer.close()
}

function SearchScreenshots($q)
{
	$searcher = [IndexSearcher]::new($directory, $true)
	$parser = [QueryParser]::new("LUCENE_CURRENT", "Name", $analyzer)    
	$query = $parser.Parse($q)
	$result = $searcher.Search($query, $null, 100)
	$hits = $result.ScoreDocs

	$screenshots = @()
	
    foreach($hit in $hits)
	{
		$document = $searcher.Doc($hit.doc)
		$screenshots += , @{ "Score" = $hit.score; "Name" = $document.Get("Name"); "Priority" = $document.Get("Priority"); "File" = $document.Get("File") }
	}

	return $screenshots
}

# NOT TO BE USED, First attempt of making a better screenshot finding method before Lucene was introduced
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
			$exactMatchingKeywords = 0
			
			# find first name keyword index in screenshot keywords
			$nameKeywordsIndex = 0
			$screenshotKeywordsIndex = $screenshot.Keywords.IndexOf($nameKeywords[0])
			
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



function MakeComparableName([string]$text)
{
	$text = " " + $text + " "

	# change odd chars to space
	$text = $text -creplace "[&\-_\(\):\.,!+]", " "

	# remove the and demo
	#$text = $text -replace "the", " " -replace "demo", " "
	
	# replace roman numbers
	$text = $text -replace " vii ", " 7 " -replace " vi ", " 6 " -replace " v ", " 5 " -replace " iv ", " 4 " -replace " iii ", " 3 " -replace " ii ", " 2 " -replace " i ", " 1 "
	
	# remove odd chars
	$text = $text -creplace "[']", ""

	# add space between number and letters, if not the character 'D'
	$text = $text -replace "(\d+)([^d\d])", "`$1 `$2"
	
	# add space before and after 3D or 4D
	$text = $text -replace "([34]D)", " `$1 "
	
	# add space between lower and upper case letters or numbers
	$text = $text -creplace "([a-z])([A-Z0-9])", "`$1 `$2"

	# add space between upper case letters or numbers
	$text = $text -creplace "([A-Z])([0-9])", "`$1 `$2"
	
	# add space between upper letters (twice to catch all)
	$text = $text -creplace '([A-Z])([A-Z])', '$1 $2' -creplace '([A-Z])([A-Z])', '$1 $2'
	
	# replace multiple space with a single space
	$text = $text -replace "\s+", " "
	
	return $text.ToLower().Trim()
}


# read screenshot list
function ReadScreenshotList($path, $useDirectoryName, $priority, $filter)
{
	Write-Host "Building screenshot list from '$path'..."

	$screenshotFiles = Get-ChildItem -include *.iff,*.png -File -recurse -Path $path | Sort-Object $_.FullName

	if ($filter)
	{
		$screenshotFiles = $screenshotFiles | Where { $_.FullName -match $filter }
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
		
		$screenshots += @{ "Name" = $comparableName; "Priority" = $priority; "File" = $screenshotFile.FullName }
	}

	Write-Host "Done"
	
	return $screenshots
}


# Reading screenshot lists
Write-Host "Reading screenshot lists..."
$screenshots = @()
$screenshots += ReadScreenshotList $troelsDkScreenshotPath $true 1
$screenshots += ReadScreenshotList $gameBaseAmigaScreenshotPath $false 2 "_\d+\.[^\.]+`$"
$screenshots += ReadScreenshotList $openAmigaGameDatabaseScreenshotPath $true 3
$screenshots += ReadScreenshotList $lemonAmigaScreenshotPath $true 4
$screenshots += ReadScreenshotList $customScreenshotPath $true 5
Write-Host "Done"


# Index screenshots
Write-Host "Indexing $($screenshots.Count) screenshots..."
IndexScreenshots $screenshots
Write-Host "Done"


# Read whdload screenshot index
$whdloadScreenshotIndexPath = [System.IO.Path]::Combine($outputPath, "whdload_screenshots.csv")
Write-Output "Reading whdload screenshot index from '$whdloadScreenshotIndexPath'..."
$whdloadScreenshotIndex = ReadWhdloadScreenshotIndex $whdloadScreenshotIndexPath $false 
Write-Output "$($whdloadScreenshotIndex.Count) entries"
Write-Output ""


# Read whdload games index
$whdloadGameSlaveIndexFile = [System.IO.Path]::Combine($whdloadGameSlaveIndexPath, "whdload_slave_index.csv")
Write-Output "Reading whdload game slave index file '$whdloadGameSlaveIndexFile'..."
$whdloadGameSlaves = ReadWhdloadGamesSlaveIndex $whdloadGameSlaveIndexFile
Write-Output "$($whdloadGameSlaves.Count) entries"
Write-Output ""


# Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


# Cache for screenshots
$screenshotsCache = @{}


# Process whdload game files
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
		$screenshots = SearchScreenshots $screenshotGameComparableName | Select-Object -First 10

		$screenshotsCache.Set_Item($screenshotGameName, $screenshots)
	}
	
	$screenshot = $screenshots | sort @{expression={$_.Score};Ascending=$false},@{expression={$_.Priority};Ascending=$true},@{expression={$_.File};Ascending=$true} | Select-Object -First 1
	
	
	# skip, if no screenshot
	if (!$screenshot)
	{
		Add-Content $logFile "skipping $whdloadGameFileName, $whdloadGameSlaveFile, no screenshots found"
		continue
	}

	
	# get screenshot file name
	$screenshotFileName = $screenshot.File.Replace($screenshotPath + "\", "")
	
	$whdloadScreenshot = $whdloadScreenshotIndex.Get_Item($whdloadGameFileName + $whdloadGameSlaveFile)

	# skip screenshot, if it exists and is identical
	if ($whdloadScreenshot -and $whdloadScreenshot.ScreenshotFileName -eq $screenshotFileName)
	{
		Add-Content $logFile "skipping $whdloadGameFileName, new screenshots not found (" + $whdloadScreenshot.ScreenshotFileName + " <-> " + $screenshotFileName + ")"
		continue
	}

	
	# write game name
	#Write-Host "$whdloadGameName (", $whdloadScreenshot.ScreenshotFileName, "<->", $screenshotFileName, ")"
	

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


# write whdload screenshot list
$whdloadScreenshotList = @( """WhdloadGameFileName"";""WhdloadSlaveFile"";""WhdloadGameName"";""ScreenshotFileName""" )

ForEach($key in ($whdloadScreenshotIndex.Keys | Sort-Object))
{
	$whdloadScreenshot = $whdloadScreenshotIndex.Get_Item($key)

	# add screenshot to list
	$whdloadScreenshotList += """" + $whdloadScreenshot.WhdloadGameFileName + """;""" + $whdloadScreenshot.WhdloadGameSlaveFile + """;""" + $whdloadScreenshot.WhdloadGameName + """;""" + $whdloadScreenshot.ScreenshotFileName + """"
}

# write whdload screenshot list
[System.IO.File]::WriteAllLines($whdloadScreenshotIndexPath, $whdloadScreenshotList, [System.Text.Encoding]::UTF8)


