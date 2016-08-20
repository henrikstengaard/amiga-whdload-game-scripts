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
	[string]$screenshotQueriesFile,
	[Parameter(Mandatory=$true)]
	[string]$screenshotSourcesFile,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$false)]
	[int32]$minScore,
	[Parameter(Mandatory=$false)]
	[switch]$noConvertScreenshots,
	[Parameter(Mandatory=$false)]
	[switch]$ignorePriority
)


# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


# programs 
$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
$nconvertPath = "${Env:ProgramFiles(x86)}\XnView\nconvert.exe"
$imageMagickConvertPath = "$env:ProgramFiles\ImageMagick-6.9.3-Q8\convert.exe"
$imgToIffAgaPath = [System.IO.Path]::Combine($scriptPath, "ags2_iff\imgtoiff-aga.py")
$imgToIffOcsPath = [System.IO.Path]::Combine($scriptPath, "ags2_iff\imgtoiff-ocs.py")


$convertScreenshotPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("convert_screenshot.ps1")


# lucene
$analyzer  = [StandardAnalyzer]::new("LUCENE_CURRENT")
$directory = [RAMDirectory]::new()


# cache for screenshots
$screenshotCache = @{}

# index screenshots
function IndexScreenshots($screenshots)
{
    $writer = [IndexWriter]::new($directory,$analyzer,$true,[IndexWriter+MaxFieldLength]::new(25000))

    foreach ($screenshot in $screenshots)
	{
        $document = [Document]::new()
        $document.Add([Field]::new("Keywords",$screenshot.Keywords,"YES","ANALYZED"))
		$document.Add([Field]::new("Name",$screenshot.Name,"YES","NOT_ANALYZED"))
        $document.Add([Field]::new("File",$screenshot.File,"YES","NOT_ANALYZED"))
        $document.Add([Field]::new("Priority",$screenshot.Priority,"YES","NOT_ANALYZED"))
        $writer.AddDocument($document)
    }

    $writer.close()
}

function SearchScreenshots($q)
{
	if ($q -notmatch ' 1\s*')
	{
		$q += ' 1'
	}

	$searcher = [IndexSearcher]::new($directory, $true)
	$parser = [QueryParser]::new("LUCENE_CURRENT", "Keywords", $analyzer)
	$parser.AllowLeadingWildcard = $true    
	$query = $parser.Parse($q)
	$result = $searcher.Search($query, $null, 100)
	$hits = $result.ScoreDocs

	$screenshots = @()
	
    foreach($hit in $hits)
	{
		$document = $searcher.Doc($hit.doc)
		$screenshots += , @{ "Score" = $hit.score; "Keywords" = $document.Get("Keywords"); "Name" = $document.Get("Name"); "Priority" = $document.Get("Priority"); "File" = $document.Get("File") }
	}

	return $screenshots
}


function MakeFileName([string]$text)
{
	$text = $text.ToLower()
	$text = $text -replace "[^0-9a-z_\-\.']", " "
	$text = $text -replace "['\.]", ""
	$text = $text.Trim()
	$text = $text -replace "\s+", "-"
	$text = $text -replace "\-+", "-"
	
	return $text
}

function ConvertRoman([string]$text)
{
	$text = $text -replace " vii ", " 7 " -replace " vi ", " 6 " -replace " v ", " 5 " -replace " iv ", " 4 " -replace " iii ", " 3 " -replace " ii ", " 2 " -replace " i ", " 1 "

	return $text
}

function MakeName([string]$text)
{
	# change odd chars to space
	$text = $text -replace "[&\-_\(\):\.,!\\/+\*\?']", " "

	$text = ConvertRoman $text

	$text = $text -replace "\s+", ""
	
	return $text.ToLower().Trim()
}


function MakeKeywords([string]$text)
{
	$text = " " + $text + " "

	$text = $text -replace '[\.]', ''
	
	# change odd chars to space
	$text = $text -replace "[&\-_\(\):\.,!\\/+\*\?]", " "

	# remove the and demo
	#$text = $text -replace "the", " " -replace "demo", " "
	
	# replace roman numbers
	# $text = $text -replace " vii ", " 7 " -replace " vi ", " 6 " -replace " v ", " 5 " -replace " iv ", " 4 " -replace " iii ", " 3 " -replace " ii ", " 2 " -replace " i ", " 1 "
	$text = ConvertRoman $text
	
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
	#$text = $text -creplace '([A-Z])([A-Z])', '$1 $2' -creplace '([A-Z])([A-Z])', '$1 $2'

	#$text = $text -creplace '([A-Z]+)([a-z0-9])', '$1 $2'

	# replace multiple space with a single space
	$text = $text -replace "\s+", " "
	
	return $text.ToLower().Trim()
}

