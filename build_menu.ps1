# Build Menu
# ----------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-09-11
#
# A PowerShell script to build AGS2 and iGame menus. 
# Whdload slave details file is used for building AGS2 menu item text per whdload slave and whdload screenshots file can optionally be used to add screenshots for each whdload slave.


Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadSlavesFile,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$true)]
	[string]$assignName,
	[Parameter(Mandatory=$true)]
	[string]$detailColumns,
	[Parameter(Mandatory=$true)]
	[string]$ags2NameFormat,
	[Parameter(Mandatory=$true)]
	[string]$iGameNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$whdloadScreenshotsFile,
	[Parameter(Mandatory=$false)]
	[switch]$usePartitions,
	[Parameter(Mandatory=$false)]
	[int32]$partitionSplitSize,
	[Parameter(Mandatory=$false)]
	[switch]$aga,
	[Parameter(Mandatory=$false)]
	[switch]$ags2,
	[Parameter(Mandatory=$false)]
	[switch]$iGame
)


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

function Capitalize([string]$text)
{
	if ($text.length -eq 1)
	{
		return $text.ToUpper()
	}

	return $text.Substring(0,1).ToUpper() + $text.Substring(1)
}

function BuildName($nameFormat, $whdloadSlave)
{
	$name = $nameFormat

	$nameFormatProperties = $whdloadSlave.psobject.Properties | where { $nameFormat -match $_.Name }

	if ($nameFormatProperties.Count -gt 0)
	{
		foreach ($property in $nameFormatProperties)
		{
			$name = $name.Replace('[$' + $property.Name + ']', (Capitalize $property.Value))
		}
	}
	else
	{
		$name = $whdloadSlave.WhdloadName	
	}


	# set whdload slave file name
	$whdloadSlaveFileName = [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath)

	# TODO: make better extra
	$extra = $whdloadSlaveFileName -replace '\.slave', '' -replace $whdloadSlave.WhdloadName, ''

	if ($extra.length -gt 0)
	{
		$name += ' ' + $extra
	}
	
	return $name
}


# resolve paths
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
$whdloadSlavesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSlavesFile)
$whdloadScreenshotsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadScreenshotsFile)
$whdloadScreenshotsPath = [System.IO.Path]::GetDirectoryName($whdloadScreenshotsFile)

# detail columns
$detailColumnsList = @( "Whdload" )
$detailColumnsList +=, $detailColumns -split ','
$detailColumnsPadding = ($detailColumnsList | sort @{expression={$_.Length};Ascending=$false} | Select-Object -First 1).Length


if ($ags2)
{
	$ags2OutputPath = [System.IO.Path]::Combine($outputPath, "ags2")
	if(!(Test-Path -Path $ags2OutputPath))
	{
		md $ags2OutputPath | Out-Null
	}
}

if ($iGame)
{
	$iGameOutputPath = [System.IO.Path]::Combine($outputPath, "igame")
	if(!(Test-Path -Path $iGameOutputPath))
	{
		md $iGameOutputPath | Out-Null
	}
}


# read whdload slaves
$whdloadSlaves = Import-Csv -Delimiter ';' $whdloadSlavesFile | sort @{expression={$_.WhdloadName};Ascending=$true} 

# read whdload screenshots file
$whdloadScreenshots = Import-Csv -Delimiter ';' $whdloadScreenshotsFile

# index whdload screenshots
$whdloadScreenshotsIndex = @{}

foreach($whdloadScreenshot in $whdloadScreenshots)
{
	if ($whdloadScreenshotsIndex.ContainsKey($whdloadScreenshot.WhdloadSlaveFilePath))
	{
		Write-Error ("Duplicate whdload screenshot for '" + $whdloadScreenshot.WhdloadSlaveFilePath + "'")
	}

	$whdloadScreenshotsIndex.Set_Item($whdloadScreenshot.WhdloadSlaveFilePath, $whdloadScreenshot.ScreenshotDirectoryName)
}


# partition and whdload size variables
$partitionNumber = 1
$partitionSize = 0
$whdloadSizeIndex = @{}

# screenshot variables
$whdloadScreenshotsPath = [System.IO.Path]::GetDirectoryName($whdloadScreenshotsFile)

# ags2 variables 
$ags2MenuItemFileNameIndex = @{}

# igame variables
$iGameGamesListLines = @()
$iGameReposLines = @()

if ($usePartitions)
{
	$iGameReposLines += ($assignName + $partitionNumber)
}
else
{
	$iGameReposLines += $assignName
}

# other output variables
$validatePathsScriptPart = 1
$validatePathsScriptLines = @()
$whdloadListAGS2Lines = @()
$whdloadListiGameLines = @()
$whdloadListColumnsPadding = ($whdloadSlaves | sort @{expression={$_.WhdloadName.Length};Ascending=$false} | Select-Object -First 1).WhdloadName.Length


