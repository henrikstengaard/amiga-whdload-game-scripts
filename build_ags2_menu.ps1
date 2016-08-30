# Build AGS2 Menu
# ---------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-08-28
#
# A PowerShell script to build AGS2 menu.


Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadSlavesFile,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$true)]
	[string]$assignName,
	[Parameter(Mandatory=$true)]
	[string]$detailColumns,
	[Parameter(Mandatory=$false)]
	[string]$whdloadScreenshotsFile,
	[Parameter(Mandatory=$false)]
	[switch]$usePartitions,
	[Parameter(Mandatory=$false)]
	[int32]$partitionSplitSize,
	[Parameter(Mandatory=$false)]
	[switch]$aga
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


# resolve paths
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
$whdloadSlavesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSlavesFile)
$whdloadScreenshotsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadScreenshotsFile)


# detail columns
$detailColumnsList = @()
$detailColumnsList +=, $detailColumns -split ','
$detailColumnsPadding = ($detailColumnsList | sort @{expression={$_.Length};Ascending=$false} | Select-Object -First 1).Length


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

	
	# build ags 2 menu item txt lines
	$ags2MenuItemTxtLines = @()

	$detailColumnsIndex = @{}

	if ($whdloadSlave.DetailMatch -and $whdloadSlave.DetailMatch -ne '')
	{
		foreach ($property in ($whdloadSlave.psobject.Properties | Where { $_.Name -match '^Detail' -and $_.Value } ))
		{
			$detailColumnsIndex.Set_Item(($property.Name -replace '^Detail', ''), $property.Value)
		}
	}
	else
	{
		Write-Host ("Warning: No details for whdload name '" + $whdloadSlave.WhdloadName + "', query '" + $whdloadSlave.Query + "'")

		$detailColumnsIndex.Set_Item("Name", $whdloadSlave.WhdloadSlaveName.Replace("CD??", "CD32"))
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

