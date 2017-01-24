# Build Menu
# ----------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-10-11
#
# A PowerShell script to build AGS2, AMS and iGame menus. 
# Whdload slave details file is used for building AGS2 and AMS menu item text per whdload slave and whdload screenshots file can optionally be used to add screenshots for each whdload slave.


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
	[string]$ags2NameFormat,
	[Parameter(Mandatory=$false)]
	[string]$iGameNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$amsNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$hstwbNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$ags2MenuItemRunTemplateFile,
	[Parameter(Mandatory=$false)]
	[string]$amsMenuItemRunTemplateFile,
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
	[switch]$iGame,
	[Parameter(Mandatory=$false)]
	[switch]$ams
)


# exit, if ags2 is enabled and ags2 name format is not defined
if ($ags2 -and !$ags2NameFormat)
{
	Write-Error "AGS2 name format is not defined for AGS2 menu"
	exit 1
}


# exit, if ags2 is enabled and ags2 menu item file template file not defined
if ($ags2 -and !$ags2MenuItemRunTemplateFile)
{
	Write-Error "AGS2 menu item file template file is not defined for AGS2 menu"
	exit 1
}


# exit, if ams is enabled and ams name format is not defined
if ($ams -and !$amsNameFormat)
{
	Write-Error "AMS name format is not defined for AMS menu"
	exit 1
}


# exit, if ams is enabled and ams menu item file template file not defined
if ($ams -and !$amsMenuItemRunTemplateFile)
{
	Write-Error "AMS menu item file template file is not defined for AMS menu"
	exit 1
}


# exit, if iGame is enabled and iGame name format is not defined
if ($iGame -and !$iGameNameFormat)
{
	Write-Error "iGame name format is not defined for iGame menu"
	exit 1
}


# exit, if HstWB name format is not defined
if (!$hstwbNameFormat)
{
	Write-Error "HstWB name format is not defined"
	exit 1
}


# resolve paths
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
$whdloadSlavesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSlavesFile)
$whdloadScreenshotsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadScreenshotsFile)
$whdloadScreenshotsPath = [System.IO.Path]::GetDirectoryName($whdloadScreenshotsFile)
if ($ags2MenuItemRunTemplateFile)
{
	$ags2MenuItemRunTemplateFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ags2MenuItemRunTemplateFile)
}
if ($amsMenuItemRunTemplateFile)
{
	$amsMenuItemRunTemplateFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($amsMenuItemRunTemplateFile)
}
$whdloadRunTemplateFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("whdload_run_template.txt")

$maxMenuItemFileNameLength = 26

# detail columns
$detailColumnsList = @( "Whdload" )
$detailColumnsList +=, $detailColumns -split ','
$detailColumnsPadding = ($detailColumnsList | sort @{expression={$_.Length};Ascending=$false} | Select-Object -First 1).Length


# get index name from first character in name
function GetIndexName($name)
{
	if (($name -replace '^[^a-z0-9]+', '') -match '^[0-9]') 
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
	if (!$text -or $text -eq '')
	{
		return ''
	}

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

	$name = $name -replace '\s*\[[^\[\]]*\]', ''

	$whdloadSlaveName = [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath) -replace '\.slave$'

	if ($whdloadSlave.WhdloadName -ne $whdloadSlaveName)
	{
		$extra = $whdloadSlaveName.Replace($whdloadSlave.WhdloadName, '')

		$whdloadNameWithoutHardware = $whdloadSlave.WhdloadName.Replace($whdloadSlave.FilteredHardware, '')
		$extra = $extra.Replace($whdloadNameWithoutHardware, '')

		if ($whdloadSlave.DetailName)
		{
			$extra = $extra.Replace($whdloadSlave.DetailName, '')
		}

		if ($whdloadSlave.FilteredName)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredName, '')
		}

		if ($whdloadSlave.FilteredHardware)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredHardware, '')
		}

		if ($whdloadSlave.FilteredCompilation)
		{
			$extra = $extra.Replace(($whdloadSlave.FilteredCompilation -replace '^[&_]', '' -replace '[&_]$', ''), '')
		}

		if ($whdloadSlave.FilteredLanguage)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredLanguage, '')
		}

		if ($whdloadSlave.FilteredHardware)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredHardware, '')
		}

		if ($whdloadSlave.FilteredMemory)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredMemory, '')
		}

		if ($whdloadSlave.FilteredDemo)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredDemo, '')
		}

		if ($whdloadSlave.FilteredOther)
		{
			$extra = $extra.Replace($whdloadSlave.FilteredOther, '')
		}

		$extra = $extra -replace '^[&_]', '' -replace '[&_]$', ''

		if ($extra.Length -gt 0)
		{
			$name += ' ' + $extra
		}
	}

	if ($whdloadSlave.FilteredCompilation -and !$name.Contains($whdloadSlave.FilteredCompilation))
	{
		$name += ' ' + ($whdloadSlave.FilteredCompilation -replace '^[&_]', '' -replace '[&_]$', '' -replace ',', ' ')
	}

	if ($whdloadSlave.FilteredLanguage)
	{
		$name += ' ' + ($whdloadSlave.FilteredLanguage.ToUpper() -replace ',', ' ')
	}

	if ($whdloadSlave.FilteredHardware -notmatch '(ocs|ecs)')
	{
		$name += ' ' + ($whdloadSlave.FilteredHardware.ToUpper() -replace ',', ' ')
	}

	if ($whdloadSlave.FilteredMemory)
	{
		$name += ' ' + ($whdloadSlave.FilteredMemory.ToUpper() -replace ',', ' ')
	}

	if ($whdloadSlave.FilteredDemo)
	{
		$name += ' ' + ($whdloadSlave.FilteredDemo -replace ',', ' ')
	}

	if ($whdloadSlave.FilteredOther)
	{
		$name += ' ' + ($whdloadSlave.FilteredOther -replace '^[&_]', '' -replace '[&_]$', '' -replace ',', ' ')
	}

	return $name
}