# build menu from whdload slaves
foreach($whdloadSlave in $whdloadSlaves)
{
	# increase partition number, if using partitions and whdload size if larger than partition split size	
	if ($usePartitions)
	{
		if (!$whdloadSizeIndex.ContainsKey($whdloadSlave.WhdloadName))
		{
			# add whdload size to index
			$whdloadSizeIndex.Set_Item($whdloadSlave.WhdloadName, $whdloadSlave.WhdloadSize)

			# increase partition number, if whdload size and partition size is greater than partition split size
			if (($partitionSize + $whdloadSlave.WhdloadSize) -gt $partitionSplitSize)
			{
				if ($ags2)
				{
					# write whdload list ags2 file 
					$ags2MenuAssignDir = [System.IO.Path]::Combine($ags2OutputPath, $assignPath)

					if(!(Test-Path -Path $ags2MenuAssignDir))
					{
						md $ags2MenuAssignDir | Out-Null
					}
					
					$whdloadListAGS2File = [System.IO.Path]::Combine($ags2MenuAssignDir, "WhdloadListAGS2")
					[System.IO.File]::WriteAllText($whdloadListAGS2File, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($whdloadListAGS2Lines -join "`n")), [System.Text.Encoding]::ASCII)
					
					# reset whdload list ags2
					$whdloadListAGS2Lines = @()
				}

				if ($iGame)
				{
					# write whdload list igame file 
					$iGameAssignDir = [System.IO.Path]::Combine($iGameOutputPath, $assignPath)

					if(!(Test-Path -Path $iGameAssignDir))
					{
						md $iGameAssignDir | Out-Null
					}

					$whdloadListiGameFile = [System.IO.Path]::Combine($iGameAssignDir, "WhdloadListiGame")
					[System.IO.File]::WriteAllText($whdloadListiGameFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($whdloadListiGameLines -join "`n")), [System.Text.Encoding]::ASCII)

					# reset whdload list igame
					$whdloadListiGameLines = @()
				}

				$partitionNumber++
				$partitionSize = 0

				$iGameReposLines += ($assignName + $partitionNumber)
			}

			# add whdload slave size to partition size
			$partitionSize += $whdloadSlave.WhdloadSize
		}

		# set assign path with partition number
		$assignPath = $assignName + $partitionNumber

		# add assign name property to whdload slave
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value ($assignName + $partitionNumber)
	}
	else 
	{
		# set assign path
		$assignPath = $assignName

		# add assign name property to whdload slave
		$whdloadSlave | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value $assignName
	}


	# set whdload slave start path and replace backslash with slash
	$whdloadSlaveStartPath = ($assignPath + ":" + [System.IO.Path]::GetDirectoryName($whdloadSlave.WhdloadSlaveFilePath)).Replace("\", "/")

	# add tailing slash, if not present
	if ($whdloadSlaveStartPath -notmatch '/$')
	{
		$whdloadSlaveStartPath += "/"
	}

	# set whdload slave file name
	$whdloadSlaveFileName = [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath)

	# add whdload slave path checks to validate paths script 
	$validatePathsScriptLines += @( 
			("IF NOT EXIST """ + $whdloadSlaveStartPath + """"), 
			("  ECHO ""ERROR: Path '" + $whdloadSlaveStartPath + "' doesn't exist!"""), 
			"ENDIF", 
			("IF NOT EXIST """ + $whdloadSlaveStartPath + $whdloadSlaveFileName + """"), 
			("  ECHO ""ERROR: Path '" + $whdloadSlaveStartPath + $whdloadSlaveFileName + "' doesn't exist!"""), 
			"ENDIF") 

	# build ags2 menu for whdload slave
	if ($ags2)
	{
		# build ags2 name
		$ags2Name = Capitalize (BuildName $ags2NameFormat $whdloadSlave)

		# add whdload and ags2 names to list
		$whdloadListAGS2Lines += (("{0,-" + $whdloadListColumnsPadding + "}   {1}") -f $whdloadSlave.WhdloadName, $ags2Name)

		# remove invalid characters from AGS 2 menu item file name
		$ags2MenuItemFileName = $ags2Name -replace "!", "" -replace ":", "" -replace """", "" -replace "/", "-" -replace "\?", ""

		# if ags 2 file name is longer than 26 characters, then trim it to 26 characters (default filesystem compatibility with limit of ~30 characters)
		if ($ags2MenuItemFileName.length -gt 26)
		{
			$ags2MenuItemFileName = $ags2MenuItemFileName.Substring(0,26).Trim()
		}
		

		# build new ags2 file name, if it already exists in index
		if ($ags2MenuItemFileNameIndex.ContainsKey($ags2MenuItemFileName))
		{
			$newAgs2MenuItemFileName = $ags2MenuItemFileName
			$count = 2
			
			do
			{
				if ($newAgs2MenuItemFileName.length -lt 26)
				{
					$newAgs2MenuItemFileName += ' '
				}
				else
				{
					$newAgs2MenuItemFileName = $newAgs2MenuItemFileName.Substring(0,$newAgs2MenuItemFileName.length - $count.ToString().length - 2) + ' #' + $count
					$count++
				}
			} while ($ags2MenuItemFileNameIndex.ContainsKey($newAgs2MenuItemFileName))

			$ags2MenuItemFileName = $newAgs2MenuItemFileName
		}
		
		# add ags2 file name to index
		$ags2MenuItemFileNameIndex.Set_Item($ags2MenuItemFileName, $true)
		

		$ags2MenuDir = [System.IO.Path]::Combine($ags2OutputPath, "menu")
		$ags2MenuItemIndexName = GetIndexName $ags2MenuItemFileName
		$ags2MenuItemPath = [System.IO.Path]::Combine($ags2MenuDir, $ags2MenuItemIndexName + ".ags")

		if(!(Test-Path -Path $ags2MenuItemPath))
		{
			md $ags2MenuItemPath | Out-Null
		}


		# set ags2 menu files
		$ags2MenuItemRunFile = [System.IO.Path]::Combine($ags2MenuItemPath, "$($ags2MenuItemFileName).run")
		$ags2MenuItemTxtFile = [System.IO.Path]::Combine($ags2MenuItemPath, "$($ags2MenuItemFileName).txt")
		$ags2MenuItemIffFile = [System.IO.Path]::Combine($ags2MenuItemPath, "$($ags2MenuItemFileName).iff")


		# build ags 2 menu item run lines
		$ags2MenuItemRunLines = @( 
			("cd """ + $whdloadSlaveStartPath + """"), 
			"IF `$whdloadargs EQ """"", 
			("  whdload """ + $whdloadSlaveFileName + """"), 
			"ELSE", 
			("  whdload """ + $whdloadSlaveFileName + """ `$whdloadargs"), 
			"ENDIF" )

		# write ags 2 menu item run file in ascii encoding
		[System.IO.File]::WriteAllText($ags2MenuItemRunFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($ags2MenuItemRunLines -join "`n")), [System.Text.Encoding]::ASCII)

		
		# build ags 2 menu item txt lines
		$ags2MenuItemTxtLines = @()

		$detailColumnsIndex = @{}

		if ($whdloadSlave.DetailMatch -and $whdloadSlave.DetailMatch -ne '')
		{
			foreach ($property in ($whdloadSlave.psobject.Properties | Where { $_.Name -match '^Detail' -and $_.Value } ))
			{
				$detailColumnsIndex.Set_Item(($property.Name -replace '^Detail', ''), (Capitalize $property.Value))
			}
		}
		else
		{
			Write-Host ("Warning: No details for whdload name '" + $whdloadSlave.WhdloadName + "', query '" + $whdloadSlave.Query + "'")

			$detailColumnsIndex.Set_Item("Name", (Capitalize $whdloadSlave.WhdloadSlaveName.Replace("CD??", "CD32")))
		}

		foreach($column in $detailColumnsList)
		{
			if (!$detailColumnsIndex.ContainsKey($column))
			{
				continue
			}

			$ags2MenuItemTxtLines += (("{0,-" + $detailColumnsPadding + "} : {1}") -f $column, $detailColumnsIndex.Get_Item($column))
		}

		$ags2MenuItemTxtLines += (("{0,-" + $detailColumnsPadding + "} : {1}") -f "Whdload", [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath))


		# write ags 2 menu item txt file in ascii encoding
		[System.IO.File]::WriteAllText($ags2MenuItemTxtFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($ags2MenuItemTxtLines -join "`n")), [System.Text.Encoding]::ASCII)
	}


	# build igame menu for whdload slave
	if ($iGame)
	{
		# build igame name
		$iGameName = BuildName $iGameNameFormat $whdloadSlave

		$iGameMenuItemName = Capitalize $iGameName

		# add whdload and ags2 names to list
		$whdloadListiGameLines += (("{0,-" + $whdloadListColumnsPadding + "}   {1}") -f $whdloadSlave.WhdloadName, $iGameMenuItemName)

		# build igame game gameslist lines
		$iGameGameLines = @(
			"index=0",
			("title=" + $iGameMenuItemName),
			"genre=Unknown",
			("path=" + $whdloadSlaveStartPath + $whdloadSlaveFileName),
			"favorite=0",
			"timesplayed=0",
			"lastplayed=0",
			"hidden=0",
			"")

		# add game to igame gameslist lines
		$iGameGamesListLines += $iGameGameLines
	}


	# use whdload screenshot, if it exists in index	
	if ($whdloadScreenshotsIndex.ContainsKey($whdloadSlave.WhdloadSlaveFilePath))
	{
		$screenshotDirectoryName = $whdloadScreenshotsIndex.Get_Item($whdloadSlave.WhdloadSlaveFilePath)
		$whdloadScreenshotPath = [System.IO.Path]::Combine($whdloadScreenshotsPath, $screenshotDirectoryName)
		
		# copy ags2 screenshot for whdload slave
		if ($ags2)
		{
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

		# copy igame screenshot for whdload slave
		if ($iGame)
		{
			$iGameAssignDir = [System.IO.Path]::Combine($iGameOutputPath, $assignPath)
			$iGameWhdloadSlaveDir = [System.IO.Path]::Combine($iGameAssignDir, [System.IO.Path]::GetDirectoryName($whdloadSlave.WhdloadSlaveFilePath).Replace("/", "\"))

			$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "igame.iff")
			
			# copy whdload screenshot file, if it exists
			if (test-path -path $whdloadScreenshotFile)
			{
				if(!(Test-Path -Path $iGameWhdloadSlaveDir))
				{
					md $iGameWhdloadSlaveDir | Out-Null
				}

				Copy-Item $whdloadScreenshotFile $iGameWhdloadSlaveDir -force
			}

			$whdloadiGameScreenshotFile = $whdloadSlaveStartPath + "igame.iff"

			# add igame path checks to validate paths script
			$validatePathsScriptLines += @( 
					("IF NOT EXIST """ + $whdloadiGameScreenshotFile + """"), 
					("  ECHO ""ERROR: Path '" + $whdloadiGameScreenshotFile +  "' doesn't exist!"""), 
					"ENDIF") 
		}
	}

	# write validate paths script part, if it has more than 2000 lines
	if ($validatePathsScriptLines.Count -gt 2000)
	{
		# write validate paths script file
		$validatePathsScriptFile = [System.IO.Path]::Combine($outputPath, ("validate_paths_part" + $validatePathsScriptPart))
		[System.IO.File]::WriteAllText($validatePathsScriptFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($validatePathsScriptLines -join "`n")), [System.Text.Encoding]::ASCII)

		$validatePathsScriptPart++
		$validatePathsScriptLines = @()
	}
}

