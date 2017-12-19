# Build WHDLoad Remove Script
# ---------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-10-14
#
# A PowerShell script to build whdload remove script used to remove unwanted language or hardware versions of whdload demos or games.


Param(
	[Parameter(Mandatory=$true)]
	[string]$entriesFiles,
	[Parameter(Mandatory=$true)]
	[string]$assignName,
	[Parameter(Mandatory=$true)]
	[string]$menuTitle,
	[Parameter(Mandatory=$true)]
	[string]$outputDir
)

# calculate md5 hash from text
function CalculateMd5FromText($text)
{
    $encoding = [system.Text.Encoding]::UTF8
	$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	return [System.BitConverter]::ToString($md5.ComputeHash($encoding.GetBytes($text))).ToLower().Replace('-', '')
}


function WriteAmigaTextLines($path, $lines)
{
	$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1");
	$utf8 = [System.Text.Encoding]::UTF8;

	$amigaTextBytes = [System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($lines -join "`n"))
	[System.IO.File]::WriteAllText($path, $iso88591.GetString($amigaTextBytes), $iso88591)
}


# Resolve paths
$outputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputDir)

if(!(Test-Path -Path $outputDir))
{
	md $outputDir | Out-Null
}


# read entries files
$entries = @()
foreach($entriesFile in ($entriesFiles -Split ','))
{
	$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
	Write-Host ("Reading whdload slaves file '{0}'" -f $entriesFile)
	$entries += import-csv -delimiter ';' -path $entriesFile -encoding utf8 
}


# build langiuage and hardware indexes
$languagesIndex = @{}
$hardwaresIndex = @{}


# process whdload slave items
foreach($entry in $entries)
{
	$languages = @()
	if ($entry.FilteredLanguage)
	{
		$languages += $entry.FilteredLanguage.ToLower() -Split ',' | Where-Object { $_ }
	}
	else
	{
		$languages += 'en'		
	}

	foreach ($language in $languages)
	{
		# if ($language -eq '')
		# {
		# 	$language = 'en'
		# }

		if ($languagesIndex.ContainsKey($language))
		{
			$languagesList = $languagesIndex.Get_Item($language)
		}
		else
		{
			$languagesList = @()
		}

		$languagesList += $entry

		$languagesIndex.Set_Item($language, $languagesList)
	}
	
	$hardwares = @()
	if ($entry.FilteredHardware)
	{
		$hardwares += $entry.FilteredHardware.ToLower() -Split ','
	}

	foreach ($hardware in $hardwares)
	{
		if ($hardwaresIndex.ContainsKey($hardware))
		{
			$hardwaresList = $hardwaresIndex.Get_Item($hardware)
		}
		else
		{
			$hardwaresList = @()
		}

		$hardwaresList += $entry

		$hardwaresIndex.Set_Item($hardware, $hardwaresList)
	}
}


$removeWhdloadsLines = @()
$removeWhdloadsLines += "; Remove WHDLoads"
$removeWhdloadsLines += "; ---------------"
$removeWhdloadsLines += "; Author: Henrik Noerfjand Stengaard"
$removeWhdloadsLines += ("; Date: {0}" -f (Get-Date -format "yyyy-MM-dd"))
$removeWhdloadsLines += ";"
$removeWhdloadsLines += "; A remove WHDLoads script to remove unwanted WHDLoads language and hardware versions."
$removeWhdloadsLines += ''
$removeWhdloadsLines += ''
$removeWhdloadsLines += ("; Show error, if WHDLoads assign '{0}' doesn't exist" -f $assignName)
$removeWhdloadsLines += ("Assign >NIL: EXISTS {0}:" -f $assignName)
$removeWhdloadsLines += "IF WARN"
$removeWhdloadsLines += ("  REQUESTCHOICE >NIL: ""Error"" ""WHDLoads assign '{0}' doesn't exist!*N*NPlease verify WHDLoads assign is configured."" ""OK""" -f $assignName)
$removeWhdloadsLines += "  SKIP end"
$removeWhdloadsLines += "ENDIF"

$removeWhdloadsMenuLines = @()
$removeWhdloadsOptionLines = @()
$removeWhdloadsRunLines = @()
$removeWhdloadsTempLines = @()