function WriteAmigaTextLines($path, $lines)
{
	$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1");
	$utf8 = [System.Text.Encoding]::UTF8;

	$amigaTextBytes = [System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($lines -join "`n"))
	[System.IO.File]::WriteAllText($path, $iso88591.GetString($amigaTextBytes), $iso88591)
}

function WriteAmigaTextString($path, $text)
{
	$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1");
	$utf8 = [System.Text.Encoding]::UTF8;

	$amigaTextBytes = [System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($text))
	[System.IO.File]::WriteAllText($path, $iso88591.GetString($amigaTextBytes), $iso88591)
}

function BuildMenuItemFileName($name, $menuItemFileNameIndex)
{
	# make menu item file name by normalizing text and remove file name invalid characters
	$menuItemFileName = (Normalize $name) -replace ',', '.' -replace '[^a-z0-9\.\-+_ ]', '' -replace '\s+', ' '

	# if menu item file name is longer than max menu item file name length, then trim it to max menu item file name length characters
	if ($menuItemFileName.length -gt $maxMenuItemFileNameLength)
	{
		$menuItemFileName = $menuItemFileName.Substring(0, $maxMenuItemFileNameLength).Trim()
	}
	

	# build new menu item file name, if it already exists in index
	if ($menuItemFileNameIndex.ContainsKey($menuItemFileName))
	{
		$newMenuItemFileName = $menuItemFileName
		$count = 2
		
		do
		{
			if ($newMenuItemFileName.length -lt $maxMenuItemFileNameLength)
			{
				$newMenuItemFileName += ' '
			}
			else
			{
				$newMenuItemFileName = $newMenuItemFileName.Substring(0,$newMenuItemFileName.length - $count.ToString().length - 2) + ' V' + $count
				$count++
			}
		} while ($menuItemFileNameIndex.ContainsKey($newMenuItemFileName))

		$menuItemFileName = $newMenuItemFileName
	}
	
	# add menu item file name to index
	$menuItemFileNameIndex.Set_Item($menuItemFileName, $true)
	
	return $menuItemFileName
}

function BuildTemplateText($templateFile, $parameters)
{
	$templateText = [System.IO.File]::ReadAllText($templateFile)

	foreach($name in $parameters.Keys)
	{
		$placeholderText = ('[$' + $name + ']')
		$placeholderValue = $parameters.Get_Item($name)
		$templateText = $templateText.Replace($placeholderText, $placeholderValue) 
	}

	return $templateText
}

function BuildMenuItemChangeDirectoryText($dataPath)
{
	return ("Assign Data: " + $dataPath + "`nExecute RAM:AMSLoader")
}

