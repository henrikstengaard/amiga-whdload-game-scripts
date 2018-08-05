# Build Menu
# ----------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2018-08-05
#
# A PowerShell script to build AGS2, AMS and iGame menus. 
# Whdload slave details file is used for building AGS2 and AMS menu item text per whdload slave and whdload screenshots file can optionally be used to add screenshots for each whdload slave.


Param(
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$false)]
	[string]$entriesFiles,
	[Parameter(Mandatory=$false)]
	[string]$sourcesFile,
	[Parameter(Mandatory=$false)]
	[string]$assignName,
	[Parameter(Mandatory=$false)]
	[string]$detailColumns,
	[Parameter(Mandatory=$false)]
	[string]$ags2NameFormat,
	[Parameter(Mandatory=$false)]
	[string]$iGameNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$amsNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$hstLauncherNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$hstwbNameFormat,
	[Parameter(Mandatory=$false)]
	[string]$ags2RunTemplateFile,
	[Parameter(Mandatory=$false)]
	[string]$hstLauncherRunTemplateFile,
	[Parameter(Mandatory=$false)]
	[string]$amsMenuItemRunTemplateFile,
	[Parameter(Mandatory=$false)]
	[string]$detailsFiles,
	[Parameter(Mandatory=$false)]
	[string]$screenshotsFiles,
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
	[switch]$ams,
	[Parameter(Mandatory=$false)]
	[switch]$hstLauncher,
	[Parameter(Mandatory=$false)]
	[switch]$noDataIndex,
	[Parameter(Mandatory=$false)]
	[string]$menuTitle
)

# exit, if neither entries files or sources file is defined
if (!$entriesFiles -and !$sourcesFile)
{
	Write-Error "Entries files or sources file is not defined"
	exit 1
}

# exit, if entries files is used and assign name is not defined
if ($entriesFiles -and !$assignName)
{
	Write-Error "Assign name is not defined"
	exit 1
}

# exit, if ags2 is enabled and ags2 name format is not defined
if ($ags2 -and !$ags2NameFormat)
{
	Write-Error "AGS2 name format is not defined for AGS2 menu"
	exit 1
}


# exit, if ags2 is enabled and ags2 menu item file template file not defined
if ($ags2 -and !$ags2RunTemplateFile)
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


# paths
$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)

if ($ags2RunTemplateFile)
{
	$ags2RunTemplateFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ags2RunTemplateFile)
}

if ($hstLauncherRunTemplateFile)
{
	$hstLauncherRunTemplateFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($hstLauncherRunTemplateFile)
}

if ($amsMenuItemRunTemplateFile)
{
	$amsMenuItemRunTemplateFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($amsMenuItemRunTemplateFile)
}

$runWhdloadTemplateFile = Join-Path -Path $scriptDir -ChildPath "run_whdload_template.txt"
$runScriptTemplateFile = Join-Path -Path $scriptDir -ChildPath "run_script_template.txt"
$runFileTemplateFile = Join-Path -Path $scriptDir -ChildPath "run_file_template.txt"

$maxMenuItemFileNameLength = 26

# detail columns
$detailColumnsList = @( "RunFile" )
$detailColumnsList +=, $detailColumns -split ','
$detailColumnsPadding = ($detailColumnsList | sort @{expression={$_.Length};Ascending=$false} | Select-Object -First 1).Length


