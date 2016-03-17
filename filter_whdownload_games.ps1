# Filter WHDownload Games
# -----------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-01
#
# A PowerShell script to filter games downloaded from www.whdownload.com by excluding unwanted versions and picking preferred versions.

Param(
	[Parameter(Mandatory=$true)]
	[string]$whdownloadGamesPath,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter()]
	[string]$exclude
)


# Excludes unwanted language and demo versions by examening filename
function ExcludeUnwantedLanguageAndDemoVersions($whdownloadFiles)
{
	$filteredWhdownloadGameUrls = $whdownloadFiles | Where { 
		$_ -notmatch '_de' -and 
		$_ -notmatch '_fr' -and 
		$_ -notmatch '_it' -and 
		$_ -notmatch '_se' -and 
		$_ -notmatch '_pl' -and 
		$_ -notmatch '_es' -and 
		$_ -notmatch '_cz' -and 
		$_ -notmatch '_ntsc' -and 
		$_ -cnotmatch 'Demo' -and 
		$_ -cnotmatch 'Preview' -and 
		$_ -notmatch '_060'
	}

	Write-Host "$($filteredWhdownloadGameUrls.Count) files left after excluding unwanted language and demo versions"
	
	return $filteredWhdownloadGameUrls;
}

# Parse whdload games
function ParseWhdloadGame($whdownloadFile)
{
	$whdloadBaseName = [System.IO.Path]::GetFileNameWithoutExtension($whdownloadFile)
		
	$whdloadSegments = $whdloadBaseName -split "_"
	
	$whdloadGame = @{}
	$whdloadGame.Name = $whdloadSegments[0]
	$whdloadGame.IsAga = $whdownloadFile -match '_aga'
	$whdloadGame.IsCd32 = $whdownloadFile -match '_cd32'
	$whdloadGame.IsCdtv = $whdownloadFile -match '_cdtv'
	$whdloadGame.File = $whdownloadFile

	$versionMatches = $whdloadSegments[1] | Select-String -Pattern "v(\d+\.\d+)"
	
	if ($versionMatches)
	{
		$whdloadGame.Version = [decimal]$versionMatches.Matches[0].Groups[1].Value
	}
	else
	{
		$whdloadGame.Version = 0,0
	}

	$numberMatches = $whdloadSegments[$whdloadSegments.Count - 1] | Select-String -Pattern "^(\d+)$"
	
	if ($numberMatches)
	{
		$whdloadGame.Number = [decimal]$numberMatches.Matches[0].Groups[1].Value
	}
	else
	{
		$whdloadGame.Number = 0
	}

	$whdloadGame.HardwareRank = 0
	$whdloadGame.Hardware = ""

	if ($whdloadGame.IsCd32)
	{
		$whdloadGame.HardwareRank = 3
		$whdloadGame.Hardware = "CD32"
	}
	if ($whdloadGame.IsAga)
	{
		$whdloadGame.HardwareRank = 2
		$whdloadGame.Hardware = "AGA"
	}
	if ($whdloadGame.IsCdtv)
	{
		$whdloadGame.HardwareRank = 1
		$whdloadGame.Hardware = "CDTV"
	}

	return New-Object psobject –Prop $whdloadGame
}

# Find preferred whdload game version by checking which is better
function PickPreferredWhdloadGameVersions($whdloadGames)
{
	$indexedWhdloadGames = @{}

	ForEach ($whdloadGame in $whdloadGames)
	{
		# unique by name and hardware
		#$name = "$($whdloadGame.Name).$($whdloadGame.Hardware)"
		# unique by name
		$name = $whdloadGame.Name

		$oldWhdloadGame = $indexedWhdloadGames.Get_Item($name)
		if ($indexedWhdloadGames.ContainsKey($name) -and !(IsWhdloadGameBetter $oldWhdloadGame $whdloadGame))
		{
			continue;
		}
		$indexedWhdloadGames.Set_Item($name, $whdloadGame)
	}
	
	$preferedWhdloadGames = $indexedWhdloadGames.GetEnumerator() | % { $_.Value } | Sort-Object Name

	Write-Host "$($preferedWhdloadGames.Count) whdload games left after picking preferred versions"
	
	return $preferedWhdloadGames;
}

