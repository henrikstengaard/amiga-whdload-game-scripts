# Filter English Amiga Board WHDLoad Packs
# ----------------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-12-22
#
# A PowerShell script to filter whdload packs from English Amiga Board.
# The script filters whdload packs by excluding hardware, language versions, calculate rank based on hardware, language, demo, memory and other texts. 
# Best ranked versions are picked for each whdload directory.


Param(
	[Parameter(Mandatory=$true)]
	[string]$entriesFile,
	[Parameter(Mandatory=$true)]
	[string]$outputEntriesFile,
	[Parameter(Mandatory=$false)]
	[string]$excludeHardwarePattern,
	[Parameter(Mandatory=$false)]
	[string]$excludeLanguagePattern,
	[Parameter(Mandatory=$false)]
	[string]$excludeFlagPattern,
	[Parameter(Mandatory=$false)]
	[int32]$maxWhdloadSlaveBaseMemSize,
	[Parameter(Mandatory=$false)]
	[int32]$maxWhdloadSlaveExpMem,
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


# read entries
$entries = @()
$entries += import-csv -delimiter ';' $entriesFile


# Patterns for filtering versions of whdload slaves
$hardwarePattern = '(CD32|AGA|CDTV|CD)$'
$languagePattern = '(En|De|DE|Fr|It|Se|Pl|Es|Cz|Dk|Fi|Gr|CV)$'
$memoryPattern = '(Slow|Fast|LowMem|Chip|1MB|1Mb|2MB|15MB|512k|512K|512kb|512Kb|512KB)$'
$demoPattern = '(Demo\d?|Demos|Preview|DemoLatest|DemoPlay|DemoRoll|Prerelease)$'
$otherPattern = '(Alt|AmigaPower|AmigaFormat|AmigaAction|CUAmiga|TheOne|NoMusic|NoSounds|NoVoice|Fix|Fixed|Aminet|ComicRelief|Util|Files|Image\d?|060|Intro|NoIntro|NTSC|Censored|Kick31|Kick13|\dDisk|\(EasyPlay\)|_Kernal1.1|Cracked|HiRes|LoRes|Crunched|Decrunched)$'
$compilationPattern = '(&Missions|&MissionDisk|&MissionDisks|&SceneryDisk\d*|&Hawaiian|&SceneryDisks|&CityDefense|&ExtraTime|&SpaceHarrier|&Missions|&ExtendedLevels|&CadaverThePayoff|&Planeteers|&ConstrSet|&ConstructionSet|&MstrTrcks|&DDisks|&DataDisk\d?|&DataDisks|&Profidisk|&Data|&TourDisk|&ChallengeGames|&VoyageBeyond|&RetrnFntZone|&RFantasyZone|&SummerGames2|&NewWorlds)'

foreach ($entry in $entries)
{
	$name = $entry.EntryName

	$flags = @()
	if ($entry.WhdloadSlaveFlags)
	{
		$flags += $entry.WhdloadSlaveFlags -split ','
	}

	# Special replace for 'Invest' and 'Spirit of Adventure' german games for language pattern
	if ($name -cmatch 'De\d+Disk')
	{
		$name = $name -creplace '(De)(\d+Disk)', '$2$1'
	}

	$hardware = @()
	$language = @()
	$memory = @()
	$demo = @()
	$other = @()
	$compilation = @()
	
	while ($name -cmatch $hardwarePattern -or $name -cmatch $languagePattern -or $name -cmatch $memoryPattern -or $name -cmatch $demoPattern -or $name -cmatch $otherPattern -or $name -cmatch $compilationPattern)
	{
		if ($name -cmatch $hardwarePattern)
		{
			$hardware +=, ($name | Select-String -Pattern $hardwarePattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)
			$name = $name -creplace $hardwarePattern, ''
		}

		if ($name -cmatch $languagePattern)
		{
			$match = ($name | Select-String -Pattern $languagePattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)

			if ($match -notmatch 'En')
			{
				$language +=, $match 
			}

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

		if ($name -cmatch $compilationPattern)
		{
			$match = ($name | Select-String -Pattern $compilationPattern -CaseSensitive -AllMatches | % { $_.Matches } | % { $_.Groups[0].Value } | Select-Object -First 1)
			$compilation +=, $match -replace '^&', ''
			$name = $name -creplace $compilationPattern, ''
		}
	}

	$name = $name -replace '&$', ''

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

	# if hardware doesn't contain CD32 or AGA and flags has ReqAGA, then add AGA to hardware
	if ((($hardware | Where { $_ -match '(CD32|AGA)' }).Count -eq 0) -and (($flags | Where { $_ -match 'ReqAGA' }).Count -gt 0))
	{
		$hardware +=, 'AGA'
	}

	if ($hardware.Count -eq 0)
	{
		$hardware +=, 'OCS/ECS'
	}
	
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredName' -Value $name -Force
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredHardware' -Value ([string]::Join(',', $hardware)) -Force
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredLanguage' -Value ([string]::Join(',', $language)) -Force
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredMemory' -Value ([string]::Join(',', $memory)) -Force
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredDemo' -Value ([string]::Join(',', $demo)) -Force
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredOther' -Value ([string]::Join(',', $other)) -Force
	$entry | Add-Member -MemberType NoteProperty -Name 'FilteredCompilation' -Value ([string]::Join(',', $compilation)) -Force
}

# create output dir, if it doesn't exist
$outputDir = Split-Path $outputEntriesFile -Parent
if(!(test-path -path $outputDir))
{
	mkdir $outputDir | Out-Null
}

# write filtered entries list
$entries | export-csv -delimiter ';' -path $outputEntriesFile -NoTypeInformation -Encoding UTF8