# Filter Amiga English Board WHDLoad Packs
# ----------------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-08-04
#
# A PowerShell script to filter whdload packs from Amiga English Board.
# The script filters whdload packs by excluding hardware, language versions, calculate rank based on hardware, language, demo, memory and other texts. 
# Best ranked versions are picked for each whdload directory.


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
	[switch]$bestVersion,
	[Parameter(Mandatory=$false)]
	[switch]$eachHardware,
	[Parameter(Mandatory=$false)]
	[switch]$skipCopying
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
$hardwarePattern = '(CD32|AGA|CDTV|CD)$'
$languagePattern = '(De|DE|Fr|It|Se|Pl|Es|Cz|Dk|Fi)$'
$memoryPattern = '(Slow|Fast|LowMem|Chip|1MB|1Mb|2MB|15MB|512k|512kb|512Kb|512KB)$'
$demoPattern = '(Demo|Preview)$'
$otherPattern = '(AmigaAction|CUAmiga|TheOne|NoMusic|NoVoice|Fix|Fixed|Aminet|ComicRelief|Util|Files|Image|060|Intro|NoIntro|NTSC|Censored|Kick31|Kick13|&Profidisk)$'


# Process whdload slaves
$identicalWhdloadSlaveIndex = @{}

foreach ($whdloadSlave in $whdloadSlaves)
{
	$name = $whdloadSlave.WhdloadName

	$hardware = @()
	$language = @()
	$memory = @()
	$demo = @()
	$other = @()
	
	while ($name -cmatch $hardwarePattern -or $name -cmatch $languagePattern -or $name -cmatch $memoryPattern -or $name -cmatch $demoPattern -or $name -cmatch $otherPattern)
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

		if ($name -cmatch $memoryPattern)
		{
			$memory +=, ($name | Select-String -Pattern $memoryPattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)
			$name = $name -creplace $memoryPattern, ''
		}
		
		if ($name -cmatch $demoPattern)
		{
			$demo +=, ($name | Select-String -Pattern $demoPattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)
			$name = $name -creplace $demoPattern, ''
		}

		if ($name -cmatch $otherPattern)
		{
			$other +=, ($name | Select-String -Pattern $otherPattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1) 
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

	if ($hardware.Count -eq 0)
	{
		$hardware +=, 'OCS/ECS'
	}
	
	# Rank whdload slave
	$rank = 1

	if (($hardware | Where { $_ -match 'CD32' }).Count -gt 0)
	{
		$rank = 4
	}
	elseif (($hardware | Where { $_ -match 'AGA' }).Count -gt 0)
	{
		$rank = 3
	}
	elseif (($hardware | Where { $_ -match 'CDTV' }).Count -gt 0)
	{
		$rank = 2
	}

	$rank -= $language.Count
	$rank -= $demo.Count
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
		$rank -= $lowestMemory / 512000
	}
	
	$kick = $other | Where { $_ -match '^kick\d+'} | % { $_ -replace '^kick', '' } | Select-Object -First 1
	
	if ($kick)
	{
		$rank += $kick
	}
	
	$rank -= ($other | Where { $_ -match '^Files$'} ).Count

	$whdloadIndexName = $name
	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'FilteredName' -Value $name
	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'FilteredHardware' -Value ([string]::Join(',', $hardware))
	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'FilteredLanguage' -Value ([string]::Join(',', $language))
	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'FilteredMemory' -Value ([string]::Join(',', $memory))
	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'FilteredDemo' -Value ([string]::Join(',', $demo))
	$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'FilteredOther' -Value ([string]::Join(',', $other))

	$game = @{ "WhdloadSlave" = $whdloadSlave; "Name" = $name; "Hardware" = $hardware; "Language" = $language; "Memory" = $memory; "Demo" = $demo; "Other" = $other; "Rank" = $rank }
	
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
	
	
	if ($eachHardware)
	{
		$hardwareList = @()
	
		foreach($whdloadSlave in $identicalWhdloadSlaves)
		{
			if ($hardwareList -contains $whdloadSlave.Hardware)
			{
				continue
			}
			
			$hardwareList += $whdloadSlave.Hardware
		}
		
		foreach ($hardware in $hardwareList)
		{
			$whdloadSlavesHardware = @()
			$whdloadSlavesHardware +=, ($identicalWhdloadSlaves | Where { $_.Hardware -contains $hardware })
			
			if ($bestVersion)
			{
				$whdloadSlavesHardware = $whdloadSlavesHardware | Where { $_.Rank -eq $whdloadSlavesHardware[0].Rank }
			}

			foreach($whdloadSlave in $whdloadSlavesHardware)
			{
				$filteredWhdloadSlaves +=, $whdloadSlave.WhdloadSlave
			}
		}
	}
	else
	{
		if ($bestVersion)
		{
			$identicalWhdloadSlaves = $identicalWhdloadSlaves | Where { $_.Rank -eq $identicalWhdloadSlaves[0].Rank }
		}

		foreach($whdloadSlave in $identicalWhdloadSlaves)
		{
			$filteredWhdloadSlaves +=, $whdloadSlave.WhdloadSlave
		}
	}
}