function BuildMenuItemDetailText($whdloadSlave)
{
	# build menu item text lines
	$menuItemDetailTextLines = @()

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

	if ($whdloadSlave.FilteredLanguage)
	{
		switch ($whdloadSlave.FilteredLanguage.ToLower())
		{
			"dk" { $language = "Danish" }
			"de" { $language = "German" }
			"fr" { $language = "French" }
			"it" { $language = "Italian" }
			"se" { $language = "Swedish" }
			"pl" { $language = "Polish" }
			"es" { $language = "Spanish" }
			"cz" { $language = "Czech" }
			"fi" { $language = "Finnish" }
			"gr" { $language = "Greek" }
			"cv" { $language = "Cabo Verde" }
		}

		if ($language)
		{
			$detailColumnsIndex.Set_Item("Language", $language)
		}
	}

	$version = @()

	if ($whdloadSlave.FilteredCompilation)
	{
		$version += $whdloadSlave.FilteredCompilation -replace '&', '' -replace ',', ' '
	}
	
	if ($whdloadSlave.FilteredHardware -notmatch '(ocs|ecs)')
	{
		$version += $whdloadSlave.FilteredHardware.ToUpper() -replace ',', ' '
	}

	if ($whdloadSlave.FilteredMemory)
	{
		$version += $whdloadSlave.FilteredMemory.ToUpper() -replace ',', ' '
	}

	if ($whdloadSlave.FilteredDemo)
	{
		$version += $whdloadSlave.FilteredDemo -replace ',', ' '
	}

	if ($whdloadSlave.FilteredOther)
	{
		$version += $whdloadSlave.FilteredOther -replace ',', ' '
	}

	if ($version.Count -gt 0)
	{
		$detailColumnsIndex.Set_Item("Version", ($version -join ' '))
	}

	foreach($column in $detailColumnsList)
	{
		if (!$detailColumnsIndex.ContainsKey($column))
		{
			continue
		}

		$menuItemDetailTextLines += (("{0,-" + $detailColumnsPadding + "} : {1}") -f $column, $detailColumnsIndex.Get_Item($column))
	}

	$menuItemDetailTextLines += (("{0,-" + $detailColumnsPadding + "} : {1}") -f "Whdload", [System.IO.Path]::GetFileName($whdloadSlave.WhdloadSlaveFilePath))
	
	return $menuItemDetailTextLines -join "`n"
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

function Normalize([string]$text)
{
	return RemoveDiacritics (ConvertSuperscript $text)
}


# make whdload output directory
$whdloadOutputPath = [System.IO.Path]::Combine($outputPath, "whdload")
if(!(Test-Path -Path $whdloadOutputPath))
{
	md $whdloadOutputPath | Out-Null
}


# make AGS2 output directory
if ($ags2)
{
	$ags2OutputPath = [System.IO.Path]::Combine($outputPath, "ags2")
	if(!(Test-Path -Path $ags2OutputPath))
	{
		md $ags2OutputPath | Out-Null
	}
}


# make ams output directory
if ($ams)
{
	$amsOutputPath = [System.IO.Path]::Combine($outputPath, "ams")
	if(!(Test-Path -Path $amsOutputPath))
	{
		md $amsOutputPath | Out-Null
	}
}


# make igame output directory
if ($igame)
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
		continue;
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

# ams variables 
$amsMenuItemFileNameIndex = @{}

# hstwb variables
$hstwbMenuItemFileNameIndex = @{}


if ($usePartitions)
{
	$iGameReposLines += ($assignName + $partitionNumber)
}
else
{
	$iGameReposLines += $assignName
}

# other output variables
$validatePathsPartScript = 1
$validatePathsPartScriptLines = @()
$ags2WhdloadListLines = @()
$iGameWhdloadListLines = @()
$amsWhdloadListLines = @()
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
	$validatePathsPartScriptLines += @( 
			("IF NOT EXISTS """ + $whdloadSlaveStartPath + """"), 
			("  ECHO ""ERROR: Path '" + $whdloadSlaveStartPath + "' doesn't exist!"""), 
			"ENDIF", 
			("IF NOT EXISTS """ + $whdloadSlaveStartPath + $whdloadSlaveFileName + """"), 
			("  ECHO ""ERROR: Path '" + $whdloadSlaveStartPath + $whdloadSlaveFileName + "' doesn't exist!"""), 
			"ENDIF") 


    # build hstwb menuitem data files
	$hstwbMenuItemDataLines = @(";HstWB menu item data")
	$hstwbMenuItemDataLines += ("Name=" + (Capitalize (BuildName $hstwbNameFormat $whdloadSlave)))
	$hstwbMenuItemDataLines += "RunFile=$whdloadSlaveFileName"


	# build ags2 menu for whdload slave
	if ($ags2)
	{
		# build ags2 name
		$ags2Name = Capitalize (BuildName $ags2NameFormat $whdloadSlave)

		# add whdload slave to ags2 whdload list
		if ($ags2WhdloadListLines.Count -eq 0)
		{
			$ags2WhdloadListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $whdloadListColumnsPadding + "}   {2}") -f "Assign", "Whdload", "AGS2")
		}
		$ags2WhdloadListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $whdloadListColumnsPadding + "}   {2}") -f ($assignPath + ":"), $whdloadSlave.WhdloadName, $ags2Name)

		# build ags2 menu item file name
		$ags2MenuItemFileName = BuildMenuItemFileName $ags2Name $ags2MenuItemFileNameIndex
		

		$ags2MenuDir = [System.IO.Path]::Combine($ags2OutputPath, "menu")
		$ags2MenuItemIndexName = GetIndexName $ags2MenuItemFileName
		$ags2MenuItemPath = [System.IO.Path]::Combine($ags2MenuDir, $ags2MenuItemIndexName + ".ags")

		if(!(Test-Path -Path $ags2MenuItemPath))
		{
			md $ags2MenuItemPath | Out-Null
		}


		# set ags2 menu files
		$ags2MenuItemRunFile = [System.IO.Path]::Combine($ags2MenuItemPath, ($ags2MenuItemFileName + ".run"))
		$ags2MenuItemTxtFile = [System.IO.Path]::Combine($ags2MenuItemPath, ($ags2MenuItemFileName + ".txt"))
		$ags2MenuItemIffFile = [System.IO.Path]::Combine($ags2MenuItemPath, ($ags2MenuItemFileName + ".iff"))


		# build ags2 menu item start text	
		$ags2MenuItemStartTextParameters = @{ "MenuItemFileName" = $ags2MenuItemFileName; "MenuItemIndexName" = $ags2MenuItemIndexName; "RunDir" = $whdloadSlaveStartPath; "RunFileName" = $whdloadSlaveFileName; "RunFile" = ($whdloadSlaveStartPath + $whdloadSlaveFileName) }
		$ags2MenuItemStartText = BuildTemplateText $ags2MenuItemRunTemplateFile $ags2MenuItemStartTextParameters
		
		# write ags2 menu item start file	
		WriteAmigaTextString $ags2MenuItemRunFile $ags2MenuItemStartText


		# build ags2 menu item detail text
		$ags2MenuItemDetailText = BuildMenuItemDetailText $whdloadSlave
		
		# write ags2 menu item txt file
		WriteAmigaTextString $ags2MenuItemTxtFile $ags2MenuItemDetailText


		# add ags2 name and filename to data lines
		$hstwbMenuItemDataLines += "AGS2Name=$ags2MenuItemFileName"
	}


	if ($ams)
	{
		# build ams name
		$amsName = Capitalize (BuildName $amsNameFormat $whdloadSlave)

		# add whdload slave to ams whdload list
		if ($amsWhdloadListLines.Count -eq 0)
		{
			$amsWhdloadListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $whdloadListColumnsPadding + "}   {2}") -f "Assign", "Whdload", "AMS")
		}
		$amsWhdloadListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $whdloadListColumnsPadding + "}   {2}") -f ($assignPath + ":"), $whdloadSlave.WhdloadName, $amsName)


		# build ams menu item file name
		$amsMenuItemFileName = BuildMenuItemFileName $amsName $amsMenuItemFileNameIndex


		$amsMenuDir = [System.IO.Path]::Combine($amsOutputPath, "menu")
		$amsMenuItemIndexName = GetIndexName $amsMenuItemFileName
		$amsMenuItemPath = [System.IO.Path]::Combine($amsMenuDir, $amsMenuItemIndexName)


		# write menu item index start file, if it doesn't exist
		$amsMenuItemIndexStartFile = [System.IO.Path]::Combine($amsMenuDir, ($amsMenuItemIndexName + ".start"))

		if(!(Test-Path -Path $amsMenuItemIndexStartFile))
		{
			$amsMenuItemIndexStartText = BuildMenuItemChangeDirectoryText ("AMS:" + $amsMenuItemIndexName)
			WriteAmigaTextString $amsMenuItemIndexStartFile $amsMenuItemIndexStartText
		}


		# create menu item path, if it doesn't exist
		if(!(Test-Path -Path $amsMenuItemPath))
		{
			md $amsMenuItemPath | Out-Null
		}


		# write menu item back start file, if it doesn't exist
		$amsMenuItemBackStartFile = [System.IO.Path]::Combine($amsMenuItemPath, "...start")

		if(!(Test-Path -Path $amsMenuItemBackStartFile))
		{
			$amsMenuItemBackStartText = BuildMenuItemChangeDirectoryText "AMS:"
			WriteAmigaTextString $amsMenuItemBackStartFile $amsMenuItemBackStartText
		}


		# set ams menu files
		$amsMenuItemStartFile = [System.IO.Path]::Combine($amsMenuItemPath, ($amsMenuItemFileName + ".start"))
		$amsMenuItemTxtFile = [System.IO.Path]::Combine($amsMenuItemPath, ($amsMenuItemFileName + ".txt"))
		$amsMenuItemIffFile = [System.IO.Path]::Combine($amsMenuItemPath, ($amsMenuItemFileName + ".iff"))

		
		# build ams menu item start	text
		$amsMenuItemStartTextParameters = @{ "MenuItemFileName" = $amsMenuItemFileName; "MenuItemIndexName" = $amsMenuItemIndexName; "RunDir" = $whdloadSlaveStartPath; "RunFileName" = $whdloadSlaveFileName; "RunFile" = ($whdloadSlaveStartPath + $whdloadSlaveFileName) }
		$amsMenuItemStartText = BuildTemplateText $amsMenuItemRunTemplateFile $amsMenuItemStartTextParameters
		
		# write ams menu item start file
		WriteAmigaTextString $amsMenuItemStartFile $amsMenuItemStartText

		
		# build ams menu item detail text
		$amsMenuItemDetailText = BuildMenuItemDetailText $whdloadSlave
		
		# write ams menu item txt file
		WriteAmigaTextString $amsMenuItemTxtFile $amsMenuItemDetailText


		# add ams name and filename to data lines
		$hstwbMenuItemDataLines += "AMSName=$amsMenuItemFileName"
	}


	# build igame menu for whdload slave
	if ($iGame)
	{
		# build igame name
		$iGameName = BuildName $iGameNameFormat $whdloadSlave

		$iGameMenuItemName = Capitalize $iGameName


		# add igame name to data lines
		$hstwbMenuItemDataLines += "iGameName=$iGameMenuItemName"


		# add whdload slave to igame whdload list
		if ($iGameWhdloadListLines.Count -eq 0)
		{
			$iGameWhdloadListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $whdloadListColumnsPadding + "}   {2}") -f "Assign", "Whdload", "iGame")
		}
		$iGameWhdloadListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $whdloadListColumnsPadding + "}   {2}") -f ($assignPath + ":"), $whdloadSlave.WhdloadName, $iGameMenuItemName)

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


	$whdloadAssignDir = [System.IO.Path]::Combine($whdloadOutputPath, $assignPath)
	$whdloadSlaveDir = [System.IO.Path]::Combine($whdloadAssignDir, [System.IO.Path]::GetDirectoryName($whdloadSlave.WhdloadSlaveFilePath).Replace("/", "\"))

	if(!(Test-Path -Path $whdloadSlaveDir))
	{
		md $whdloadSlaveDir | Out-Null
	}

	# build hstwb menuitem run	text	
	$whdloadRunTemplateParameters = @{ "WhdloadSlaveStartPath" = $whdloadSlaveStartPath; "WhdloadSlaveFileName" = $whdloadSlaveFileName }
	$whdloadRunTemplateText = BuildTemplateText $whdloadRunTemplateFile $whdloadRunTemplateParameters

	if ($hstwbMenuItemFileNameIndex.ContainsKey($whdloadSlaveDir))
	{
		$hstwbMenuItemFileNameCount = $hstwbMenuItemFileNameIndex.Get_Item($whdloadSlaveDir)
		$hstwbMenuItemFileNameCount++
	}
	else
	{
		$hstwbMenuItemFileNameCount = 1
	}

	$hstwbMenuItemFileNameIndex.Set_Item($whdloadSlaveDir, $hstwbMenuItemFileNameCount)

	$hstwbMenuItemFileName = "hstwbmenuitem{0}" -f $hstwbMenuItemFileNameCount

	# write hstwb menuitem run file
	$hstwbMenuItemRunFile = [System.IO.Path]::Combine($whdloadSlaveDir, ("{0}.run" -f $hstwbMenuItemFileName))
	WriteAmigaTextString $hstwbMenuItemRunFile $whdloadRunTemplateText

	# write hstwb menuitem data file
	$hstwbMenuItemDataFile = [System.IO.Path]::Combine($whdloadSlaveDir, ("{0}.data" -f $hstwbMenuItemFileName))
	WriteAmigaTextLines $hstwbMenuItemDataFile $hstwbMenuItemDataLines


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

		# copy ams screenshot for whdload slave
		if ($ams)
		{
			$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "ams.iff")
			
			# copy whdload screenshot file, if it exists
			if (test-path -path $whdloadScreenshotFile)
			{
				Copy-Item $whdloadScreenshotFile $amsMenuItemIffFile -force
			}
		}

		# copy igame screenshot for whdload slave
		if ($iGame)
		{
			$whdloadScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotPath, "igame.iff")
			
			# copy whdload screenshot file, if it exists
			if (test-path -path $whdloadScreenshotFile)
			{
				Copy-Item $whdloadScreenshotFile $whdloadSlaveDir -force
			}

			$whdloadiGameScreenshotFile = $whdloadSlaveStartPath + "igame.iff"

			# add igame path checks to validate paths script
			$validatePathsPartScriptLines += @( 
					("IF NOT EXISTS """ + $whdloadiGameScreenshotFile + """"), 
					("  ECHO ""ERROR: Path '" + $whdloadiGameScreenshotFile +  "' doesn't exist!"""), 
					"ENDIF") 
		}
	}
	else {
		Write-Host ("No screenshot for " + $whdloadSlave.WhdloadSlaveFilePath)
	}

	# write validate paths part script, if it has more than 2000 lines
	if ($validatePathsPartScriptLines.Count -gt 2000)
	{
		# write validate paths part script file
		$validatePathsPartScriptFile = [System.IO.Path]::Combine($outputPath, ("validate_paths_part" + $validatePathsPartScript))
		WriteAmigaTextLines $validatePathsPartScriptFile $validatePathsPartScriptLines

		$validatePathsPartScript++
		$validatePathsPartScriptLines = @()
	}
}

