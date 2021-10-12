# Build Entries Set
# -----------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2021-10-12
#
# A PowerShell script to build entries set.
# The script filters whdload packs by excluding hardware, language versions, calculate rank based on hardware, language, demo, memory and other texts. 
# Best ranked versions are picked for each whdload directory.


Param(
	[Parameter(Mandatory=$true)]
	[string]$entriesFiles,
	[Parameter(Mandatory=$true)]
	[string]$outputEntriesSetFile,
	[Parameter(Mandatory=$false)]
	[string]$assignName,
	[Parameter(Mandatory=$false)]
	[string]$setName,
	[Parameter(Mandatory=$false)]
	[string]$appendName,
	[Parameter(Mandatory=$false)]
	[string]$excludeHardwarePattern,
	[Parameter(Mandatory=$false)]
	[string]$excludeLanguagePattern,
	[Parameter(Mandatory=$false)]
	[string]$excludeFlagPattern,
	[Parameter(Mandatory=$false)]
	[string]$maxWhdloadSlaveBaseMemSize,
	[Parameter(Mandatory=$false)]
	[string]$maxWhdloadSlaveExpMem,
	[Parameter(Mandatory=$false)]
	[string]$maxEntrySize,
	[Parameter(Mandatory=$false)]
	[switch]$bestVersion,
	[Parameter(Mandatory=$false)]
	[switch]$eachHardware,
	[Parameter(Mandatory=$false)]
	[switch]$skipCopying
)


# resolve paths
$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
$outputEntriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputEntriesFile)


# read entries files
$entries = @()
foreach($entriesFile in ($entriesFiles -Split ','))
{
	$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
	Write-Host ("Reading entries file '{0}'" -f $entriesFile)
	$entries += import-csv -delimiter ';' -path $entriesFile -encoding utf8 
}

# build rank and identical entries index
$identicalEntriesIndex = @{}
foreach ($entry in $entries)
{
	if ($entry.FilteredName)
	{
		$name = $entry.FilteredName
		$identicalEntryName = $name

		if ($entry.FilteredCompilation)
		{
			$identicalEntryName += $entry.FilteredCompilation
		}
	}
	else
	{
		$name = $entry.EntryName
		$identicalEntryName = $name
	}

	$flags = @()
	if ($entry.WhdloadSlaveFlags)
	{
		$flags += $entry.WhdloadSlaveFlags -split ','
	}

	if ($maxWhdloadSlaveBaseMemSize -and $entry.WhdloadSlaveBaseMemSize -and [uint32]$entry.WhdloadSlaveBaseMemSize -gt [uint32]$maxWhdloadSlaveBaseMemSize)
	{
		continue
	}

	if ($maxWhdloadSlaveExpMem -and $entry.WhdloadSlaveExpMem -and [uint32]$entry.WhdloadSlaveExpMem -gt [uint32]$maxWhdloadSlaveExpMem)
	{
		continue
	}

	if ($maxEntrySize -and $entry.EntrySize -and [uint32]$entry.EntrySize -gt [uint32]$maxEntrySize)
	{
		continue
	}
	
	# skip, if any exclude pattern matches flag
	if ($excludeFlagPattern -and ($flags | Where-Object { $_ -match $excludeFlagPattern }).Count -gt 0)
	{
		continue
	}

	$hardware = @()
	if ($entry.FilteredHardware)
	{
		$hardware += $entry.FilteredHardware -split ','
	}

	$language = @()
	if ($entry.FilteredLanguage)
	{
		$language += $entry.FilteredLanguage -split ','
	}

	$memory = @()
	if ($entry.FilteredMemory)
	{
		$memory += $entry.FilteredMemory -split ','
	}

	$demo = @()
	if ($entry.FilteredDemo)
	{
		$demo += $entry.FilteredDemo -split ','
	}

	$other = @()
	if ($entry.FilteredOther)
	{
		$other += $entry.FilteredOther -split ','
	}

	$compilation = @()
	if ($entry.FilteredCompilation)
	{
		$compilation += $entry.FilteredCompilation -split ','
	}
	
	# skip, if any exclude pattern matches hardware
	if ($excludeHardwarePattern -and ($hardware | Where { $_ -match $excludeHardwarePattern }).Count -gt 0)
	{
		continue
	}

	# skip, if any exclude pattern matches language
	if ($excludeLanguagePattern -and ($language | Where { $_ -match $excludeLanguagePattern }).Count -gt 0)
	{
		continue
	}

	# Rank whdload slave
	$rank = 1

	if (($hardware | Where { $_ -match 'CD32' }).Count -gt 0)
	{
		$rank = 40
	}
	elseif (($hardware | Where { $_ -match 'AGA' }).Count -gt 0)
	{
		$rank = 30
	}
	elseif (($hardware | Where { $_ -match 'CDTV' }).Count -gt 0)
	{
		$rank = 20
	}

	$rank -= $language.Count
	$rank -= $demo.Count * 20
	$rank -= $other.Count
	$rank -= $memory.Count

	# make memory sortable
	$sortableMemory = @()
	foreach($m in $memory)
	{
		$sortableMemory +=, ($m -replace 'mb$', '000000' -replace '(k|kb)$', '000')
	}
	
	$lowestMemory = $sortableMemory | Where { $_ -match '^\d+$' } | sort @{expression={$_};Ascending=$true} | Select-Object -First 1
	
	if ($lowestMemory)
	{
		$rank -= ($lowestMemory / 51200)
	}
	
	$kick = $other | Where { $_ -match '^kick\d+'} | % { $_ -replace '^kick', '' } | Select-Object -First 1
	
	if ($kick)
	{
		$rank += $kick
	}
	
	$rank -= ($other | Where { $_ -match '^Files$'} ).Count

	$rank -= ($entry.RunDir.Length * 2)

	$game = @{ "Entry" = $entry; "Name" = $name; "Hardware" = $hardware; "Language" = $language; "Memory" = $memory; "Demo" = $demo; "Other" = $other; "Rank" = $rank }

	if ($identicalEntriesIndex.ContainsKey($identicalEntryName))
	{
		$identicalEntries = $identicalEntriesIndex.Get_Item($identicalEntryName)
	}
	else
	{
		$identicalEntries = @()
	}
	
	$identicalEntries +=, $game
	
	$identicalEntriesIndex.Set_Item($identicalEntryName, $identicalEntries)
}