foreach($language in ($languagesIndex.Keys | Sort-Object))
{
	$languageId = CalculateMd5FromText $language.ToUpper()

	$removeWhdloadsMenuLines += ""
	$removeWhdloadsMenuLines += ("; Language '{0}' menu" -f $language.ToUpper())
	$removeWhdloadsMenuLines += ("echo ""Language {0} : "" NOLINE >>T:removewhdloadsmenu" -f $language.ToUpper())
	$removeWhdloadsMenuLines += ("IF EXISTS ""T:{0}""" -f $languageId)
	$removeWhdloadsMenuLines += "  echo ""YES"" >>T:removewhdloadsmenu"
	$removeWhdloadsMenuLines += "ELSE"
	$removeWhdloadsMenuLines += "  echo ""NO "" >>T:removewhdloadsmenu"
	$removeWhdloadsMenuLines += "ENDIF"

	$removeWhdloadsMenuIndex++
	$removeWhdloadsOptionLines += ""
	$removeWhdloadsOptionLines += ("; Language '{0}' option" -f $language.ToUpper())
	$removeWhdloadsOptionLines += ("IF ""`$removewhdloadsmenu"" eq ""{0}""" -f $removeWhdloadsMenuIndex)
	$removeWhdloadsOptionLines += ("  IF EXISTS ""T:{0}""" -f $languageId)
	$removeWhdloadsOptionLines += ("    Delete >NIL: ""T:{0}""" -f $languageId)
	$removeWhdloadsOptionLines += "  ELSE"
	$removeWhdloadsOptionLines += ("    echo """" NOLINE >""T:{0}""" -f $languageId)
	$removeWhdloadsOptionLines += "  ENDIF"
	$removeWhdloadsOptionLines += "ENDIF"
	
	$removeWhdloadsRunLines += ""
	$removeWhdloadsRunLines += ("; Remove language '{0}', if it's selected" -f $language.ToUpper())
	$removeWhdloadsRunLines += ("IF EXISTS ""T:{0}""" -f $languageId)
	$removeWhdloadsRunLines += ("  echo ""Language {0}...""" -f $language.ToUpper())
	$removeWhdloadsRunLines += ("  execute ""Remove-Language-{0}""" -f $language.ToUpper())
	$removeWhdloadsRunLines += "ENDIF"
	
	$removeWhdloadsTempLines += ("IF EXISTS ""T:{0}""" -f $languageId)
	$removeWhdloadsTempLines += ("  Delete >NIL: ""T:{0}""" -f $languageId)
	$removeWhdloadsTempLines += "ENDIF"
	
	$languagesList = $languagesIndex.Get_Item($language)
	
	$languageRemoveScriptLines = @()

	foreach($entry in $languagesList)
	{
		$entryDir = '{0}:{1}' -f $assignName, ((Split-Path $entry.RunFile -Parent) -replace '\\', '/')
		
		$languageRemoveScriptLines += 'IF EXISTS "{0}"' -f $entryDir
		$languageRemoveScriptLines += '  Delete >NIL: "{0}" ALL' -f $entryDir
		$languageRemoveScriptLines += 'ENDIF'
	}

	$languageRemoveScriptFile = Join-Path $outputDir -ChildPath ('Remove-Language-{0}' -f $language.ToUpper())
	WriteAmigaTextLines $languageRemoveScriptFile $languageRemoveScriptLines
}