# write validate paths part script file
$validatePathsPartScriptFile = [System.IO.Path]::Combine($outputPath, ("validate_paths_part" + $validatePathsPartScript))
WriteAmigaTextLines $validatePathsPartScriptFile $validatePathsPartScriptLines

$validatePathsScriptLines = @()

for ($i = 1; $i -le $validatePathsPartScript; $i++)
{
	$validatePathsScriptLines += ("execute " + "validate_paths_part" + $i)
}

# write validate paths script file
$validatePathsScriptFile = [System.IO.Path]::Combine($outputPath, "validate_paths")
WriteAmigaTextLines $validatePathsScriptFile $validatePathsScriptLines

# write whdload slaves file
$whdloadSlavesFile = [System.IO.Path]::Combine($outputPath, "whdload_slaves.csv")
$whdloadSlaves | export-csv -delimiter ';' -path $whdloadSlavesFile -NoTypeInformation -Encoding UTF8

if ($ags2)
{
	# write ags2 whdload list file 
	$ags2WhdloadListFile = [System.IO.Path]::Combine($ags2OutputPath, "AGS2 WHDLoad List")
	WriteAmigaTextLines $ags2WhdloadListFile $ags2WhdloadListLines
}

if ($ams)
{
	# write ams whdload list file 
	$amsWhdloadListFile = [System.IO.Path]::Combine($amsOutputPath, "AMS WHDLoad List")
	WriteAmigaTextLines $amsWhdloadListFile $amsWhdloadListLines
}

if ($iGame)
{
	# write igame whdload list file 
	$iGameWhdloadListFile = [System.IO.Path]::Combine($iGameOutputPath, "iGame WHDLoad List")
	WriteAmigaTextLines $iGameWhdloadListFile $iGameWhdloadListLines
	
	# write igame gameslist file
	$iGameGamesListFile = [System.IO.Path]::Combine($iGameOutputPath, "gameslist.")
	WriteAmigaTextLines $iGameGamesListFile $iGameGamesListLines

	# write igame repos file
	$iGameReposFile = [System.IO.Path]::Combine($iGameOutputPath, "repos.")
	WriteAmigaTextLines $iGameReposFile $iGameReposLines
}