# Filter identical whdload slaves
$filteredEntries = @()

foreach ($name in ($identicalEntriesIndex.Keys | Sort-Object))
{
	$identicalEntries = @()
	$identicalEntries += ($identicalEntriesIndex.Get_Item($name) | Sort-Object @{expression={$_.Rank};Ascending=$false})
	
	if ($eachHardware)
	{
		$hardwareList = @()
	
		foreach($entry in $identicalEntries)
		{
			if ($hardwareList -contains $entry.Hardware)
			{
				continue
			}
			
			$hardwareList += $entry.Hardware
		}
		
		foreach ($hardware in $hardwareList)
		{
			$entriesHardware = @()
			$entriesHardware +=, ($identicalEntries | Where-Object { $_.Hardware -contains $hardware })
			
			if ($bestVersion -and $entriesHardware.Count -gt 1)
			{
				$bestHardwareEntry = $entriesHardware | Select-Object -First 1
				$bestHardwareEntries = @()
				$bestHardwareEntries += $entriesHardware | Where-Object { $_.Entry.RunDir -eq $bestHardwareEntry.Entry.RunDir } | Sort-Object @{expression={$_.Entry.RunFile};Ascending=$true}
				$entriesHardware = $bestHardwareEntries
			}

			foreach($entry in $entriesHardware)
			{
				$filteredEntries +=, $entry.Entry
			}
		}
	}
	else
	{
		if ($bestVersion -and $identicalEntries.Count -gt 1)
		{
			$bestIdenticalEntry = $identicalEntries | Select-Object -First 1
			$bestIdenticalEntries = @()
			$bestIdenticalEntries += $identicalEntries | Where-Object { $_.Entry.RunDir -eq $bestIdenticalEntry.Entry.RunDir } | Sort-Object @{expression={$_.Entry.RunFile};Ascending=$true}
			$identicalEntries = $bestIdenticalEntries
		}

		foreach($entry in $identicalEntries)
		{
			$filteredEntries +=, $entry.Entry
		}
	}
}


# Copy filtered whdload slave directories
# if (!$skipCopying)
# {
# 	foreach($entry in $filteredEntries)
# 	{
# 		$entryRunDir = Join-Path $entry.EntriesDir -ChildPath $entry.RunDir


# 		if(!(test-path -path $entryRunDir))
# 		{
# 			continue
# 		}

# 		$outputEntryRunDir = Join-Path $outputPath -ChildPath $entry.RunDir
		
# 		# create whdload destination index path, if it doesn't exist
# 		if(!(test-path -path $outputEntryRunDir))
# 		{
# 			md $outputEntryRunDir | Out-Null
# 		}

		
# 		# copy entry rundir to output dir
# 		Copy-Item "$entryRunDir\*" -Destination $outputEntryRunDir -Recurse -Force

# 		# copy info files
# 		$entryRunDirSegments = @()
# 		$entryRunDirSegments += $entry.RunDir -split '\\'

# 		$currentEntryRunDir = $entry.EntriesDir
# 		$currentOutputEntryRunDir = $outputPath
		
# 		foreach ($entryRunDirSegment in $entryRunDirSegments)
# 		{
# 			$currentEntryRunDirInfoFile = Join-Path $currentEntryRunDir -ChildPath ("{0}.info" -f $entryRunDirSegment)

# 			if (Test-Path -Path $currentEntryRunDirInfoFile)
# 			{
# 				Copy-Item $currentEntryRunDirInfoFile $currentOutputEntryRunDir -Force
# 			}

# 			$currentEntryRunDir = Join-Path $currentEntryRunDir -ChildPath $entryRunDirSegment
# 			$currentOutputEntryRunDir = Join-Path $currentOutputEntryRunDir -ChildPath $entryRunDirSegment
# 		}
# 	}
# }

# create output dir, if it doesn't exist
$outputDir = Split-Path $outputEntriesSetFile -Parent
if(!(test-path -path $outputDir))
{
	mkdir $outputDir | Out-Null
}

foreach($filteredEntry in $filteredEntries)
{
    if ($assignName)
    {
        # add assign name
        if ($filteredEntry.AssignName)
        {
            $filteredEntry.AssignName = $assignName
        }
        else
        {
            $filteredEntry | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value $assignName
        }
    }

    if ($setName)
    {
        # add set name
        if ($filteredEntry.SetName)
        {
            $filteredEntry.SetName = $setName
        }
        else
        {
            $filteredEntry | Add-Member -MemberType NoteProperty -Name 'SetName' -Value $setName
        }
    }

    if ($appendName)
    {
        # add append name
        if ($filteredEntry.AppendName)
        {
            $filteredEntry.AppendName = $appendName
        }
        else
        {
            $filteredEntry | Add-Member -MemberType NoteProperty -Name 'AppendName' -Value $appendName
        }
    }
}

# write filtered entries list
$filteredEntries | export-csv -delimiter ';' -path $outputEntriesSetFile -NoTypeInformation -Encoding UTF8