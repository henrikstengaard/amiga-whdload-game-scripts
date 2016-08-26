# Build AGS2 Menu
# ---------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-06-24
#
# A PowerShell script to build AGS2 menu.


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
	[string]$whdloadSlavesFile,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$true)]
	[string]$assignName,
	[Parameter(Mandatory=$false)]
	[string]$detailSourcesFile,
	[Parameter(Mandatory=$false)]
	[int32]$minScore,
	[Parameter(Mandatory=$false)]
	[string]$whdloadScreenshotsFile,
	[Parameter(Mandatory=$false)]
	[switch]$usePartitions,
	[Parameter(Mandatory=$false)]
	[int32]$partitionSplitSize,
	[Parameter(Mandatory=$false)]
	[switch]$aga
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
	return RemoveDiacritics (PatchDiacritics (ConvertSuperscript $text))
}



# resolve paths
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
$whdloadSlavesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSlavesFile)
$whdloadScreenshotsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadScreenshotsFile)
$detailSourcesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($detailSourcesFile)


# read whdload slaves
$whdloadSlaves = Import-Csv -Delimiter ';' $whdloadSlavesFile | sort @{expression={$_.WhdloadName};Ascending=$true} 

# read whdload screenshots file
$whdloadScreenshots = Import-Csv -Delimiter ';' $whdloadScreenshotsFile

# read screenshot sources
$detailSources = Import-Csv -Delimiter ';' $detailSourcesFile

$detailSourceIndex = @{}




#
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
		$publisherKeywords = MakeKeywords (Normalize $detailItem.Publisher)
		$comparableName = $nameKeywords -replace '\s+', ''
		$languages =  $detailItem.Languages.ToLower()
		$detailItem | Add-Member -MemberType NoteProperty -Name '_Keywords' -Value ($nameKeywords + " " + $detailItem.Id + " " + $publisherKeywords + " " + $comparableName  + " " + $languages)

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
	foreach($whdloadSlave in ($whdloadSlaves | Where { $_.DetailMatch -eq $null }))
	{
		$name = $whdloadSlave.WhdloadName.ToLower()

		$detailItem = $null
		$matchingDetailItems = $null

		# use whdload name to get exact matching detail items
		if ($detailItemsIndex.ContainsKey($name))
		{
			$matchingDetailItems = $detailItemsIndex.Get_Item($name)
		}

		# use query to get exact matching detail items
		if (!$matchingDetailItems)
		{
			$query = $whdloadSlave.Query -replace '[-\s]+', ''
			$matchingDetailItems = $detailItemsIndex.Get_Item($query)
		}

		# use filtered name to get exact matching detail items
		if (!$matchingDetailItems -and $whdloadSlave.FilteredName)
		{
			$filteredName = $whdloadSlave.FilteredName.ToLower()
			$matchingDetailItems = $detailItemsIndex.Get_Item($filteredName)
		}

		# use whdload slave name to get exact matching detail items
		if (!$matchingDetailItems -and $whdloadSlave.WhdloadSlaveName)
		{
			$whdloadSlaveNameKeywords = (MakeKeywords (Normalize $whdloadSlave.WhdloadSlaveName)) -replace '\s+', ''
			$matchingDetailItems = $detailItemsIndex.Get_Item($whdloadSlaveNameKeywords)
		}

		# use first part of whdload name to get exact matching detail items, if it contains a question mark
		if (!$matchingDetailItems -and ($name -match '&'))
		{
			$nameFirstPart = $name -replace '^([^&]+).+', '$1'
			$matchingDetailItems = $detailItemsIndex.Get_Item($nameFirstPart)
		}


		if ($name -match '^bloodnet' -or $name -match 'babylonian')
		{
			">>> '" + $whdloadSlave.WhdloadName + "', '$name' <<<"
			">>> " + $matchingDetailItems.Count + " hits"
			$detailItemsIndex.Keys | Where { $_ -match '^blood' -or $_ -match 'baby' }
		}

		if (!$matchingDetailItems)
		{
			continue
		}

		$detailItem = $matchingDetailItems | Select-Object -First 1

		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailMatch' -Value 'Exact'
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailScore' -Value '100'
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailSource' -Value $detailSource.SourceName

		if ($detailItem.Name)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailName' -Value $detailItem.Name
		}

		if ($detailItem.Publisher)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailPublisher' -Value $detailItem.Publisher
		}

		if ($detailItem.Developer)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailDeveloper' -Value $detailItem.Developer
		}

		if ($detailItem.Year)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailYear' -Value $detailItem.Year
		}

		if ($detailItem.Genre)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailGenre' -Value $detailItem.Genre
		}

		if ($detailItem.Players)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailPlayers' -Value $detailItem.Players
		}
	}

	$detailSourceIndex.Set_Item($detailSource.SourceName, $detailItemsIndex)
}