# Copy filtered whdload slave directories
if (!$skipCopying)
{
	foreach($whdloadSlave in $filteredWhdloadSlaves)
	{
		$whdloadDirectoryPath = [System.IO.Path]::GetDirectoryName($whdloadSlave.WhdloadSlaveFilePath)

		$whdloadSourcePath = [System.IO.Path]::Combine($whdloadSlave.WhdloadPath, $whdloadDirectoryPath)
		$whdloadDestinationPath = [System.IO.Path]::Combine($outputPath, $whdloadDirectoryPath)

		
		#$whdloadDestinationPath = [System.IO.Path]::GetDirectoryName($destinationPath)
		$whdloadDestinationIndexPath = [System.IO.Path]::GetDirectoryName($whdloadDestinationPath)
		
		# create whdload destination index path, if it doesn't exist
		if(!(test-path -path $whdloadDestinationIndexPath))
		{
			md $whdloadDestinationIndexPath | Out-Null
		}

		# copy info file
		$whdloadSourceIndexPath = [System.IO.Path]::GetDirectoryName($whdloadSourcePath)
		$whdloadSourceDirectoryInfoFile = [System.IO.Path]::Combine($whdloadSourceIndexPath, $whdloadSlave.WhdloadName + ".info")
		$whdloadDestinationDirectoryInfoFile = [System.IO.Path]::Combine($whdloadDestinationIndexPath, $whdloadSlave.WhdloadName + ".info")

		# copy whdload directory info file, if it exists
		if ((test-path -path $whdloadSourceDirectoryInfoFile) -and !(test-path -path $whdloadDestinationDirectoryInfoFile))
		{
			Copy-Item $whdloadSourceDirectoryInfoFile $whdloadDestinationIndexPath -force
		}

		$whdloadIndexName = [System.IO.Path]::GetFilename($whdloadSourceIndexPath)
		$whdloadSourceRootPath = [System.IO.Path]::GetDirectoryName($whdloadSourceIndexPath)
		$whdloadSourceRootInfoFile = [System.IO.Path]::Combine($whdloadSourceRootPath, $whdloadIndexName + ".info")
		$whdloadDestinationRootPath = [System.IO.Path]::GetDirectoryName($whdloadDestinationIndexPath)
		$whdloadDestinationRootInfoFile = [System.IO.Path]::Combine($whdloadDestinationRootPath, $whdloadIndexName + ".info")

		# copy whdload index info file, if it doesn't exists
		if ((test-path -path $whdloadSourceRootInfoFile) -and !(test-path -path $whdloadDestinationRootInfoFile))
		{
			Copy-Item $whdloadSourceRootInfoFile $whdloadDestinationRootPath -force
		}

		# copy whdload directory, if it doesn't exist
		if(!(test-path -path $whdloadDestinationPath))
		{
			Copy-Item $whdloadSourcePath -Destination $whdloadDestinationIndexPath -Recurse
		}
	}
}


# Write filtered whdload slaves list
$filteredWhdloadSlaveListFile = [System.IO.Path]::Combine($outputPath, "whdload_slaves.csv")
$filteredWhdloadSlaves | export-csv -delimiter ';' -path $filteredWhdloadSlaveListFile -NoTypeInformation