# write validate paths script file
$validatePathsScriptFile = [System.IO.Path]::Combine($outputPath, ("validate_paths_part" + $validatePathsScriptPart))
[System.IO.File]::WriteAllText($validatePathsScriptFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($validatePathsScriptLines -join "`n")), [System.Text.Encoding]::ASCII)

# write whdload slaves file
$whdloadSlavesFile = [System.IO.Path]::Combine($outputPath, "whdload_slaves.csv")
$whdloadSlaves | export-csv -delimiter ';' -path $whdloadSlavesFile -NoTypeInformation -Encoding UTF8

if ($ags2)
{
	# write whdload list ags2 file 
	$ags2MenuAssignDir = [System.IO.Path]::Combine($ags2OutputPath, $assignPath)

	if(!(Test-Path -Path $ags2MenuAssignDir))
	{
		md $ags2MenuAssignDir | Out-Null
	}
	
	$whdloadListAGS2File = [System.IO.Path]::Combine($ags2MenuAssignDir, "WhdloadListAGS2")
	[System.IO.File]::WriteAllText($whdloadListAGS2File, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($whdloadListAGS2Lines -join "`n")), [System.Text.Encoding]::ASCII)
}

if ($iGame)
{
	# write whdload list igame file 
	$iGameAssignDir = [System.IO.Path]::Combine($iGameOutputPath, $assignPath)

	if(!(Test-Path -Path $iGameAssignDir))
	{
		md $iGameAssignDir | Out-Null
	}

	$whdloadListiGameFile = [System.IO.Path]::Combine($iGameAssignDir, "WhdloadListiGame")
	[System.IO.File]::WriteAllText($whdloadListiGameFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($whdloadListiGameLines -join "`n")), [System.Text.Encoding]::ASCII)
	
	# write igame gameslist file in ascii encoding
	$iGameGamesListFile = [System.IO.Path]::Combine($iGameOutputPath, "gameslist.")
	[System.IO.File]::WriteAllText($iGameGamesListFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($iGameGamesListLines -join "`n")), [System.Text.Encoding]::ASCII)

	# write igame repos file in ascii encoding
	$iGameReposFile = [System.IO.Path]::Combine($iGameOutputPath, "repos.")
	[System.IO.File]::WriteAllText($iGameReposFile, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::UTF8.GetBytes($iGameReposLines -join "`n")), [System.Text.Encoding]::ASCII)
}