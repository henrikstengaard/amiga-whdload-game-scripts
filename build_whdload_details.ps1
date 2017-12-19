# Build WhdLoad Details
# ---------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-12-19
#
# A PowerShell script to build whdload details by finding exact and best matching detail items from multiple sources. 
# Lucene is used to query and find best matching detail items using keywords built from detail item id, name, publisher and languages.


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
	[string]$entriesFile,
	[Parameter(Mandatory=$true)]
	[string]$detailsSourcesFile,
	[Parameter(Mandatory=$true)]
	[int32]$minScore,
	[Parameter(Mandatory=$true)]
	[string]$entriesDetailsFile,
	[Parameter(Mandatory=$false)]
	[switch]$noExactEntryNameMatching,
	[Parameter(Mandatory=$false)]
	[switch]$noExactWhdloadSlaveNameMatching,
	[Parameter(Mandatory=$false)]
	[switch]$noExactFilteredNameMatching
)


# lucene
$analyzer  = [StandardAnalyzer]::new("LUCENE_CURRENT")
$directory = [RAMDirectory]::new()


# index items
function IndexItems($items)
{
    $writer = [IndexWriter]::new($directory,$analyzer,$true,[IndexWriter+MaxFieldLength]::new(25000))

    foreach ($item in $items)
	{
        $document = [Document]::new()
        $document.Add([Field]::new("Keywords",$item._Keywords,"YES","ANALYZED"))
		$document.Add([Field]::new("Data",($item | ConvertTo-Json),"YES","NOT_ANALYZED"))
        $writer.AddDocument($document)
    }

    $writer.close()
}


# search items
function SearchItems($q)
{
	if (!$q)
	{
		return $null
	}

	if ($q -notmatch ' 1\s*')
	{
		$q += ' 1'
	}

	try
	{
		$searcher = [IndexSearcher]::new($directory, $true)
		$parser = [QueryParser]::new("LUCENE_CURRENT", "Keywords", $analyzer)    
		$query = $parser.Parse($q)
		$result = $searcher.Search($query, $null, 100)
		$hits = $result.ScoreDocs

		$results = @()
		
		foreach($hit in $hits)
		{
			$document = $searcher.Doc($hit.doc)
			$data = $document.Get("Data") | ConvertFrom-Json
			$results += , @{ "Score" = $hit.score; "Item" = $data }
		}
	}
	catch
	{
		Write-Error "Failed to search items with query '$q': $($_.Exception.Message)"
	}

	return $results
}