function UniqueWords($text)
{
	$keywords = ($text) -split ' '

	$keywordIndex = @{}
	$uniqueKeywords = @()
	
	foreach($keyword in $keywords)
	{
		if ($keywordIndex.ContainsKey($keyword))
		{
			$keywordCount = $keywordIndex.Get_Item($keyword)
		}
		else
		{
			$keywordCount = 0
		}
		
		$keywordCount++
		
		if ($keywordCount -eq 1)
		{
			$uniqueKeywords +=, $keyword
		}
		
		$keywordIndex.Set_Item($keyword, $keywordCount)
	}
	
	return [string]::Join(" ", $uniqueKeywords)
}

# read screenshot list
function ReadScreenshotList($screenshotSourcesIndexDir, $screenshotSource, $priority)
{
	$screenshotIndexFile = [System.IO.Path]::Combine($screenshotSourcesIndexDir, $screenshotSource.SourceName.ToLower() + ".csv")

	$screenshots = @()
	
	if (Test-Path $screenshotIndexFile)
	{
		$screenshots += (Import-Csv -Delimiter ';' $screenshotIndexFile)
	}
	else 
	{
		$screenshotPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($screenshotSource.ScreenshotPath)

		Write-Host ("Building screenshot list from '$screenshotPath' with filter '" + $screenshotSource.Filter + "'...")

		$screenshotFiles = Get-ChildItem -include *.iff,*.png,*.jpg,*.gif,*.jpeg,*.tif,*.bmp -File -recurse -Path $screenshotPath | Sort-Object $_.FullName

		if ($screenshotSource.Filter)
		{
			$screenshotFiles = $screenshotFiles | Where { $_.FullName -match $screenshotSource.Filter }
		}
		
		ForEach ($screenshotFile in $screenshotFiles)
		{
			if ($screenshotSource.UseDirectoryName -eq "1")
			{
				$screenshotName = [System.IO.Path]::GetFileName($screenshotFile.Directory)
			}
			else
			{
				$screenshotName = [System.IO.Path]::GetFileNameWithoutExtension($screenshotFile.FullName)

				if ($screenshotName -match '_\d+$')
				{
					$screenshotName = $screenshotName -replace "_\d+$", ""
				}
			}

			$keywords = UniqueWords (MakeKeywords $screenshotName)

			$screenshots += New-Object psobject -property @{ "Keywords" = $keywords; "Name" = $screenshotName; "Priority" = $priority; "File" = $screenshotFile.FullName }
		}

		$screenshots | Export-Csv -Delimiter ';' -Path $screenshotIndexFile -NoTypeInformation

		Write-Host "Done"
	}
	
	return $screenshots
}


# get index name from first character in name
function GetIndexName($name)
{
	if ($name -match '^[0-9]') 
	{
		$indexName = "0"
	}
	else
	{
		$indexName = $name.Substring(0,1)
	}

	return $indexName
}

function RemoveDiacritics([string]$text)
{
	$textFormD = $text.Normalize([System.Text.NormalizationForm]::FormD).ToCharArray()
	$sb = New-Object -TypeName "System.Text.StringBuilder"

	ForEach ($c in $textFormD)
	{
		$uc = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
		if ($uc -ne [System.Globalization.UnicodeCategory]::NonSpacingMark)
		{
			[void]$sb.Append($c)
		}
	}
	
	return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function ConvertSuperscript([string]$text)
{
	$textFormKd = $text.Normalize([System.Text.NormalizationForm]::FormKD).ToCharArray()
	$sb = New-Object -TypeName "System.Text.StringBuilder"

	ForEach ($c in $textFormKd)
	{
		$uc = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
		if ($uc -ne [System.Globalization.UnicodeCategory]::NonSpacingMark)
		{
			[void]$sb.Append($c)
		}
	}

	return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormKC)
}

function Normalize([string]$text)
{
	return RemoveDiacritics (ConvertSuperscript $text)
}

function FindBestMatchingScreenshot($screenshotQuery)
{
	$query = $screenshotQuery.ScreenshotQuery
	$screenshot = $null

	# if ($screenshotCache.ContainsKey($query))
	# {
	# 	$screenshot = $screenshotCache.Get_Item($query)
	# }
	# else
	# {
		$strictQuery = [string]::join(' ', ($query -split ' ' | % { "+{0}*" -f $_ }))
		$simpleQuery = [string]::join(' ', ($query -split ' ' | % { "{0}*" -f $_ }))

		$bestMatchingScreenshots = @()
		$bestMatchingScreenshots += SearchScreenshots $strictQuery
		$bestMatchingScreenshots += SearchScreenshots $simpleQuery
		$bestMatchingScreenshots += SearchScreenshots $query

		# foreach($bestMatchingScreenshot in $bestMatchingScreenshots)
		# {
		# 	$bestMatchingScreenshot.Keywords -split ' ' | Where { ($_ -notmatch '(demo|the)') -and ($query -notmatch $_) } | % { $bestMatchingScreenshot.Score -= 1 }
		# }

		if ($minScore)
		{
			$screenshot = $bestMatchingScreenshots | Where { $_.Score -ge $minScore } | sort @{expression={$_.Score};Ascending=$false} | Select-Object -First 1
		}
		else
		{
			$screenshot = $bestMatchingScreenshots | sort @{expression={$_.Score};Ascending=$false} | Select-Object -First 1
		}

	# 	$screenshotCache.Set_Item($query, $screenshot)
	# }

	return $screenshot
}