for ($priority = 0; $priority -lt $detailSources.Count;$priority++)
{
	$detailSource = $detailSources[$priority]
	$detailItemsIndex = $detailSourceIndex.Get_Item($detailSource.SourceName)

	Write-Host ("Indexing " + $detailItemsIndex.Count + " detail items from '" + $detailSource.SourceName + "' for best matching...")
	IndexItems $detailItems
	Write-Host ("Done")

	Write-Host ("Finding best matching detail items from '" + $detailSource.SourceName + "'...")
	foreach($whdloadSlave in ($whdloadSlaves | Where { $_.DetailMatch -eq $null }))
	{
		# $name = $whdloadSlave.WhdloadName.ToLower()

		# $detailItem = $null
		# $matchingDetailItems = $null

		# # use whdload name to get exact matching detail items
		# if ($detailItemsIndex.ContainsKey($name))
		# {
		# 	$matchingDetailItems = $detailItemsIndex.Get_Item($name)
		# }

		# # use query to get exact matching detail items
		# if (!$matchingDetailItems)
		# {
		# 	$query = $whdloadSlave.Query -replace '[-\s]+', ''
		# 	$matchingDetailItems = $detailItemsIndex.Get_Item($query)
		# }

		# # use filtered name to get exact matching detail items
		# if (!$matchingDetailItems -and $whdloadSlave.FilteredName)
		# {
		# 	$filteredName = $whdloadSlave.FilteredName.ToLower()
		# 	$matchingDetailItems = $detailItemsIndex.Get_Item($filteredName)
		# }

		# # use whdload slave name to get exact matching detail items
		# if (!$matchingDetailItems -and $whdloadSlave.WhdloadSlaveName)
		# {
		# 	$whdloadSlaveNameKeywords = (MakeKeywords (Normalize $whdloadSlave.WhdloadSlaveName)) -replace '\s+', ''
		# 	$matchingDetailItems = $detailItemsIndex.Get_Item($whdloadSlaveNameKeywords)
		# }

		# # use first part of whdload name to get exact matching detail items, if it contains a question mark
		# if (!$matchingDetailItems -and ($name -match '&'))
		# {
		# 	$nameFirstPart = $name -replace '^([^&]+).+', '$1'
		# 	$matchingDetailItems = $detailItemsIndex.Get_Item($nameFirstPart)
		# }



		$matchingDetailItems = FindBestMatchingItems ($whdloadSlave.Query + " english")

		if ($name -match '^bloodnet' -or $name -match 'babylonian')
		{
			">>> '" + $whdloadSlave.WhdloadName + "', '$name' <<<"
			">>> " + $matchingDetailItems.Count + " hits"
			$detailItemsIndex.Keys | Where { $_ -match '^blood' -or $_ -match 'baby' }
		}

		if (!$matchingDetailItems)
		{
			continue
		}

		$firstMatchingDetailItem = $matchingDetailItems | Select-Object -First 1
		$detailItem = $firstMatchingDetailItem.Item

		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailMatch' -Value 'Best'
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailScore' -Value $firstMatchingDetailItem.Score
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailSource' -Value $detailSource.SourceName

		if ($detailItem.Name)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailName' -Value $detailItem.Name
		}

		if ($detailItem.Publisher)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailPublisher' -Value $detailItem.Publisher
		}

		if ($detailItem.Developer)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailDeveloper' -Value $detailItem.Developer
		}

		if ($detailItem.Year)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailYear' -Value $detailItem.Year
		}

		if ($detailItem.Genre)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailGenre' -Value $detailItem.Genre
		}

		if ($detailItem.Players)
		{
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailPlayers' -Value $detailItem.Players
		}
	}
	Write-Host ("Done")
}


# Write details file
$whdloadSlavesDetailsFile = [System.IO.Path]::Combine($outputPath, "whdload_slaves_details.csv")
$whdloadSlaves | export-csv -delimiter ';' -path $whdloadSlavesDetailsFile -NoTypeInformation -Encoding UTF8

exit 0


$detailItemIndex = @{}

# index whdload screenshots
$whdloadScreenshotsIndex = @{}

foreach($whdloadScreenshot in $whdloadScreenshots)
{
	if ($whdloadScreenshotsIndex.ContainsKey($whdloadScreenshot.WhdloadSlaveFilePath))
	{
		Write-Error ("Duplicate whdload screenshot for '" + $whdloadScreenshot.WhdloadSlaveFilePath + "'")
	}

	$whdloadScreenshotsIndex.Set_Item($whdloadScreenshot.WhdloadSlaveFilePath, $whdloadScreenshot.ScreenshotFile)
}

