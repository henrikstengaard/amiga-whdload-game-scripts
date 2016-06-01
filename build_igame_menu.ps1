# Build iGame Menu
# ----------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-04-21
#
# A PowerShell script to build iGame gamelist and screenshots.


Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadGamesPath,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$true)]
	[string]$mode
)


# check id mode is aga or ocs
if ($mode -notmatch '^(aga|ocs)')
{
	Write-Error "Unsupported mode '$mode'"
	exit 1
}

# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


# input and output paths
$whdownloadGamesSlaveIndexPath = [System.IO.Path]::Combine($scriptPath, "whdownload_games_slave_index")


# screenshot paths
$screenshotPath = [System.IO.Path]::Combine($scriptPath, "screenshots")
$whdloadScreenshotPath = [System.IO.Path]::Combine($screenshotPath, "whdload")


# get game index name from first character in game name
function GetGameIndexName($gameName)
{
	$gameName = $gameName -replace '^[^a-z0-9]+', ''

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


# read index
function ReadIndex($indexFile)
{
	$index = @{}

	ForEach($line in (Get-Content $indexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$index.Set_Item($columns[0], $columns)
	}
	
	return $index
}


# read whdload game slave index
function ReadWhdloadGameSlaveIndex($indexFile)
{
	$index = @{}

	ForEach($line in (Get-Content $indexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		
		$whdloadGameFileName = $columns[0]
		
		$whdloadSlaves = $index.Get_Item($whdloadGameFileName)
		
		if (!$whdloadSlaves)
		{
			$whdloadSlaves = @()
		}

		$whdloadSlaves += , $columns
		$index.Set_Item($whdloadGameFileName, $whdloadSlaves)
	}
	
	return $index
}


# Get whdload game files
Write-Output "Reading whdload games from '$whdloadGamesPath'..."
$whdloadGameFiles = Get-ChildItem -recurse -Path $whdloadGamesPath -exclude *.html,*.csv -File
Write-Output "$($whdloadGameFiles.Count) entries"
Write-Output ""


# Read whdload games index
$whdloadGameIndexFile = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_games_index.csv")
Write-Output "Reading whdload games index file '$whdloadGameIndexFile'..."
$whdloadGameIndex = ReadIndex $whdloadGameIndexFile
$whdloadGameIndex.Count


# Read whdload extract index
$whdloadExtractIndexFile = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_extract_index.csv")
Write-Output "Reading whdload extract index file '$whdloadExtractIndexFile'..."
$whdloadExtractIndexIndex = ReadIndex $whdloadExtractIndexFile
$whdloadExtractIndexIndex.Count


# Read whdload games index
$whdloadGameSlaveIndexFile = [System.IO.Path]::Combine($whdownloadGamesSlaveIndexPath, "whdload_slave_index.csv")
Write-Output "Reading whdload game slave index file '$whdloadGameSlaveIndexFile'..."
$whdloadGameSlaveIndex = ReadWhdloadGameSlaveIndex $whdloadGameSlaveIndexFile
$whdloadGameSlaveIndex.Count


# Read whdload screenshot index
$whdloadScreenshotIndexFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "whdload_screenshots.csv")
Write-Output "Reading whdload screenshot index file '$whdloadScreenshotIndexFile'..."
$whdloadScreenshotIndex = ReadIndex $whdloadScreenshotIndexFile
$whdloadScreenshotIndex.Count


# Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


# 
$whdloadGameCountindex = @{}

ForEach ($whdloadGameFile in $whdloadGameFiles)
{
	# get whdload game from index
	$whdloadGame = $whdloadGameIndex.Get_Item($whdloadGameFile.Name)
	
	if (!$whdloadGame)
	{
		continue
	}
	
	$whdloadGameName = $whdloadGame[1]

	if ($whdloadGameCountindex.ContainsKey($whdloadGameName))
	{
		$count = $whdloadGameCountindex.Get_Item($whdloadGameName)
	}
	else
	{
		$count = 0
	}
	
	$count++
	
	$whdloadGameCountindex.Set_Item($whdloadGameName, $count)
}


$iGameCompleteGamesListFile = [System.IO.Path]::Combine($outputPath, "gameslist.")
$iGameCompleteGamesListLines = @()

# Process whdload game files
ForEach ($whdloadGameFile in $whdloadGameFiles)
{
	# get whdload game from index
	$whdloadGame = $whdloadGameIndex.Get_Item($whdloadGameFile.Name)
	
	if (!$whdloadGame)
	{
		continue
	}

	$hardware = ""
	
	if ($whdloadGameFile.Name -match '_cd32')
	{
		$hardware = "cd32"
	}
	if ($whdloadGameFile.Name -match '_aga')
	{
		$hardware = "aga"
	}
	if ($whdloadGameFile.Name -match '_cdtv')
	{
		$hardware = "cdtv"
	}

	
	$whdloadGameName = $whdloadGame[1]


	$whdloadGameBaseName = [System.IO.Path]::GetFileNameWithoutExtension($whdloadGameFile.FullName) -split "_" | Select-Object -first 1


	
	$whdloadGameSlaves = $whdloadGameSlaveIndex.Get_Item($whdloadGameFile.Name)

	
	if (!$whdloadGameSlaves)
	{
		Write-Error "No slave '$whdloadGameBaseName'"
		exit 1
	}
	
	ForEach($whdloadGameSlave in $whdloadGameSlaves)
	{
		# get whdload game slave file name and copy columns
		$whdloadGameSlaveFile = $whdloadGameSlave[1]
		$whdloadGameSlaveName = $whdloadGameSlave[3].Replace("CD??", "CD32")
		$whdloadGameSlaveCopy = $whdloadGameSlave[4]
		
		# get whdload game slave directory from whdload game slave file
		$whdloadGameSlaveDirectory = [System.IO.Path]::GetDirectoryName($whdloadGameSlaveFile)
		$whdloadGameSlaveFileName = [System.IO.Path]::GetFileName($whdloadGameSlaveFile)
		
		# get whdload extract
		$whdloadExtract = $whdloadExtractIndexIndex.Get_Item($whdloadGameFile.Name)

		# check if whdload extract path exists
		if (!$whdloadExtract)
		{
			Write-Error "Missing extract path"
			exit 1
		}	

		
		$whdloadExtractPath = $whdloadExtract[1]
		$whdloadGamePath = "$($whdloadExtractPath)/$($whdloadGameSlaveDirectory)"
		


		
		# 
		$iGameWhdloadPath = [System.IO.Path]::Combine($outputPath, ($whdloadGamePath -replace ":", "\" -replace "/", "\"))

		if(!(Test-Path -Path $iGameWhdloadPath))
		{
			md $iGameWhdloadPath | Out-Null
		}
		

		# igame files
		$iGameGameIffFile = [System.IO.Path]::Combine($iGameWhdloadPath, "igame.iff")
		

		# get whdload screenshot
		$whdloadScreenshotGamePath = [System.IO.Path]::Combine($whdloadScreenshotPath, $whdloadGameBaseName + ".$hardware" )
		
		if (test-path -path $whdloadScreenshotGamePath)
		{
			$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotGamePath, "igame.iff")
		
			# copy if screenshot exists
			if (test-path -path $whdloadScreenshotFile)
			{
				Copy-Item $whdloadScreenshotFile $iGameGameIffFile -force
			}
		}

		
		$iGameTitle = "$($whdloadGameName)"
		
		# append slave name to igame title in parantheses, if game has multiple slaves
		if ($whdloadGameSlaves.Count -gt 1)
		{
			$slaveName = [System.IO.Path]::GetFileNameWithoutExtension($whdloadGameSlaveFile)

			if ($iGameTitle -match '\s+\([^\(\)]+\)')
			{
				$iGameTitle = $iGameTitle -replace '(\s+\([^\(\)]+)\)', '$1'
				$iGameTitle += ", $($slaveName))"
			}
			else
			{
				$iGameTitle += " ($($slaveName))"
			}
		}
		
		
		# build igame game gameslist lines
		$iGameGameGamesListLines = @(
			"index=0",
			"title=$($iGameTitle)",
			"genre=Unknown",
			"path=$($whdloadGamePath)/$($whdloadGameSlaveFileName)",
			"favorite=0",
			"timesplayed=0",
			"lastplayed=0",
			"hidden=0",
			"" )

		# add igame gameslist lines
		$iGameCompleteGamesListLines += $iGameGameGamesListLines
	}
}

# write complete igame gameslist file in ascii encoding
[System.IO.File]::WriteAllText($iGameCompleteGamesListFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($iGameCompleteGamesListLines -join "`n")), [System.Text.Encoding]::ASCII)