$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)

# Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}




# $screenshots = @()
# $screenshots += @{ "Keywords" = "thuglife essence"; "Name" = "thuglifeessence"; "_Priority" = 1; "File" = "thuglife-essence\screen.png" }
# $screenshots += @{ "Keywords" = "top karaoke vol 1 inspector gadget saturne"; "Name" = "topkaraokevol1inspectorgadgetsaturne"; "_Priority" = 1; "File" = "top-karaoke-vol1-inspector-gadget--saturne\screen.png" }

# # Index screenshots
# # -----------------
# Write-Host "Indexing $($screenshots.Count) screenshots with priority $p..."
# IndexScreenshots $screenshots
# Write-Host "Done"

# SearchScreenshots 'thug* life* essence*'
# SearchScreenshots 'top karaoke 1 inspecteur gadget saturne'

#exit 0




# Read screenshot queries
$screenshotQueries = @()
$screenshotQueries += (Import-Csv -Delimiter ';' ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($screenshotQueriesFile)))


# Read screenshot sources
$screenshotSourcesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($screenshotSourcesFile)
$screenshotSourcesIndexDir = [System.IO.Path]::GetDirectoryName($screenshotSourcesFile)

$screenshotSources = @()
$screenshotSources += (Import-Csv -Delimiter ';' $screenshotSourcesFile)

$screenshots = @()

for ($i = 0; $i -lt $screenshotSources.Count; $i++)
{
	$priority = $i + 1
 	$screenshotSource = $screenshotSources[$i]
 	$screenshots += ReadScreenshotList $screenshotSourcesIndexDir $screenshotSource $priority
}

# $screenshots | Where { $_.Name -match 'thuglife' }
# $screenshots | Where { $_.Name -match 'topkaraoke' }

# exit 0

# Index screenshots
$screenshotsIndex = @{}

foreach($screenshot in $screenshots)
{
	$name = $screenshot.Name.ToLower() -replace '-',''

	if ($screenshotsIndex.ContainsKey($name))
	{
		$matchingScreenshots = $screenshotsIndex.Get_Item($name)
	}
	else
	{
		$matchingScreenshots = @()
	}
	
	$matchingScreenshots +=, $screenshot
		
	$screenshotsIndex.Set_Item($name, $matchingScreenshots)
}


# Find exact matching screenshots
ForEach ($screenshotQuery in $screenshotQueries)
{
	$name = $screenshotQuery.WhdloadName.ToLower()

	# find screenshots using whdload name
	$matchingScreenshots = $screenshotsIndex.Get_Item($name)

	# use query to find exact matches
	if (!$matchingScreenshots)
	{
		$query = $screenshotQuery.ScreenshotQuery.ToLower() -replace '[- ]+', ''
		$matchingScreenshots = $screenshotsIndex.Get_Item($query)
	}

	# try finding screenshots using filtered name
	if (!$matchingScreenshots -and $screenshotQuery.FilteredName)
	{
		$filteredName = $screenshotQuery.FilteredName.ToLower()
		$matchingScreenshots = $screenshotsIndex.Get_Item($filteredName)
	}

	# try finding screenshots using whdload slave name
	if (!$matchingScreenshots -and $screenshotQuery.WhdloadSlaveName)
	{
		$whdloadSlaveName = $screenshotQuery.WhdloadSlaveName.ToLower() -replace '\s+', ''
		$matchingScreenshots = $screenshotsIndex.Get_Item($whdloadSlaveName)
	}

	# if question mark, try find
	if (!$matchingScreenshots -and ($name -match '&'))
	{
		$nameFirstPart = $name -replace '^([^&]+).+', '$1'
		$matchingScreenshots = $screenshotsIndex.Get_Item($nameFirstPart)
	}

	if (!$matchingScreenshots)
	{
		continue
	}

	if ($ignorePriority)
	{
		$screenshot = $matchingScreenshots | Select-Object -First 1
	}
	else 
	{
		$screenshot = $matchingScreenshots | sort @{expression={$_.Priority};Ascending=$true} | Select-Object -First 1
	}

	# skip, if no screenshot
	if (!$screenshot)
	{
		return
	}

	# Add screenshot match, name and file to query
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotMatch' -Value 'Exact'
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotScore' -Value '100'
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotName' -Value $screenshot.Name
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotFile' -Value $screenshot.File
}

