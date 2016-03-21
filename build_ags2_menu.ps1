# Build AGS2 Menu
# ---------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-11
#
# A PowerShell script to build AGS2 menu with screenshots.
#


# 7-zip:
# http://7-zip.org/download.html
# http://7-zip.org/a/7z1514-x64.exe


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


# programs 
$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"


# input and output paths
#$whdloadGamesPath = [System.IO.Path]::Combine($scriptPath, "whdload_games")
$whdownloadGamesSlaveIndexPath = [System.IO.Path]::Combine($scriptPath, "whdownload_games_slave_index")
#$outputPath = [System.IO.Path]::Combine($scriptPath, "ags2_menu")
$ags2MenuIndexPath = [System.IO.Path]::Combine($outputPath, "ags2_menu.csv")


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


# 1. check if 7-zip is installed, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}


# 4. Get whdload game files
Write-Output "Reading whdload games from '$whdloadGamesPath'..."
$whdloadGameFiles = Get-ChildItem -recurse -Path $whdloadGamesPath -exclude *.html,*.csv -File
Write-Output "$($whdloadGameFiles.Count) entries"
Write-Output ""


# 9. Read whdload games index
$whdloadGameIndexFile = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_games_index.csv")
Write-Output "Reading whdload games index file '$whdloadGameIndexFile'..."
$whdloadGameIndex = ReadIndex $whdloadGameIndexFile
$whdloadGameIndex.Count


# 9. Read whdload extract index
$whdloadExtractIndexFile = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_extract_index.csv")
Write-Output "Reading whdload extract index file '$whdloadExtractIndexFile'..."
$whdloadExtractIndexIndex = ReadIndex $whdloadExtractIndexFile
$whdloadExtractIndexIndex.Count


# 10. Read whdload games index
$whdloadGameSlaveIndexFile = [System.IO.Path]::Combine($whdownloadGamesSlaveIndexPath, "whdload_slave_index.csv")
Write-Output "Reading whdload game slave index file '$whdloadGameSlaveIndexFile'..."
$whdloadGameSlaveIndex = ReadWhdloadGameSlaveIndex $whdloadGameSlaveIndexFile
$whdloadGameSlaveIndex.Count


# 10. Read whdload screenshot index
$whdloadScreenshotIndexFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "whdload_screenshots.csv")
Write-Output "Reading whdload screenshot index file '$whdloadScreenshotIndexFile'..."
$whdloadScreenshotIndex = ReadIndex $whdloadScreenshotIndexFile
$whdloadScreenshotIndex.Count


# 11. Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}



$ags2GameIndex = @{}


# 13. Process whdload game files
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


	$whdownloadGameIndexName = GetGameIndexName $whdloadGameName

	$ags2GameIndexMenuPath = [System.IO.Path]::Combine($outputPath, $whdownloadGameIndexName + ".ags")
	
	if(!(Test-Path -Path $ags2GameIndexMenuPath))
	{
		md $ags2GameIndexMenuPath | Out-Null
	}
	
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
		
		# make ags 2 game file name, removes invalid file name characters
		$ags2GameFileName = $whdloadGameName -replace "!", "" -replace ":", "" -replace """", "" -replace "/", "-" -replace "\?", ""

		# if ags 2 game file name is longer than 26 characters, then trim it to 26 characters (default filesystem compatibility with limit of ~30 characters)
		if ($ags2GameFileName.length -gt 26)
		{
			$ags2GameFileName = $ags2GameFileName.Substring(0,26).Trim()
		}

		# build new ags2 game file name, if it already exists in index
		if ($ags2GameIndex.ContainsKey($ags2GameFileName))
		{
			$count = 2
			
			do
			{
				if ($ags2GameFileName.length + $count.ToString().length -lt 26)
				{
					$newAgs2GameFileName = $ags2GameFileName + $count
				}
				else
				{
					$newAgs2GameFileName = $ags2GameFileName.Substring(0,$ags2GameFileName.length - $count.ToString().length) + $count
				}
				$count++
			} while ($ags2GameIndex.ContainsKey($newAgs2GameFileName))
			$ags2GameFileName = $newAgs2GameFileName
		}
		
		# add ags2 game file name to index
		$ags2GameIndex.Set_Item($ags2GameFileName, $true)
		
		
		# ags2 game files
		$ags2GameRunFile = [System.IO.Path]::Combine($ags2GameIndexMenuPath, "$($ags2GameFileName).run")
		$ags2GameTxtFile = [System.IO.Path]::Combine($ags2GameIndexMenuPath, "$($ags2GameFileName).txt")
		$ags2GameIffFile = [System.IO.Path]::Combine($ags2GameIndexMenuPath, "$($ags2GameFileName).iff")
		


		# get whdload screenshot
		$whdloadScreenshotGamePath = [System.IO.Path]::Combine($whdloadScreenshotPath, $whdloadGameBaseName + ".$hardware" )
		
		if (test-path -path $whdloadScreenshotGamePath)
		{
			if ($mode -eq 'aga')
			{
				$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotGamePath, "ags2aga.iff")
			}
			if ($mode -eq 'ocs')
			{
				$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotGamePath, "ags2ocs.iff")
			}
		
			# copy if screenshot exists
			if (test-path -path $whdloadScreenshotFile)
			{
				Copy-Item $whdloadScreenshotFile $ags2GameIffFile -force
			}
		}
		
		
		# get whdload extract
		$whdloadExtract = $whdloadExtractIndexIndex.Get_Item($whdloadGameFile.Name)
		
		if (!$whdloadExtract)
		{
			Write-Error "Missing extract path"
			exit 1
		}	
		
		$whdloadExtractPath = $whdloadExtract[1]
		$whdloadGamePath = "$($whdloadExtractPath)/$($whdloadGameSlaveDirectory)"

		$ags2GameRunLines = @( 
			"cd $($whdloadGamePath)", 
			"IF `$whdloadargs EQ """"", 
			"  whdload $($whdloadGameSlaveFileName)", 
			"ELSE", 
			"  whdload $($whdloadGameSlaveFileName) `$whdloadargs", 
			"ENDIF" )
		
		# write ags 2 game run file in ascii encoding
		[System.IO.File]::WriteAllText($ags2GameRunFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($ags2GameRunLines -join "`n")), [System.Text.Encoding]::ASCII)

		$ags2GameTxtLines = @(
			"$($whdloadGameName)",
			"",
			"$($whdloadGameSlaveName)"
			"$($whdloadGameSlaveCopy)")
		
		# write ags 2 game txt file in ascii encoding
		[System.IO.File]::WriteAllText($ags2GameTxtFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($ags2GameTxtLines -join "`n")), [System.Text.Encoding]::ASCII)
	}
}
