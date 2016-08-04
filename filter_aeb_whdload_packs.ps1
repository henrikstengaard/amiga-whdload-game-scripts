# Filter Amiga English Board WHDLoad Packs
# ----------------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-08-04
#
# A PowerShell script to filter whdload packs from Amiga English Board.
# The script filters whdload packs by excluding hardware and language versions and picking best version.


Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadSourceFile,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$false)]
	[string]$excludeHardwarePattern,
	[Parameter(Mandatory=$false)]
	[string]$excludeLanguagePattern,
	[Parameter(Mandatory=$false)]
	[switch]$bestVersion
)


# Resolve paths
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)


# Read whdload slave
function ReadWhdloadSlaves($whdloadPath)
{
	$whdloadSlaveFile = [System.IO.Path]::Combine($whdloadPath, "whdload_slaves.csv")
	
	$whdloadSlaves = @()
	
	if (!(test-path -path $whdloadSlaveFile))
	{
		return $whdloadSlaves
	}
	
	$whdloadSlaves += import-csv -delimiter ';' $whdloadSlaveFile
	
	foreach($whdloadSlave in $whdloadSlaves)
	{
		 $whdloadSlave | Add-Member -MemberType NoteProperty -Name "WhdloadPath" -Value $whdloadPath
	}
	
	return $whdloadSlaves
}


# Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


# Read screenshot sources
# -----------------------
$whdloadSources = Import-Csv -Delimiter ';' $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSourceFile)

$whdloadSlaves = @()

foreach($whdloadSource in $whdloadSources)
{
	$whdloadSlaves += ReadWhdloadSlaves $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSource.WhdloadPath)
}


# Patterns for filtering versions of whdload slaves
$hardwarePattern = '(CD32|AGA)$'
$languagePattern = '(De|DE|Fr|It|Se|Pl|Es|Cz)$'
$demoPattern = '(Demo|Preview)$'
$otherPattern = '(NoVoice|Fix|Fixed|Slow|Fast|Aminet|ComicRelief|Util|1MB|2MB|060|CD|Chip|NoIntro|NTSC|Censored)$'


# Process whdload slaves
$identicalWhdloadSlaveIndex = @{}

foreach ($whdloadSlave in $whdloadSlaves)
{
	$name = $whdloadSlave.WhdloadName

	$hardware = @()
	$language = @()
	$demo = ""
	$other = ""
	
	while ($name -cmatch $hardwarePattern -or $name -cmatch $languagePattern -or $name -cmatch $demoPattern -or $name -cmatch $otherPattern)
	{
		if ($name -cmatch $hardwarePattern)
		{
			$hardware +=, ($name | Select-String -Pattern $hardwarePattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)
			$name = $name -creplace $hardwarePattern, ''
		}

		if ($name -cmatch $languagePattern)
		{
			$language +=, ($name | Select-String -Pattern $languagePattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)
			$name = $name -creplace $languagePattern, ''
		}
	
		if ($name -cmatch $demoPattern)
		{
			$demo = $name | Select-String -Pattern $demoPattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1 
			$name = $name -creplace $demoPattern, ''
		}

		if ($name -cmatch $otherPattern)
		{
			$other = $name | Select-String -Pattern $otherPattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1 
			$name = $name -creplace $otherPattern, ''
		}
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
		$rank = 3
	}
	elseif (($hardware | Where { $_ -match 'AGA' }).Count -gt 0)
	{
		$rank = 2
	}

	# boost rank if rank is empty (english)
	if ($language -eq '')
	{
		$rank++
	}
	
	# whdload index name. combined to include multiple slaves (intro, no intro etc.) and different memory versions
	$whdloadIndexName = $name + $other
	
	$game = @{ "WhdloadSlave" = $whdloadSlave; "Name" = $name; "Hardware" = [string]::Join(",", $hardware); "Language" = [string]::Join(",", $language); "Demo" = $demo; "Other" = $other; "Rank" = $rank }
	
	if ($identicalWhdloadSlaveIndex.ContainsKey($whdloadIndexName))
	{
		$identicalWhdloadSlaves = $identicalWhdloadSlaveIndex.Get_Item($whdloadIndexName)
	}
	else
	{
		$identicalWhdloadSlaves = @()
	}
	
	$identicalWhdloadSlaves +=, $game
	
	$identicalWhdloadSlaveIndex.Set_Item($whdloadIndexName, $identicalWhdloadSlaves)
}


# Filter identical whdload slaves
$filteredWhdloadSlaves = @()

foreach ($name in ($identicalWhdloadSlaveIndex.Keys | sort))
{
	$identicalWhdloadSlaves = @()
	$identicalWhdloadSlaves += ($identicalWhdloadSlaveIndex.Get_Item($name) | sort @{expression={$_.Rank};Ascending=$false})
	
	if ($bestVersion)
	{
		$identicalWhdloadSlaves = $identicalWhdloadSlaves | Where { $_.Rank -eq $identicalWhdloadSlaves[0].Rank }
	}
	
	foreach($whdloadSlave in $identicalWhdloadSlaves)
	{
		$filteredWhdloadSlaves +=, $whdloadSlave.WhdloadSlave
	}
}


# Copy filtered whdload slave directories
foreach($whdloadSlave in $filteredWhdloadSlaves)
{
	$whdloadDirectoryPath = [System.IO.Path]::GetDirectoryName($whdloadSlave.WhdloadSlaveFilePath)

	$sourcePath = [System.IO.Path]::Combine($whdloadSlave.WhdloadPath, $whdloadDirectoryPath)
	$destinationPath = [System.IO.Path]::Combine($outputPath, $whdloadDirectoryPath)

	# skip, since it's already copied
	if(test-path -path $destinationPath)
	{
		continue
	}
	
	$parentPath = [System.IO.Path]::GetDirectoryName($destinationPath)
	
	if(!(test-path -path $parentPath))
	{
		md $parentPath | Out-Null
	}
	
	Copy-Item $sourcePath -Destination $parentPath -Recurse
}


# Write filtered whdload slaves list
$filteredWhdloadSlaveListFile = [System.IO.Path]::Combine($outputPath, "whdload_slaves.csv")
$filteredWhdloadSlaves | export-csv -delimiter ';' -path $filteredWhdloadSlaveListFile -NoTypeInformation