# $screenshots | Where { $_.Name -match 'mummy' }

if ($ignorePriority)
{
	# Index screenshots
	# -----------------
	Write-Host "Indexing $($screenshots.Count) screenshots..."
	IndexScreenshots $screenshots
	Write-Host "Done"

# 	$q1 = $screenshotQueries | Where { $_.WhdloadName -match 'MysteryOfTheMummy' } | Select-Object -First 1
# $q1
# 	FindBestMatchingScreenshot $q1
# 	exit 0
		# "- thug life essence"
		# $q1 = $screenshotQueries | Where { $_.ScreenshotQuery -match 'thug life essence' } | Select-Object -First 1
		# #$q1.ScreenshotQuery = '+thug* +life* +essence*'
		# FindBestMatchingScreenshot $q1
		# "- top karaoke 1"
		# $q2 = $screenshotQueries | Where { $_.ScreenshotQuery -match 'top karaoke 1' } | Select-Object -First 1
		# #$q2.ScreenshotQuery = '+top* +karaoke* +1*'
		# FindBestMatchingScreenshot $q2

		# exit 0

	# Find best matching screenshots for queries, which doesn't have a screenshot
	ForEach ($screenshotQuery in ($screenshotQueries | Where { $_.ScreenshotFile -eq $null }))
	{
		$screenshot = FindBestMatchingScreenshot $screenshotQuery

		# skip, if no screenshot
		if (!$screenshot)
		{
			continue
		}

		# Add screenshot match, name and file to query
		$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotMatch' -Value 'Best' -Force
		$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotScore' -Value $screenshot.Score -Force
		$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotName' -Value $screenshot.Name -Force
		$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotFile' -Value $screenshot.File -Force	
	}
}
else 
{
	for ($p = 1; $p -le $screenshotSources.Count; $p++)
	{
		# get priorpty screenshots
		$priorityScreenshots = $screenshots | Where { $_.Priority -eq $p }

		# Index screenshots
		# -----------------
		Write-Host "Indexing $($priorityScreenshots.Count) screenshots with priority $p..."
		IndexScreenshots $priorityScreenshots
		Write-Host "Done"


		# Find best matching screenshots for queries, which doesn't have a screenshot
		ForEach ($screenshotQuery in ($screenshotQueries | Where { $_.ScreenshotFile -eq $null }))
		{
			$screenshot = FindBestMatchingScreenshot $screenshotQuery

			# skip, if no screenshot
			if (!$screenshot)
			{
				continue
			}

			# if ($screenshot.Score -lt $screenshotQuery.ScreenshotScore)
			# {
			# 	continue
			# }
			# else
			# {
			# 	"found better screenshot for '" + $screenshot.Name + "': " + $screenshot.File + "'"
			# }

			# Add screenshot match, name and file to query
			$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotMatch' -Value 'Best' -Force
			$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotScore' -Value $screenshot.Score -Force
			$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotName' -Value $screenshot.Name -Force
			$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotFile' -Value $screenshot.File -Force
		}
	}
}


# write warning for whdload slaves without screenshot
ForEach ($screenshotQuery in $screenshotQueries)
{
	if ($screenshotQuery.ScreenshotFile -eq $null)
	{
		Write-Host ("Warning: No screenshot for '" + $screenshotQuery.WhdloadName + "'")
	}
}


# write screenshots list
$screenshotListFile = [System.IO.Path]::Combine($outputPath, "screenshots.csv")
$screenshotQueries | Export-Csv -Delimiter ';' -Path $screenshotListFile -NoTypeInformation


# convert screenshots
if (!$noConvertScreenshots)
{
	ForEach ($screenshotQuery in ($screenshotQueries | Where { $_.ScreenshotFile -ne $null }))
	{
		$screenshotDirectoryName = MakeFileName $screenshotQuery.ScreenshotName
		$screenshotOutputPath = [System.IO.Path]::Combine($outputPath, $screenshotDirectoryName)

		("Converting '" + $screenshotQuery.ScreenshotFile + "'...")
		
		# skip convert screenshot, if it already exist
		if(test-path -path $screenshotOutputPath)
		{
			continue
		}


		# create screenshot output path
		md $screenshotOutputPath | Out-Null
		
		# convert screenshot
		& $convertScreenshotPath -screenshotFile $screenshotQuery.ScreenshotFile -outputPath $screenshotOutputPath

		$screenshotQuery | Add-Member -MemberType NoteProperty -Name "ScreenshotOutputPath" -Value $screenshotDirectoryName
	}

}