$partitionNumber = 1
$partitionSize = 0

$whdloadScreenshotsPath = [System.IO.Path]::GetDirectoryName($whdloadScreenshotsFile)

$whdloadSizeIndex = @{}
$ags2MenuItemFileNameIndex = @{}


foreach($whdloadSlave in $whdloadSlaves)
{
	# make ags 2 file name, removes invalid file name characters
	$ags2MenuItemFileName = $whdloadSlave.WhdloadName -replace "!", "" -replace ":", "" -replace """", "" -replace "/", "-" -replace "\?", ""

	# if ags 2 file name is longer than 26 characters, then trim it to 26 characters (default filesystem compatibility with limit of ~30 characters)
	if ($ags2MenuItemFileName.length -gt 26)
	{
		$ags2MenuItemFileName = $ags2MenuItemFileName.Substring(0,26).Trim()
	}

	# build new ags2 file name, if it already exists in index
	if ($ags2MenuItemFileNameIndex.ContainsKey($ags2MenuItemFileName))
	{
		$count = 2
		
		do
		{
			if ($ags2MenuItemFileName.length + $count.ToString().length -lt 26)
			{
				$newAgs2MenuItemFileName = $ags2MenuItemFileName + $count
			}
			else
			{
				$newAgs2MenuItemFileName = $ags2MenuItemFileName.Substring(0,$ags2MenuItemFileName.length - $count.ToString().length) + $count
			}
			$count++
		} while ($ags2MenuItemFileNameIndex.ContainsKey($newAgs2MenuItemFileName))
		$ags2MenuItemFileName = $newAgs2MenuItemFileName
	}
	
	# add ags2 file name to index
	$ags2MenuItemFileNameIndex.Set_Item($ags2MenuItemFileName, $true)
	

	$ags2MenuItemIndexName = GetIndexName $ags2MenuItemFileName
	$ags2MenuItemPath = [System.IO.Path]::Combine($outputPath, $ags2MenuItemIndexName + ".ags")

	if(!(Test-Path -Path $ags2MenuItemPath))
	{
		md $ags2MenuItemPath | Out-Null
	}
	
	# set ags2 menu files
	$ags2MenuItemRunFile = [System.IO.Path]::Combine($ags2MenuItemPath, "$($ags2MenuItemFileName).run")
	$ags2MenuItemTxtFile = [System.IO.Path]::Combine($ags2MenuItemPath, "$($ags2MenuItemFileName).txt")
	$ags2MenuItemIffFile = [System.IO.Path]::Combine($ags2MenuItemPath, "$($ags2MenuItemFileName).iff")

	# add partition number to whdload slave run path, if multiple partitions are used	
	if ($usePartitions -and !$whdloadSizeIndex.ContainsKey($whdloadSlave.WhdloadName))
	{
		# add whdload size to index
		$whdloadSizeIndex.Set_Item($whdloadSlave.WhdloadName, $whdloadSlave.WhdloadSize)

		# increase partition number, if whdload size and partition size is greater than partition split size
		if (($partitionSize + $whdloadSlave.WhdloadSize) -gt $partitionSplitSize)
		{
			$partitionNumber++
			$partitionSize = 0
		}

		# add whdload slave size to partition size
		$partitionSize += $whdloadSlave.WhdloadSize

		# set whdload slave run path with partition number
		$whdloadSlaveRunPath = ($assignName + $partitionNumber + ":" + $ags2MenuItemIndexName + "/" + $whdloadSlave.WhdloadName)

		# add assign name property to whdload slave
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value ($assignName + $partitionNumber)
	}
	else 
	{
		# set whdload slave run path
		$whdloadSlaveRunPath = ($assignName + ":" + $ags2MenuItemIndexName + "/" + $whdloadSlave.WhdloadName)

		# add assign name property to whdload slave
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value $assignName
	}

	# set whdload slave file name
	$whdloadSlaveFileName = [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath)

	
	# build ags 2 menu item run lines
	$ags2MenuItemRunLines = @( 
		"cd $($whdloadSlaveRunPath)", 
		"IF `$whdloadargs EQ """"", 
		"  whdload $($whdloadSlaveFileName)", 
		"ELSE", 
		"  whdload $($whdloadSlaveFileName) `$whdloadargs", 
		"ENDIF" )

	# write ags 2 menu item run file in ascii encoding
	[System.IO.File]::WriteAllText($ags2MenuItemRunFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($ags2MenuItemRunLines -join "`n")), [System.Text.Encoding]::ASCII)




	$detailItem = $null

	if ($detailItemIndex.ContainsKey($whdloadSlave.WhdloadName))
	{
		$detailItem = $detailItemIndex.Get_Item($whdloadSlave.WhdloadName)	

		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemMatch' -Value $detailItem.DetailItemMatch
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemSource' -Value $detailItem.DetailItemSource

		# if (!$whdloadDetails.ContainsKey("Name") -and $detailItem.Name)
		# {
		# 	$whdloadDetails.Set_Item("Name", $detailItem.Name)
		# 	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'Name' -Value $detailItem.Name
		# }

		# if (!$whdloadDetails.ContainsKey("Publisher") -and $detailItem.Publisher)
		# {
		# 	$whdloadDetails.Set_Item("Publisher", $detailItem.Publisher)
		# 	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'Publisher' -Value $detailItem.Publisher
		# }

		# if (!$whdloadDetails.ContainsKey("Developer") -and $detailItem.Developer)
		# {
		# 	$whdloadDetails.Set_Item("Developer", $detailItem.Developer)
		# 	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'Developer' -Value $detailItem.Developer
		# }

		# if (!$whdloadDetails.ContainsKey("Year") -and $detailItem.Year)
		# {
		# 	$whdloadDetails.Set_Item("Year", $detailItem.Year)
		# 	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'Year' -Value $detailItem.Year
		# }

		# if (!$whdloadDetails.ContainsKey("Genre") -and $detailItem.Genre)
		# {
		# 	$whdloadDetails.Set_Item("Genre", $detailItem.Genre)
		# 	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'Genre' -Value $detailItem.Genre
		# }

		# if (!$whdloadDetails.ContainsKey("Players") -and $detailItem.Players)
		# {
		# 	$whdloadDetails.Set_Item("Players", $detailItem.Players)
		# 	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'Players' -Value $detailItem.Players
		# }
	}


	
	# build ags 2 menu item txt lines
	$ags2MenuItemTxtLines = @()

	if ($detailItem)
	{
		$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Name", $detailItem.Name)
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemName' -Value $detailItem.Name

		if ($detailItem.Publisher)
		{
			$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Publisher", $detailItem.Publisher)
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemPublisher' -Value $detailItem.Publisher
		}

		if ($whdloadDetails.ContainsKey("Developer"))
		{
			$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Developer", $detailItem.Developer)
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemDeveloper' -Value $detailItem.Developer
		}

		if ($detailItem.Year)
		{
			$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Year", $detailItem.Year)
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemYear' -Value $detailItem.Year
		}

		if ($detailItem.Genre)
		{
			$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Genre", $detailItem.Genre)
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemGenre' -Value $detailItem.Genre
		}

		if ($detailItem.Players)
		{
			$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Players", $detailItem.Players)
			$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'DetailItemPlayers' -Value $detailItem.Players
		}
	}
	else
	{
		Write-Host ("Warning: No details for whdload name '" + $whdloadSlave.WhdloadName + "', query '" + $whdloadSlave.Query + "'")

		$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Name", $whdloadSlave.WhdloadSlaveName.Replace("CD??", "CD32"))
	}

	$ags2MenuItemTxtLines += ("{0,-9} : {1}" -f "Whdload", [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath))


	# write ags 2 menu item txt file in ascii encoding
	[System.IO.File]::WriteAllText($ags2MenuItemTxtFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($ags2MenuItemTxtLines -join "`n")), [System.Text.Encoding]::ASCII)


	# use whdload screenshot, if it exists in index	
	if ($whdloadScreenshotsIndex.ContainsKey($whdloadSlave.WhdloadSlaveFilePath))
	{
		$screenshotFile = $whdloadScreenshotsIndex.Get_Item($whdloadSlave.WhdloadSlaveFilePath)
		$whdloadScreenshotPath = [System.IO.Path]::Combine($whdloadScreenshotsPath, $screenshotFile)
		
		if ($aga)
		{
			$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "ags2aga.iff")
		}
		else
		{
			$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "ags2ocs.iff")
		}
	
		# copy whdload screenshot file, if it exists
		if (test-path -path $whdloadScreenshotFile)
		{
			Copy-Item $whdloadScreenshotFile $ags2MenuItemIffFile -force
		}
	}
}


# Write queries file
$whdloadSlavesFile = [System.IO.Path]::Combine($outputPath, "whdload_slaves.csv")
$whdloadSlaves | export-csv -delimiter ';' -path $whdloadSlavesFile -NoTypeInformation -Encoding UTF8

