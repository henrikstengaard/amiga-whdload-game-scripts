# Build WHDLoad Screenshots
# -------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-06-03
#
# A PowerShell script to build whdload screenshots for iGame and AGS2 in AGA and OCS mode.
# Lucene is used to index screenshots for better search and matching between games and screenshots


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
	[switch]$noConvertScreenshots
)


# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


# programs 
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
	$query = $screenshotQuery.Query
	$screenshot = $null

	$strictQuery = [string]::join(' ', ($query -split ' ' | % { "+{0}*" -f $_ }))
	$simpleQuery = [string]::join(' ', ($query -split ' ' | % { "{0}*" -f $_ }))

	$bestMatchingScreenshots = @()
	$bestMatchingScreenshots += SearchScreenshots $strictQuery
	$bestMatchingScreenshots += SearchScreenshots $simpleQuery
	$bestMatchingScreenshots += SearchScreenshots $query

	if ($minScore)
	{
		$screenshot = $bestMatchingScreenshots | Where { $_.Score -ge $minScore } | sort @{expression={$_.Score};Ascending=$false} | Select-Object -First 1
	}
	else
	{
		$screenshot = $bestMatchingScreenshots | sort @{expression={$_.Score};Ascending=$false} | Select-Object -First 1
	}

	return $screenshot
}


$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)

# Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


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

	Write-Host ("Reading screenshot list from '" + $screenshotSource.SourceName + "'...")
 	$screenshots += ReadScreenshotList $screenshotSourcesIndexDir $screenshotSource $priority
	Write-Host ("Done")
}


# index screenshots for exact matching
Write-Host ("Indexing " + $screenshots.Count + " screenshots for exact matching...")
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
Write-Host ("Done")


# find exact matching screenshots
Write-Host ("Finding exact matching screenshots...")
ForEach ($screenshotQuery in $screenshotQueries)
{
	$name = $screenshotQuery.WhdloadName.ToLower()

	# find screenshots using whdload name
	$matchingScreenshots = $screenshotsIndex.Get_Item($name)

	# use query to find exact matches
	if (!$matchingScreenshots)
	{
		$query = $screenshotQuery.Query.ToLower() -replace '[- ]+', ''
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


	$screenshot = $matchingScreenshots | Select-Object -First 1

	# skip, if no screenshot
	if (!$screenshot)
	{
		return
	}

	$screenshotDirectoryName = MakeFileName $screenshot.Name

	# Add screenshot match, name and file to query
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotMatch' -Value 'Exact' -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotScore' -Value '100' -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotName' -Value $screenshot.Name -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotFile' -Value $screenshot.File -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotDirectoryName' -Value $screenshotDirectoryName -Force
}
Write-Host ("Done")


# index screenshots for best matching
Write-Host ("Indexing " + $screenshots.Count + " screenshots for best matching...")
IndexScreenshots $screenshots
Write-Host "Done"


# find best matching screenshots
Write-Host ("Finding best matching screenshots...")
ForEach ($screenshotQuery in ($screenshotQueries | Where { $_.ScreenshotFile -eq $null }))
{
	$screenshot = FindBestMatchingScreenshot $screenshotQuery

	# skip, if no screenshot
	if (!$screenshot)
	{
		continue
	}

	$screenshotDirectoryName = MakeFileName $screenshot.Name

	# Add screenshot match, name and file to query
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotMatch' -Value 'Best' -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotScore' -Value $screenshot.Score -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotName' -Value $screenshot.Name -Force
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotFile' -Value $screenshot.File -Force	
	$screenshotQuery | Add-Member -MemberType NoteProperty -Name 'ScreenshotDirectoryName' -Value $screenshotDirectoryName -Force
}
Write-Host "Done"


# Write number of whdload slaves that doesn't have a screenshot match
Write-Host ("" + ($screenshotQueries | Where { $_.ScreenshotMatch -eq $null }).Count + " whdload slaves doesn't have a screenshot match")


# write screenshots list
$screenshotListFile = [System.IO.Path]::Combine($outputPath, "screenshots.csv")
$screenshotQueries | Export-Csv -Delimiter ';' -Path $screenshotListFile -NoTypeInformation


# convert screenshots
if (!$noConvertScreenshots)
{
	$whdloadSlavesWithScreenshots = ($screenshotQueries | Where { $_.ScreenshotFile -ne $null })
	Write-Host ("Converting " + $whdloadSlavesWithScreenshots.Count + " screenshots...")
	ForEach ($screenshotQuery in $whdloadSlavesWithScreenshots)
	{
		$screenshotOutputPath = [System.IO.Path]::Combine($outputPath, $screenshotQuery.ScreenshotDirectoryName)

		# skip convert screenshot, if it already exist
		if(test-path -path $screenshotOutputPath)
		{
			continue
		}

		# create screenshot output path
		md $screenshotOutputPath | Out-Null
		
		# convert screenshot
		& $convertScreenshotPath -screenshotFile $screenshotQuery.ScreenshotFile -outputPath $screenshotOutputPath
	}
	Write-Host "Done"
}