# get index name from first character in name
function GetIndexName($name)
{
	$name = $name -replace '^[^a-z0-9]+', ''

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

function FindBestMatchingItems($query)
{
	$screenshots = $null

	$strictQuery = [string]::join(' ', ($query -split ' ' | % { "+{0}*" -f $_ }))
	$simpleQuery = [string]::join(' ', ($query -split ' ' | % { "{0}*" -f $_ }))

	$bestMatchingItems = @()
	$bestMatchingItems += SearchItems $strictQuery
	$bestMatchingItems += SearchItems $simpleQuery
	$bestMatchingItems += SearchItems $query

	if ($minScore)
	{
		$screenshots = $bestMatchingItems | Where { $_.Score -ge $minScore } | sort @{expression={$_.Score};Ascending=$false}
	}
	else
	{
		$screenshots = $bestMatchingItems | sort @{expression={$_.Score};Ascending=$false}
	}

	return $screenshots
}


function ConvertRoman([string]$text)
{
	$text = $text -replace " vii ", " 7 " -replace " vi ", " 6 " -replace " v ", " 5 " -replace " iv ", " 4 " -replace " iii ", " 3 " -replace " ii ", " 2 " -replace " i ", " 1 "

	return $text
}

function MakeKeywords([string]$text)
{
	$text = " " + $text + " "

	$text = $text -replace '[\.]', ''
	
	# change odd chars to space
	$text = $text -replace "[&\-_\(\):\.,!\\/+\*\?\[\]]", " "

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
	
	# replace multiple space with a single space
	$text = $text -replace "\s+", " "
	
	return $text.ToLower().Trim()
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

function PatchDiacritics([string]$text)
{
	return $text -replace 'æ', 'ae' -replace 'ø', 'oe' -replace 'å', 'aa'
}

function Normalize([string]$text)
{
	return RemoveDiacritics (ConvertSuperscript (PatchDiacritics $text))
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

function AddDetailItemColumns($entry, $detailItem)
{
	foreach($property in $detailItem.psobject.Properties)
	{
		if ($property.Value -eq $null)
		{
			continue
		}

		$entry | Add-Member -MemberType NoteProperty -Name ('Detail' + $property.Name) -Value $property.Value -Force
	}
}


# resolve paths
$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
$detailsSourcesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($detailsSourcesFile)
$entriesDetailsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesDetailsFile)


# read whdload slaves
$entries = @()
$entries += Import-Csv -Delimiter ';' $entriesFile | Sort-Object @{expression={$_.EntryName};Ascending=$true} 

# read screenshot sources
$detailSources = @()
$detailSources += Import-Csv -Delimiter ';' $detailsSourcesFile

$detailSourceIndex = @{}

# Process detail items for exact matching
for ($priority = 0; $priority -lt $detailSources.Count;$priority++)
{
	$detailSource = $detailSources[$priority]
	$detailsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($detailSource.DetailsFile)
	$detailItems = Import-Csv -Delimiter ';' $detailsFile

	Write-Host ("Indexing " + $detailItems.Count + " detail items from '" + $detailSource.SourceName + "' for exact matching...")
	$detailItemsIndex = @{}

	foreach($detailItem in $detailItems)
	{
		$nameKeywords = MakeKeywords (Normalize $detailItem.Name)
		$comparableName = $nameKeywords -replace '\s+', ''
		$comparableFileName = (MakeFileName (Normalize $detailItem.Name)) -replace '[-]+', ''

		$keywords = @($nameKeywords, $comparableName)

		if ($detailItem.Id)
		{
			$keywords +=, $detailItem.Id
		}

		if ($detailItem.Publisher)
		{
			$keywords +=, (MakeKeywords (Normalize $detailItem.Publisher))
		}

		if ($detailItem.Groups)
		{
			$comparableFileName += (MakeFileName (Normalize $detailItem.Groups)) -replace '[-]+', ''
			$keywords +=, (MakeKeywords (Normalize $detailItem.Groups))
		}

		$keywords += $comparableFileName

		if ($detailItem.Languages)
		{
			$keywords +=, ($detailItem.Languages.ToLower())
		}

		$detailItem | Add-Member -MemberType NoteProperty -Name '_Keywords' -Value ([string]::Join(" ", $keywords))

		# add comparableFileName
		if ($detailItemsIndex.ContainsKey($comparableFileName))
		{
			$identicalDetailItems = $detailItemsIndex.Get_Item($comparableFileName)
		}
		else
		{
			$identicalDetailItems = @()
		}

		$identicalDetailItems +=, $detailItem

		$detailItemsIndex.Set_Item($comparableFileName, $identicalDetailItems)



		# add comparableName
		if ($detailItemsIndex.ContainsKey($comparableName))
		{
			$identicalDetailItems = $detailItemsIndex.Get_Item($comparableName)
		}
		else
		{
			$identicalDetailItems = @()
		}

		$identicalDetailItems +=, $detailItem

		$detailItemsIndex.Set_Item($comparableName, $identicalDetailItems)
	}
	Write-Host ("Done")

	Write-Host ("Finding exact matching detail items from '" + $detailSource.SourceName + "'...")
	foreach($entry in ($entries | Where-Object { $_.DetailMatch -eq $null }))
	{
		$name = $entry.EntryName.ToLower()

		$detailItem = $null
		$matchingDetailItems = $null

		# use whdload name to get exact matching detail items
		if (!$noExactEntryNameMatching -and $detailItemsIndex.ContainsKey($name))
		{
			$matchingDetailItems = $detailItemsIndex.Get_Item($name)
		}

		# use query to get exact matching detail items
		if (!$matchingDetailItems)
		{
			$query = $entry.Query -replace '[-\s]+', ''
			$matchingDetailItems = $detailItemsIndex.Get_Item($query)
		}

		# use filtered name to get exact matching detail items
		if (!$noExactFilteredNameMatching -and !$matchingDetailItems -and $entry.FilteredName)
		{
			$filteredName = $entry.FilteredName.ToLower()
			$matchingDetailItems = $detailItemsIndex.Get_Item($filteredName)
		}

		# use whdload slave name to get exact matching detail items
		if (!$noExactWhdloadSlaveNameMatching -and !$matchingDetailItems -and $entry.WhdloadSlaveName)
		{
			$whdloadSlaveNameKeywords = (MakeKeywords (Normalize $entry.WhdloadSlaveName)) -replace '\s+', ''
			$matchingDetailItems = $detailItemsIndex.Get_Item($whdloadSlaveNameKeywords)
		}

		# use first part of whdload name to get exact matching detail items, if it contains a question mark
		if (!$matchingDetailItems -and ($name -match '&'))
		{
			$nameFirstPart = $name -replace '^([^&]+).+', '$1'
			$matchingDetailItems = $detailItemsIndex.Get_Item($nameFirstPart)
		}

		# skip whdload slave, if no matching detail items exist
		if (!$matchingDetailItems)
		{
			continue
		}

		# get first matching detail item
		$detailItem = $matchingDetailItems | Select-Object -First 1

		# add exact matching detail item match, score and source
		$entry | Add-Member -MemberType NoteProperty -Name 'DetailMatch' -Value 'Exact'
		$entry | Add-Member -MemberType NoteProperty -Name 'DetailScore' -Value '100'
		$entry | Add-Member -MemberType NoteProperty -Name 'DetailSource' -Value $detailSource.SourceName

		# add detail item columns to entry
		AddDetailItemColumns $entry $detailItem
	}
	Write-Host ("Done")

	$detailSourceIndex.Set_Item($detailSource.SourceName, $detailItems)
}


# Process detail items for best matching
for ($priority = 0; $priority -lt $detailSources.Count;$priority++)
{
	$detailSource = $detailSources[$priority]
	$detailItems = $detailSourceIndex.Get_Item($detailSource.SourceName)

	Write-Host ("Indexing " + $detailItems.Count + " detail items from '" + $detailSource.SourceName + "' for best matching...")
	IndexItems $detailItems
	Write-Host ("Done")

	Write-Host ("Finding best matching detail items from '" + $detailSource.SourceName + "'...")
	foreach($entry in ($entries | Where-Object { $_.DetailMatch -eq $null }))
	{
		$matchingDetailItems = FindBestMatchingItems $entry.Query

		# skip whdload slave, if no matching detail items exist
		if (!$matchingDetailItems)
		{
			continue
		}

		# get first matching detail item
		$firstMatchingDetailItem = $matchingDetailItems | Select-Object -First 1
		$detailItem = $firstMatchingDetailItem.Item

		# add best matching detail item match, score and source
		$entry | Add-Member -MemberType NoteProperty -Name 'DetailMatch' -Value 'Best'
		$entry | Add-Member -MemberType NoteProperty -Name 'DetailScore' -Value $firstMatchingDetailItem.Score
		$entry | Add-Member -MemberType NoteProperty -Name 'DetailSource' -Value $detailSource.SourceName

		# add detail item columns to entry
		AddDetailItemColumns $entry $detailItem
	}
	Write-Host ("Done")
}


# Write number of entries that doesn't have a detail match
$entriesNoMatch = @()
$entriesNoMatch += $entries | Where-Object { $_.DetailMatch -eq $null }
Write-Host ("{0} whdload slaves doesn't have a detail match" -f $entriesNoMatch.Count)


# Write entries details file
$entries | export-csv -delimiter ';' -path $entriesDetailsFile -NoTypeInformation -Encoding UTF8