# Build WHDLoad Queries
# ---------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-12-22
#
# A PowerShell script to build whdload queries used for finding best matching detail and screenshot.


Param(
	[Parameter(Mandatory=$true)]
	[string]$entriesFiles,
	[Parameter(Mandatory=$true)]
	[string]$queriesFile,
	[Parameter(Mandatory=$false)]
	[string]$queryPatchesFile,
	[Parameter(Mandatory=$false)]
	[string]$removeQueryWordsPattern,
	[Parameter(Mandatory=$false)]
	[switch]$addFilteredName,
	[Parameter(Mandatory=$false)]
	[switch]$noWhdloadName,
	[Parameter(Mandatory=$false)]
	[switch]$addWhdloadSlaveName,
	[Parameter(Mandatory=$false)]
	[switch]$addWhdloadSlaveCopy,
	[Parameter(Mandatory=$false)]
	[string]$appendQueryText
)


Import-Module (Resolve-Path('text.psm1')) -Force

function MakeComparableName([string]$text)
{
	$text = " " + $text + " "

	# change odd chars to space
	#$text = $text -creplace "[&\-_\(\):\.,!\\/+\*\?]", " "
	#$text = $text -replace "[^a-z0-9]", " "
	$text = $text -replace "[^\w]", " "
	$text = $text -replace '\?', ' '
	$text = $text -replace '[\.]', ''
	$text = $text -replace "[&\-_\(\):\.,!\\/+\*\?\(\)]", " "
					
	# remove the and demo
	#$text = $text -replace "the", " " -replace "demo", " "

	#$text = $text -replace "disk", " " 
	$text = $text -replace "\(c\)", " "
	
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

	# add space between numbers and upper case letters
	$text = $text -replace "([0-9])([a-z])", "`$1 `$2"

	# add space between upper case letters and numbers
	$text = $text -creplace "([A-Z])([0-9])", "`$1 `$2"
	
	# pull 3d and 4d together
	$text = $text -replace "\s+([34])\s+([D])\s+", " `$1`$2 "

	# pull cd and 32 together
	$text = $text -replace "\s+CD\s+32\s+", " CD32 "

	# remove single letters (twice to catch all)
	$text = $text -creplace '\s+([a-z])\s+', ' ' -creplace '\s+([a-z])\s+', ' '
	
	
	# add space between upper letters (twice to catch all)
	#$text = $text -creplace '([A-Z])([A-Z])', '$1 $2' -creplace '([A-Z])([A-Z])', '$1 $2'
	#$text = $text -creplace '([A-Z]+)([a-z0-9])', '$1 $2'
	
	# replace multiple space with a single space
	$text = $text -replace "\s+", " "
	
	return $text.ToLower().Trim()
}

function RemoveWords($text, $removeWords)
{
	$keywords = ($text) -split ' '
	$newKeywords = @()

	foreach($keyword in $keywords)
	{
		if (($keyword -match '^s*$') -or ($keyword -match $removeWords))
		{
			continue
		}

		$newKeywords +=, $keyword
	}

	return [string]::Join(" ", $newKeywords)
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


# resolve paths
$queriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($queriesFile)

# read entries files
$entries = @()
foreach($entriesFile in ($entriesFiles -Split ','))
{
	$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
	Write-Host ("Reading entries file '{0}'" -f $entriesFile)
	$entries += import-csv -delimiter ';' -path $entriesFile -encoding utf8 
}

# read query patches
$queryPatches = @()
if ($queryPatchesFile)
{
	$queryPatchesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($queryPatchesFile)
	$queryPatches += (import-csv -delimiter ';' -path $queryPatchesFile -encoding utf8)
}

# build query patches index
$queryPatchesIndex = @{}
$queryPatches | % { $queryPatchesIndex.Set_Item($_.EntryName.ToLower(), $_.QueryPatch.ToLower()) }

$queryPatchCount = 0

# process whdload slave items
foreach($entry in $entries)
{
	if ($queryPatchesIndex.ContainsKey($entry.EntryName.ToLower()))
	{
		$queryPatchCount++
		$query = $queryPatchesIndex.Get_Item($entry.EntryName.ToLower())
	}
	else
	{
		$name = ""
		
		if (!$noWhdloadName)
		{
			$name = $entry.EntryName
		}

		if ($addFilteredName -and $entry.FilteredName -and ($name -ne $entry.FilteredName))
		{
			$name += " " + $entry.FilteredName
		}

		if ($addWhdloadSlaveName -and $entry.WhdloadSlaveName -and ($entry.EntryName -ne $entry.WhdloadSlaveName))
		{
			$name += " " + $entry.WhdloadSlaveName
		}

		if ($addWhdloadSlaveCopy -and $entry.WhdloadSlaveCopy)
		{
			$name += " " + ($entry.WhdloadSlaveCopy -replace '\d{4}', ' ')
		}

		$query = UniqueWords (MakeComparableName (NormalizeText $name))
		
		# remove single letters
		$words = @()
		$words += $query -split ' ' | Where-Object { $_ -notmatch '^[a-z]$' }
		$query = [string]::Join(" ", $words)

		if ($removeQueryWordsPattern -and ($removeQueryWordsPattern -ne ''))
		{
			$query = RemoveWords $query $removeQueryWordsPattern
		}

		if ($appendQueryText -and $appendQueryText -ne '')
		{
			$query += $appendQueryText
		}
	}

	$query = ($query -replace '\s+',' ').Trim()

	# Add query to whdload slave item
	$entry | Add-Member -MemberType NoteProperty -Name Query -Value $query
}

Write-Host "$queryPatchCount queries patched"

# write queries file
$entries | export-csv -delimiter ';' -path $queriesFile -NoTypeInformation -Encoding UTF8