# get index name from first character in name
function GetIndexName($name)
{
	if (($name -replace '^[^a-z0-9]+', '') -match '^[0-9]')
	{
		$indexName = "0-9"
	}
	else
	{
		$indexName = $name.Substring(0,1)
	}

	return $indexName.ToUpper()
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

function BuildName($nameFormat, $entry)
{
	$name = $nameFormat

	$nameFormatProperties = $entry.psobject.Properties | where { $nameFormat -match $_.Name }

	if ($nameFormatProperties.Count -gt 0)
	{
		foreach ($property in $nameFormatProperties)
		{
			$name = $name.Replace('[$' + $property.Name + ']', (Capitalize $property.Value))
		}
	}
	else
	{
		$name = $entry.EntryName	
	}

	$name = $name -replace '\s*\[[^\[\]]*\]', ''

	$entryName = (Split-Path $entry.RunFile -Leaf) -replace '\.slave$'

	if ($entry.RunType -match 'whdload' -and $entry.EntryName -ne $entryName)
	{
		$extra = $entryName.Replace($entry.EntryName, '')

		if ($entry.FilteredHardware)
		{
			$entryNameWithoutHardware = $entry.EntryName.Replace($entry.FilteredHardware, '')
			$extra = $extra.Replace($entryNameWithoutHardware, '')
		}

		if ($entry.DetailName)
		{
			$extra = $extra.Replace($entry.DetailName, '')
		}

		if ($entry.FilteredName)
		{
			$extra = $extra.Replace($entry.FilteredName, '')
		}

		if ($entry.FilteredHardware)
		{
			$extra = $extra.Replace($entry.FilteredHardware, '')
		}

		if ($entry.FilteredCompilation)
		{
			$extra = $extra.Replace(($entry.FilteredCompilation -replace '^[&_]', '' -replace '[&_]$', ''), '')
		}

		if ($entry.FilteredLanguage)
		{
			$extra = $extra.Replace($entry.FilteredLanguage, '')
		}

		if ($entry.FilteredHardware)
		{
			$extra = $extra.Replace($entry.FilteredHardware, '')
		}

		if ($entry.FilteredMemory)
		{
			$extra = $extra.Replace($entry.FilteredMemory, '')
		}

		if ($entry.FilteredDemo)
		{
			$extra = $extra.Replace($entry.FilteredDemo, '')
		}

		if ($entry.FilteredOther)
		{
			$extra = $extra.Replace($entry.FilteredOther, '')
		}

		$extra = $extra -replace '^[&_]', '' -replace '[&_]$', ''

		if ($extra.Length -gt 0)
		{
			$name += ' ' + $extra
		}
	}

	if ($entry.FilteredCompilation -and !$name.Contains($entry.FilteredCompilation))
	{
		$name += ' ' + ($entry.FilteredCompilation -replace '^[&_]', '' -replace '[&_]$', '' -replace ',', ' ')
	}

	if ($entry.FilteredLanguage)
	{
		$name += ' ' + ($entry.FilteredLanguage.ToUpper() -replace ',', ' ')
	}

	if ($entry.FilteredHardware -and $entry.FilteredHardware -notmatch '(ocs|ecs)')
	{
		$name += ' ' + ($entry.FilteredHardware.ToUpper() -replace ',', ' ')
	}

	if ($entry.FilteredMemory)
	{
		$name += ' ' + ($entry.FilteredMemory.ToUpper() -replace ',', ' ')
	}

	if ($entry.FilteredDemo)
	{
		$name += ' ' + ($entry.FilteredDemo -replace ',', ' ')
	}

	if ($entry.FilteredOther)
	{
		$name += ' ' + ($entry.FilteredOther -replace '^[&_]', '' -replace '[&_]$', '' -replace ',', ' ')
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

function BuildMenuItemDetailText($entry)
{
	# build menu item text lines
	$menuItemDetailTextLines = @()

	$detailColumnsIndex = @{}

	if ($entry.DetailMatch -and $entry.DetailMatch -ne '')
	{
		foreach ($property in ($entry.psobject.Properties | Where { $_.Name -match '^Detail' -and $_.Value } ))
		{
			$detailColumnsIndex.Set_Item(($property.Name -replace '^Detail', ''), (Capitalize $property.Value))
		}
	}
	else
	{
		Write-Host ("Warning: No details for whdload name '" + $entry.EntryName + "', query '" + $entry.Query + "'")

		$detailColumnsIndex.Set_Item("Name", (Capitalize $entry.EntryName.Replace("CD??", "CD32")))
	}

	if ($entry.FilteredLanguage)
	{
		switch ($entry.FilteredLanguage.ToLower())
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

	if ($entry.FilteredCompilation)
	{
		$version += $entry.FilteredCompilation -replace '&', '' -replace ',', ' '
	}
	
	if ($entry.FilteredHardware -and $entry.FilteredHardware -notmatch '(ocs|ecs)')
	{
		$version += $entry.FilteredHardware.ToUpper() -replace ',', ' '
	}

	if ($entry.FilteredMemory)
	{
		$version += $entry.FilteredMemory.ToUpper() -replace ',', ' '
	}

	if ($entry.FilteredDemo)
	{
		$version += $entry.FilteredDemo -replace ',', ' '
	}

	if ($entry.FilteredOther)
	{
		$version += $entry.FilteredOther -replace ',', ' '
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

	$menuItemDetailTextLines += (("{0,-" + $detailColumnsPadding + "} : {1}") -f "RunFile", [System.IO.Path]::GetFileName($entry.RunFile))
	
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


# make data output directory
$dataOutputPath = [System.IO.Path]::Combine($outputPath, "data")
if(!(Test-Path -Path $dataOutputPath))
{
	md $dataOutputPath | Out-Null
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
$iGameOutputPath = Join-Path $outputPath -ChildPath 'igame'
$iGame320x128OutputDir = Join-Path $iGameOutputPath -ChildPath '320x128'
$iGame320x256OutputDir = Join-Path $iGameOutputPath -ChildPath '320x256'
if ($igame)
{
	if(!(Test-Path -Path $iGameOutputPath))
	{
		mkdir $iGameOutputPath | Out-Null
	}

	if(!(Test-Path -Path $iGame320x128OutputDir))
	{
		mkdir $iGame320x128OutputDir | Out-Null
	}

	if(!(Test-Path -Path $iGame320x256OutputDir))
	{
		mkdir $iGame320x256OutputDir | Out-Null
	}
}


# make hst launcher output directory
if ($hstLauncher)
{
	$hstLauncherOutputPath = [System.IO.Path]::Combine($outputPath, "hstlauncher")
	if(!(Test-Path -Path $hstLauncherOutputPath))
	{
		md $hstLauncherOutputPath | Out-Null
	}
}


# read entries files
$entries = @()

if ($sourcesFile)
{
	$sourcesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($sourcesFile)

	$sources = @()
	Write-Host ("Reading sources file '{0}'" -f $sourcesFile)
	$sources += import-csv -delimiter ';' -path $sourcesFile -encoding utf8 

	foreach($source in $sources)
	{
		$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($source.EntriesFile)
		Write-Host ("Reading entries file '{0}'" -f $entriesFile)
		$sourceEntries = @()
		$sourceEntries += import-csv -delimiter ';' -path $entriesFile -encoding utf8

		$sourceEntries | Foreach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value $source.AssignName -Force }
		$entries += $sourceEntries
	}
}
else
{
	foreach($entriesFile in ($entriesFiles -Split ','))
	{
		$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
		Write-Host ("Reading entries file '{0}'" -f $entriesFile)
		$entries += import-csv -delimiter ';' -path $entriesFile -encoding utf8 
	}

	$entries | Foreach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value $assignName -Force }
}


# read whdload screenshots files
$whdloadScreenshotsIndex = @{}

foreach($screenshotsFile in ($screenshotsFiles -Split ','))
{
	$screenshotsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($screenshotsFile)
	Write-Host ("Reading screenshots file '{0}'" -f $screenshotsFile)
	$whdloadScreenshots = @()
	$whdloadScreenshots += import-csv -delimiter ';' -path $screenshotsFile -encoding utf8 

	$whdloadScreenshotsDir = [System.IO.Path]::GetDirectoryName($screenshotsFile)

	foreach($whdloadScreenshot in $whdloadScreenshots)
	{
		if ($whdloadScreenshotsIndex.ContainsKey($whdloadScreenshot.RunFile))
		{
			continue;
		}
	
		$whdloadScreenshotsIndex.Set_Item($whdloadScreenshot.RunFile, (Join-Path $whdloadScreenshotsDir -ChildPath $whdloadScreenshot.ScreenshotDirectoryName))
	}
}


# read details files
$detailsIndex = @{}
foreach($detailsFile in ($detailsFiles -Split ','))
{
	$detailsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($detailsFile)
	Write-Host ("Reading details file '{0}'" -f $detailsFile)
	$detailsEntries = @()
	$detailsEntries += import-csv -delimiter ';' -path $detailsFile -encoding utf8 

	foreach($detailsEntry in $detailsEntries)
	{
		if ($detailsIndex.ContainsKey($detailsEntry.RunFile.ToLower()))
		{
			continue;
		}
	
		$detailsIndex.Set_Item($detailsEntry.RunFile.ToLower(), $detailsEntry)
	}
}


# partition and whdload size variables
$partitionNumber = 1
$partitionSize = 0
$whdloadSizeIndex = @{}

# ags2 variables 
$ags2MenuItemFileNameIndex = @{}

# igame variables
$iGameGamesListLines = @()
$iGameReposIndex = @{}

# ams variables 
$amsMenuItemFileNameIndex = @{}

# hstwb variables
$hstwbMenuItemFileNameIndex = @{}
$hstLauncherFileNameIndex = @{}


# other output variables
$validatePathsPartScript = 1
$validatePathsPartScriptLines = @()
$ags2ListLines = @()
$iGameListLines = @()
$amsListLines = @()
$hstLauncherListLines = @()
$entryColumnPadding = ($entries | Sort-Object @{expression={$_.EntryName.Length};Ascending=$false} | Select-Object -First 1).EntryName.Length
$runFileColumnPadding = ($entries | ForEach-Object { Split-Path $_.RunFile -Leaf } | Sort-Object @{expression={$_.Length};Ascending=$false} | Select-Object -First 1).Length

$hstLauncherMenuIndex = @{}

$detailsNotFoundCount = 0
$screenshotsNotFoundCount = 0

$ags2CsvList = New-Object System.Collections.Generic.List[System.Object]

$hstLauncherEntriesLines = New-Object System.Collections.Generic.List[System.Object]


# build menu from whdload slaves
foreach($entry in ($entries | Sort-Object @{expression={$_.EntryName};Ascending=$true}))
{
	# increase partition number, if using partitions and whdload size if larger than partition split size	
	if ($usePartitions)
	{
		if (!$whdloadSizeIndex.ContainsKey($entry.EntryName))
		{
			# add whdload size to index
			$whdloadSizeIndex.Set_Item($entry.EntryName, $entry.WhdloadSize)

			# increase partition number, if whdload size and partition size is greater than partition split size
			if (($partitionSize + $entry.WhdloadSize) -gt $partitionSplitSize)
			{
				$partitionNumber++
				$partitionSize = 0
			}

			# add whdload slave size to partition size
			$partitionSize += $entry.WhdloadSize
		}

		# set assign path with partition number
		$assignPath = $entry.AssignName + $partitionNumber

		# update assign name with partition number
		$entry | Add-Member -MemberType NoteProperty -Name 'AssignName' -Value ($entry.AssignName + $partitionNumber) -Force
	}
	else 
	{
		# set assign path
		$assignPath = $entry.AssignName
	}

	if (!$iGameReposIndex.ContainsKey($assignPath))
	{
		$iGameReposIndex.Set_Item($assignPath, $true)
	}

	# set rundir, replace blackslash with slash and add index name, if it doesn't exist
	$runDir = [System.IO.Path]::GetDirectoryName($entry.RunFile).Replace("\", "/")
	if (!$noDataIndex -and $runDir -notmatch '^(0\-9|[a-z])/')
	{
		$indexName = GetIndexName $runDir
		$runDir = "{0}/{1}" -f $indexName, $runDir
	}

	# set whdload slave start path and replace backslash with slash
	$entryRunDir = ($assignPath + ":" + $runDir)

	# add tailing slash, if not present
	if ($entryRunDir -notmatch '/$')
	{
		$entryRunDir += "/"
	}

	# set whdload slave file name
	$entryFileName = [System.IO.Path]::GetFileName($entry.RunFile)

	# add whdload slave path checks to validate paths script 
	$validatePathsPartScriptLines += @( 
			("IF NOT EXISTS """ + $entryRunDir + """"), 
			("  ECHO ""ERROR: Path '" + $entryRunDir + "' doesn't exist!"""), 
			"ENDIF", 
			("IF NOT EXISTS """ + $entryRunDir + $entryFileName + """"), 
			("  ECHO ""ERROR: Path '" + $entryRunDir + $entryFileName + "' doesn't exist!"""), 
			"ENDIF") 

	if ($detailsIndex.ContainsKey($entry.RunFile.ToLower()))
	{
		$detailsEntry = $detailsIndex.Get_Item($entry.RunFile.ToLower())
	}
	else
	{
		$detailsNotFoundCount++
		$detailsEntry = $entry
		Write-Host ("No detail for " + $entry.RunFile)
	}

    # build hstwb menuitem data files
	$hstwbMenuItemDataLines = @(";HstWB menu item data")
	$hstwbMenuItemDataLines += ("Name=" + (Capitalize (BuildName $hstwbNameFormat $detailsEntry)))
	$hstwbMenuItemDataLines += "RunFile=$entryFileName"


	$runTemplateFile = ''
	
	if ($entry.RunType -match 'whdload')
	{
		$runTemplateFile = $runWhdloadTemplateFile
	}
	elseif ($entry.RunType -match 'runscript')
	{
		$runTemplateFile = $runScriptTemplateFile
	}
	elseif ($entry.RunType -match 'file')
	{
		$runTemplateFile = $runFileTemplateFile
	}
	else
	{
		throw ("Entry '{0}' with run type '{1}' is unsupported!" -f $entry.EntryName, $entry.RunType)
	}

	$runTemplateParameters = @{ "EntryRunDir" = $entryRunDir; "EntryFileName" = $entryFileName }
	$runTemplateText = BuildTemplateText $runTemplateFile $runTemplateParameters
	

	# build ags2 menu for whdload slave
	if ($ags2)
	{
		# build ags2 name
		$ags2Name = Capitalize (BuildName $ags2NameFormat $detailsEntry)

		# build ags2 menu item file name
		$ags2MenuItemFileName = BuildMenuItemFileName $ags2Name $ags2MenuItemFileNameIndex
		
		# add whdload slave to ags2 whdload list
		if ($ags2ListLines.Count -eq 0)
		{
			$ags2ListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3,-26}   {4}") -f "Assign", "Entry", "RunFile", "AGS2", "Name")
		}
		$ags2ListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3,-26}   {4}") -f ($assignPath + ":"), $entry.EntryName, $entryFileName, $ags2MenuItemFileName, $ags2Name)

		$ags2MenuDir = [System.IO.Path]::Combine($ags2OutputPath, "menu")
		$ags2MenuItemIndexName = GetIndexName $ags2MenuItemFileName
		$ags2MenuItemPath = [System.IO.Path]::Combine($ags2MenuDir, $ags2MenuItemIndexName + ".ags")

		if(!(Test-Path -Path $ags2MenuItemPath))
		{
			md $ags2MenuItemPath | Out-Null
		}

		$ags2CsvList.add(@{ "EntryName" = $entry.EntryName; "RunFile" = $entry.RunFile; "RunDir" = $entry.RunDir; "AGS2MenuItemFileName" = (Join-Path ("{0}.ags" -f $ags2MenuItemIndexName) -ChildPath $ags2MenuItemFileName) })

		# set ags2 menu files
		$ags2MenuItemRunFile = [System.IO.Path]::Combine($ags2MenuItemPath, ($ags2MenuItemFileName + ".run"))
		$ags2MenuItemTxtFile = [System.IO.Path]::Combine($ags2MenuItemPath, ($ags2MenuItemFileName + ".txt"))
		$ags2MenuItemIffFile = [System.IO.Path]::Combine($ags2MenuItemPath, ($ags2MenuItemFileName + ".iff"))


		# build ags2 menu item start text	
		$ags2MenuItemStartTextParameters = @{ "MenuItemFileName" = $ags2MenuItemFileName; "MenuItemIndexName" = $ags2MenuItemIndexName; "RunTemplate" = $runTemplateText; "RunFile" = ($entryRunDir + $entryFileName) }
		$ags2MenuItemStartText = BuildTemplateText $ags2RunTemplateFile $ags2MenuItemStartTextParameters
		
		# write ags2 menu item start file	
		WriteAmigaTextString $ags2MenuItemRunFile $ags2MenuItemStartText


		# build ags2 menu item detail text
		if ($detailsEntry)
		{
			$ags2MenuItemDetailText = BuildMenuItemDetailText $detailsEntry
		}
		else
		{
			$ags2MenuItemDetailText = ''
		}
		
		# write ags2 menu item txt file
		WriteAmigaTextString $ags2MenuItemTxtFile $ags2MenuItemDetailText


		# add ags2 name and filename to data lines
		$hstwbMenuItemDataLines += "AGS2Name=$ags2MenuItemFileName"
	}


	if ($ams)
	{
		# build ams name
		$amsName = Capitalize (BuildName $amsNameFormat $detailsEntry)

		# add whdload slave to ams whdload list
		if ($amsListLines.Count -eq 0)
		{
			$amsListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3}") -f "Assign", "Entry", "RunFile", "AMS")
		}
		$amsListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3}") -f ($assignPath + ":"), $entry.EntryName, $entryFileName, $amsName)


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
		$amsMenuItemStartTextParameters = @{ "MenuItemFileName" = $amsMenuItemFileName; "MenuItemIndexName" = $amsMenuItemIndexName; "RunDir" = $entryRunDir; "RunFileName" = $entryFileName; "RunFile" = ($entryRunDir + $entryFileName) }
		$amsMenuItemStartText = BuildTemplateText $amsMenuItemRunTemplateFile $amsMenuItemStartTextParameters
		
		# write ams menu item start file
		WriteAmigaTextString $amsMenuItemStartFile $amsMenuItemStartText

		
		# build ams menu item detail text
		if ($detailsEntry)
		{
			$amsMenuItemDetailText = BuildMenuItemDetailText $detailsEntry
		}
		else
		{
			$amsMenuItemDetailText = ''
		}
		
		# write ams menu item txt file
		WriteAmigaTextString $amsMenuItemTxtFile $amsMenuItemDetailText
		
		# add ams name and filename to data lines
		$hstwbMenuItemDataLines += "AMSName=$amsMenuItemFileName"
	}


	# build igame menu for whdload slave
	if ($iGame -and $entry.RunType -match '(whdload|file)')
	{
		# build igame name
		$iGameName = BuildName $iGameNameFormat $detailsEntry

		$iGameMenuItemName = Capitalize $iGameName


		# add igame name to data lines
		$hstwbMenuItemDataLines += "iGameName=$iGameMenuItemName"


		# add whdload slave to igame whdload list
		if ($iGameListLines.Count -eq 0)
		{
			$iGameListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3}") -f "Assign", "Entry", "RunFile", "iGame")
		}
		$iGameListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3}") -f ($assignPath + ":"), $entry.EntryName, $entryFileName, $iGameMenuItemName)

		# build igame game gameslist lines
		$iGameGameLines = @(
			"index=0",
			("title=" + $iGameMenuItemName),
			"genre=Unknown",
			("path=" + $entryRunDir + $entryFileName),
			"favorite=0",
			"timesplayed=0",
			"lastplayed=0",
			"hidden=0",
			"")

		# add game to igame gameslist lines
		$iGameGamesListLines += $iGameGameLines
	}

	if ($hstLauncher)
	{
		$hstLauncherName = Capitalize (BuildName $hstLauncherNameFormat $detailsEntry)

		if ($hstLauncherListLines.Count -eq 0)
		{
			$hstLauncherListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3}") -f "Assign", "Entry", "RunFile", "HST Launcher")
		}
		$hstLauncherListLines += (("{0,-" + ($assignPath.Length + 1) + "}   {1,-" + $entryColumnPadding + "}   {2,-" + $runFileColumnPadding + "}   {3}") -f ($assignPath + ":"), $entry.EntryName, $entryFileName, $hstLauncherName)
		
		$indexName = GetIndexName $hstLauncherName

		$hstLauncherMenuDir = Join-Path $hstLauncherOutputPath -ChildPath "menu"
		$hstLauncherMenuIndexDir = Join-Path $hstLauncherMenuDir -ChildPath $indexName

		if(!(Test-Path -Path $hstLauncherMenuIndexDir))
		{
			mkdir $hstLauncherMenuIndexDir | Out-Null
		}

		# build hst launcher file name
		$hstLauncherFileName = BuildMenuItemFileName $hstLauncherName $hstLauncherFileNameIndex
		
		# build hst launcher run text
		$entryRunFile = $entryRunDir + $entryFileName
		$hstLauncherRunTextParameters = @{ 
			"RunTemplate" = $runTemplateText;
			"RunFile" = $entryRunFile
		}
		$hstLauncherRunText = BuildTemplateText $hstLauncherRunTemplateFile $hstLauncherRunTextParameters
		
		# write hst launcher run file
		$hstLauncherRunFile = Join-Path $hstLauncherMenuIndexDir -ChildPath ("{0}.run" -f $hstLauncherFileName)
		WriteAmigaTextString $hstLauncherRunFile $hstLauncherRunText

		$hstLauncherMenuFile = "{0}/{1}" -f $indexName, $hstLauncherFileName
		$hstLauncherEntryLine = @($hstLauncherName, $hstLauncherMenuFile, $entryRunFile) -join "`t"

		$hstLauncherEntriesLines.Add($hstLauncherEntryLine)
		
		if ($hstLauncherMenuIndex.ContainsKey($indexName))
		{
			$menuIndexLines = $hstLauncherMenuIndex.Get_Item($indexName)
		}
		else
		{
			$menuIndexLines = New-Object System.Collections.Generic.List[System.Object]
			$hstLauncherMenuIndex.Set_Item($indexName, $menuIndexLines)
		}

		$menuIndexLines.Add($hstLauncherEntryLine)
	}

	$entryDir = $runDir.Replace("/", "\")


	# build data content
	$dataAssignDir = Join-Path $dataOutputPath -ChildPath $assignPath
	$dataAssignEntryDir = Join-Path $dataAssignDir -ChildPath $entryDir

	if(!(Test-Path -Path $dataAssignEntryDir))
	{
		mkdir $dataAssignEntryDir | Out-Null
	}
	
	if ($hstwbMenuItemFileNameIndex.ContainsKey($dataAssignEntryDir))
	{
		$hstwbMenuItemFileNameCount = $hstwbMenuItemFileNameIndex.Get_Item($dataAssignEntryDir)
		$hstwbMenuItemFileNameCount++
	}
	else
	{
		$hstwbMenuItemFileNameCount = 1
	}

	$hstwbMenuItemFileNameIndex.Set_Item($dataAssignEntryDir, $hstwbMenuItemFileNameCount)

	$hstwbMenuItemFileName = "hstwbmenuitem{0}" -f $hstwbMenuItemFileNameCount

	# write hstwb menuitem run file
	$hstwbMenuItemRunFile = Join-Path $dataAssignEntryDir -ChildPath ("{0}.run" -f $hstwbMenuItemFileName)
	WriteAmigaTextString $hstwbMenuItemRunFile $runTemplateText

	# write hstwb menuitem data file
	$hstwbMenuItemDataFile = Join-Path $dataAssignEntryDir -ChildPath ("{0}.data" -f $hstwbMenuItemFileName)
	WriteAmigaTextLines $hstwbMenuItemDataFile $hstwbMenuItemDataLines


	# use whdload screenshot, if it exists in index	
	if ($whdloadScreenshotsIndex.ContainsKey($entry.RunFile.ToLower()))
	{
		$whdloadScreenshotDir = $whdloadScreenshotsIndex.Get_Item($entry.RunFile.ToLower())
		
		# copy ags2 screenshot for whdload slave
		if ($ags2)
		{
			if ($aga)
			{
				$ags2ScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotDir, "ags2aga.iff")
			}
			else
			{
				$ags2ScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotDir, "ags2ocs.iff")
			}
		
			# copy ags2 screenshot file, if it exists
			if (test-path -path $ags2ScreenshotFile)
			{
				Copy-Item $ags2ScreenshotFile $ags2MenuItemIffFile -force
			}
		}

		# copy ams screenshot for whdload slave
		if ($ams)
		{
			$amsScreenshotFile = [System.IO.Path]::Combine($whdloadScreenshotDir, "ams.iff")
			
			# copy ams screenshot file, if it exists
			if (test-path -path $amsScreenshotFile)
			{
				Copy-Item $amsScreenshotFile $amsMenuItemIffFile -force
			}
		}

		# copy igame screenshot for whdload slave
		if ($iGame)
		{
			# copy igame 320x128 screenshot file, if it exists
			$iGame320x128ScreenshotFile = Join-Path $whdloadScreenshotDir -ChildPath 'igame_320x128.iff'
			if (test-path -path $iGame320x128ScreenshotFile)
			{
				$iGame320x128EntryOutputDir = Join-Path $iGame320x128OutputDir -ChildPath $entryDir

				if(!(Test-Path -Path $iGame320x128EntryOutputDir))
				{
					mkdir $iGame320x128EntryOutputDir | Out-Null
				}

				$iGame320x128EntryOutputFile = Join-Path $iGame320x128EntryOutputDir -ChildPath 'igame.iff'
				Copy-Item $iGame320x128ScreenshotFile $iGame320x128EntryOutputFile -force
			}

			# copy igame 320x256 screenshot file, if it exists
			$iGame320x256ScreenshotFile = Join-Path $whdloadScreenshotDir -ChildPath 'igame_320x256.iff'
			if (test-path -path $iGame320x256ScreenshotFile)
			{
				$iGame320x256EntryOutputDir = Join-Path $iGame320x256OutputDir -ChildPath $entryDir

				if(!(Test-Path -Path $iGame320x256EntryOutputDir))
				{
					mkdir $iGame320x256EntryOutputDir | Out-Null
				}
				
				$iGame320x256EntryOutputFile = Join-Path $iGame320x256EntryOutputDir -ChildPath 'igame.iff'
				Copy-Item $iGame320x256ScreenshotFile $iGame320x256EntryOutputFile -force
			}
		}
	}
	else
	{
		$screenshotsNotFoundCount++
		Write-Host ("No screenshot for " + $entry.RunFile)
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

# write entries file
$entriesFile = [System.IO.Path]::Combine($outputPath, "entries.csv")
$entries | export-csv -delimiter ';' -path $entriesFile -NoTypeInformation -Encoding UTF8

if ($ags2)
{
	# write ags2 list file 
	$ags2ListFile = [System.IO.Path]::Combine($ags2OutputPath, "AGS2 List")
	WriteAmigaTextLines $ags2ListFile $ags2ListLines

	# write ags2 csv list file 
	$ags2CsvListFile = Join-Path $ags2OutputPath -ChildPath "AGS2 List.csv"

	# write output file
	$ags2CsvList | ForEach-Object{ New-Object PSObject -Property $_ } | export-csv -delimiter ';' -path $ags2CsvListFile -NoTypeInformation -Encoding UTF8	
}

if ($ams)
{
	# write ams list file 
	$amsListFile = [System.IO.Path]::Combine($amsOutputPath, "AMS List")
	WriteAmigaTextLines $amsListFile $amsListLines
}

if ($iGame)
{
	# write igame list file 
	$iGameListFile = [System.IO.Path]::Combine($iGameOutputPath, "iGame List")
	WriteAmigaTextLines $iGameListFile $iGameListLines
	
	# write igame gameslist file
	$iGameGamesListFile = [System.IO.Path]::Combine($iGameOutputPath, "gameslist.")
	WriteAmigaTextLines $iGameGamesListFile $iGameGamesListLines

	# write igame repos file
	$iGameReposFile = [System.IO.Path]::Combine($iGameOutputPath, "repos.")
	$iGameReposLines = @()
	$iGameReposLines += $iGameReposIndex.Keys | Sort-Object
	WriteAmigaTextLines $iGameReposFile ($iGameReposLines)
}

if ($hstLauncher)
{
	# write main menu list file
	$mainMenuListLines = @()
	$mainMenuListLines += $hstLauncherMenuIndex.Keys | Sort-Object | ForEach-Object { "{0}`t{0}`t{0}" -f $_ }
	$mainMenuListFile = Join-Path $hstLauncherMenuDir -ChildPath 'menu.lst'
	WriteAmigaTextLines $mainMenuListFile $mainMenuListLines

	# write menu list file for each index
	foreach ($indexName in ($hstLauncherMenuIndex.Keys | Sort-Object))
	{
		$indexMenuLines = $hstLauncherMenuIndex.Get_Item($indexName)

		$indexDir = Join-Path $hstLauncherMenuDir -ChildPath $indexName
		if(!(Test-Path -Path $indexDir))
		{
			mkdir $indexDir | Out-Null
		}

		# write index menu list file
		$indexMenuListFile = Join-Path $indexDir -ChildPath 'menu.lst'
		WriteAmigaTextLines $indexMenuListFile $indexMenuLines.ToArray()

		# copy index menu list file to index entries list file
		$indexEntriesListFile = Join-Path $indexDir -ChildPath 'entries.lst'
		Copy-Item $indexMenuListFile -Destination $indexEntriesListFile

		# write index title file
		$indexTitleFile = Join-Path $indexDir -ChildPath 'title.txt'
		WriteAmigaTextLines $indexTitleFile @($indexName)
	}

	# write all file
	$hstLauncherAllFile = Join-Path $hstLauncherMenuDir -ChildPath 'all.lst'
	WriteAmigaTextLines $hstLauncherAllFile $hstLauncherEntriesLines.ToArray()

	# write search file
	$hstLauncherSearchFile = Join-Path $hstLauncherMenuDir -ChildPath 'search.lst'
	Copy-Item $hstLauncherAllFile -Destination $hstLauncherSearchFile

	# write title file, if menu title is defined
	if ($menuTitle)
	{
		$hstLauncherTitleFile = Join-Path $hstLauncherMenuDir -ChildPath 'title.txt'
		WriteAmigaTextLines $hstLauncherTitleFile @($menuTitle)
	}

	# write hst launcher list file
	$hstLauncherListFile = [System.IO.Path]::Combine($hstLauncherOutputPath, "HST Launcher List")
	WriteAmigaTextLines $hstLauncherListFile $hstLauncherListLines
}


Write-Host ("{0} details not found" -f $detailsNotFoundCount)
Write-Host ("{0} screenshots not found" -f $screenshotsNotFoundCount)