# Examines old and new whdload game and returnes true if new whdload game is better. The new whdload game is better if it has better hardware(cd32, aga, cdtv), version is higher or number is higher
function IsWhdloadGameBetter($oldWhdloadGame, $newWhdloadGame)
{
	if ($newWhdloadGame.HardwareRank -gt $oldWhdloadGame.HardwareRank)
	{
		return $true
	}

	if ($newWhdloadGame.Version -gt $oldWhdloadGame.Version)
	{
		return $true
	}

	if ($newWhdloadGame.Number -gt $oldWhdloadGame.Number)
	{
		return $true
	}

	return $false
}

# Get game index name from first character in game name
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

# Copy whdload games to output path
function CopyWhdloadGames($outputPath, $whdloadGames)
{
	Write-Host "Copying $($whdloadGames.Count) whdload games to '$outputPath'"

	ForEach ($whdloadGame in $whdloadGames)
	{
		$whdloadFileName = [System.IO.Path]::GetFileName($whdloadGame.File)
		$whdloadGameIndexName = GetGameIndexName $whdloadFileName
		$whdloadGameIndexPath = [System.IO.Path]::Combine($outputPath, $whdloadGameIndexName)
		$whdloadGameFile = [System.IO.Path]::Combine($whdloadGameIndexPath, $whdloadFileName)
		
		if(!(Test-Path -Path $whdloadGameIndexPath))
		{
			md $whdloadGameIndexPath | Out-Null
		}

		Copy-Item $whdloadGame.File $whdloadGameFile -force
	}
}

# Build whdownload games index
function BuildWhdownloadGamesIndex($whdownloadGamesPath, $whdloadGamesPath, $preferredWhdloadGames)
{
	$whdownloadGameIndexPath = [System.IO.Path]::Combine($whdownloadGamesPath, "whdownload_games_index.csv")

	$whdownloadIndex = @{}
	ForEach($line in (Get-Content $whdownloadGameIndexPath | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$whdownloadIndex.Set_Item($columns[0], $line)
	}

	$whdloadGameIndexPath = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_games_index.csv")

	Add-Content $whdloadGameIndexPath (Get-Content $whdownloadGameIndexPath | Select-Object -First 1)
	
	ForEach ($preferredWhdloadGame in $preferredWhdloadGames)
	{
		$fileName = [System.IO.Path]::GetFileName($preferredWhdloadGame.File)
		$line = $whdownloadIndex.Get_Item($fileName)
		
		Add-Content $whdloadGameIndexPath "$line"
	}
}

# 1. Get whdownload files
$whdownloadFiles = Get-ChildItem -recurse -Path $whdownloadGamesPath -exclude *.html,*.csv -File

# 2. Exclude whdownload files, if defined
if ($exclude)
{
	$excludeItems = $exclude -split ','

	ForEach ($excludeItem in $excludeItems)
	{
		$whdownloadFiles = $whdownloadFiles | Where { $_ -notmatch $excludeItem }
	}
}

# 3. Excluding unwanted language and demo versions
$filteredWhdownloadFiles = ExcludeUnwantedLanguageAndDemoVersions $whdownloadFiles

# 4. Parse whdload games from whdownload files
$whdloadGames = $filteredWhdownloadFiles | ForEach { ParseWhdloadGame $_ }

# 5. Pick preferred whdload game versions
$preferredWhdloadGames = PickPreferredWhdloadGameVersions $whdloadGames

# 6. Copy preferred whdload games 
CopyWhdloadGames $outputPath $preferredWhdloadGames

# 7. Build whdownload games index
BuildWhdownloadGamesIndex $whdownloadGamesPath $outputPath $preferredWhdloadGames