foreach($hardware in ($hardwaresIndex.Keys | Where-Object { $_ -notmatch '(ocs|ecs)' }| Sort-Object))
{
	$hardwareId = CalculateMd5FromText $hardware.ToUpper()
	
	$removeWhdloadsMenuLines += ""
	$removeWhdloadsMenuLines += ("; Hardware '{0}' menu" -f $hardware.ToUpper())
	$removeWhdloadsMenuLines += ("echo ""Hardware {0} : "" NOLINE >>T:removewhdloadsmenu" -f $hardware.ToUpper())
	$removeWhdloadsMenuLines += ("IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeWhdloadsMenuLines += "  echo ""YES"" >>T:removewhdloadsmenu"
	$removeWhdloadsMenuLines += "ELSE"
	$removeWhdloadsMenuLines += "  echo ""NO "" >>T:removewhdloadsmenu"
	$removeWhdloadsMenuLines += "ENDIF"

	$removeWhdloadsMenuIndex++
	$removeWhdloadsOptionLines += ""
	$removeWhdloadsOptionLines += ("; Hardware '{0}' option" -f $hardware.ToUpper())
	$removeWhdloadsOptionLines += ("IF ""`$removewhdloadsmenu"" eq ""{0}""" -f $removeWhdloadsMenuIndex)
	$removeWhdloadsOptionLines += ("  IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeWhdloadsOptionLines += ("    Delete >NIL: ""T:{0}""" -f $hardwareId)
	$removeWhdloadsOptionLines += "  ELSE"
	$removeWhdloadsOptionLines += ("    echo """" NOLINE >""T:{0}""" -f $hardwareId)
	$removeWhdloadsOptionLines += "  ENDIF"
	$removeWhdloadsOptionLines += "ENDIF"

	$removeWhdloadsRunLines += ""
	$removeWhdloadsRunLines += ("; Remove hardware '{0}', if it's selected" -f $hardware.ToUpper())
	$removeWhdloadsRunLines += ("IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeWhdloadsRunLines += ("  echo ""Hardware {0}...""" -f $hardware.ToUpper())
	$removeWhdloadsRunLines += ("  execute ""Remove-Hardware-{0}""" -f $hardware.ToUpper())
	$removeWhdloadsRunLines += "ENDIF"

	$removeWhdloadsTempLines += ("IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeWhdloadsTempLines += ("  Delete >NIL: ""T:{0}""" -f $hardwareId)
	$removeWhdloadsTempLines += "ENDIF"
	
	$hardwaresList = $hardwaresIndex.Get_Item($hardware)
	
	$hardwareRemoveScriptLines = @()

	foreach($entry in $hardwaresList)
	{
		$entryDir = '{0}:{1}' -f $assignName, ((Split-Path $entry.RunFile -Parent) -replace '\\', '/')

		$hardwareRemoveScriptLines += 'IF EXISTS "{0}"' -f $entryDir
		$hardwareRemoveScriptLines += '  Delete >NIL: "{0}" ALL' -f $entryDir
		$hardwareRemoveScriptLines += 'ENDIF'
	}

	$hardwareRemoveScriptFile = Join-Path $outputDir -ChildPath ('Remove-Hardware-{0}' -f $hardware.ToUpper())
	WriteAmigaTextLines $hardwareRemoveScriptFile $hardwareRemoveScriptLines
}


$removeWhdloadsLines += ''
$removeWhdloadsLines += ''
$removeWhdloadsLines += '; Reset selected remove whdloads options'
$removeWhdloadsLines += '; --------------------------------------'
$removeWhdloadsLines += $removeWhdloadsTempLines

$removeWhdloadsLines += ''
$removeWhdloadsLines += ''
$removeWhdloadsLines += '; Build remove WHDLoads menu'
$removeWhdloadsLines += '; --------------------------'
$removeWhdloadsLines += 'LAB removewhdloadsmenu'
$removeWhdloadsLines += "echo """" NOLINE >T:removewhdloadsmenu"

$removeWhdloadsLines += $removeWhdloadsMenuLines

$removeWhdloadsLines += "echo ""=============================="" >>T:removewhdloadsmenu"
$removeWhdloadsLines += "echo ""Remove selected WHDLoads"" >>T:removewhdloadsmenu"
$removeWhdloadsLines += "echo ""Quit"" >>T:removewhdloadsmenu"
$removeWhdloadsLines += ''
$removeWhdloadsLines += "; Show remove whdloads menu"
$removeWhdloadsLines += "set removewhdloadsmenu """""
$removeWhdloadsLines += "set removewhdloadsmenu ""``C:RequestList TITLE=""{0}"" LISTFILE=""T:removewhdloadsmenu"" WIDTH=320 LINES=20``""" -f $menuTitle

$removeWhdloadsLines += "delete >NIL: T:removewhdloadsmenu"

$removeWhdloadsLines += $removeWhdloadsOptionLines

$removeWhdloadsLines += ''
$removeWhdloadsLines += "; Remove selected whdloads option"
$removeWhdloadsLines += ("IF ""`$removewhdloadsmenu"" eq """ + ($removeWhdloadsMenuIndex + 2) + """")
$removeWhdloadsLines += "  set confirm ``RequestChoice ""Confirm"" ""Are you sure you want to remove selected WHDLoads?"" ""Yes|No""``"
$removeWhdloadsLines += "  IF ""`$confirm"" EQ ""1"""
$removeWhdloadsLines += "    SKIP runremovewhdloads"
$removeWhdloadsLines += "  ENDIF"
$removeWhdloadsLines += "ENDIF"
$removeWhdloadsLines += ""
$removeWhdloadsLines += "; Quit option"
$removeWhdloadsLines += ("IF ""`$removewhdloadsmenu"" eq """ + ($removeWhdloadsMenuIndex + 3) + """")
$removeWhdloadsLines += "  SKIP end"
$removeWhdloadsLines += "ENDIF"
$removeWhdloadsLines += ''
$removeWhdloadsLines += "SKIP BACK removewhdloadsmenu"
$removeWhdloadsLines += ''
$removeWhdloadsLines += ''
$removeWhdloadsLines += "; Remove WHDLoads"
$removeWhdloadsLines += "; ---------------"
$removeWhdloadsLines += "LAB runremovewhdloads"
$removeWhdloadsLines += ''
$removeWhdloadsLines += "echo ""*e[1mRemoving WHDLoads...*e[0m"""

$removeWhdloadsLines += $removeWhdloadsRunLines

$removeWhdloadsLines += "echo ""Done"""
$removeWhdloadsLines += ''
$removeWhdloadsLines += ''
$removeWhdloadsLines += "echo """""
$removeWhdloadsLines += "echo ""Remove WHDLoads is complete."""
$removeWhdloadsLines += "echo """""
$removeWhdloadsLines += "ask ""Press ENTER to continue"""
$removeWhdloadsLines += ''
$removeWhdloadsLines += "; End"
$removeWhdloadsLines += "LAB end"
$removeWhdloadsLines += ''
$removeWhdloadsLines += '; Delete temp files, if they exist'

$removeWhdloadsLines += $removeWhdloadsTempLines

$removeWhdloadsFile = Join-Path $outputDir -ChildPath 'Remove-WHDLoads'
WriteAmigaTextLines $removeWhdloadsFile $removeWhdloadsLines
