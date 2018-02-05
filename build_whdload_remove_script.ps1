# Build entries remove script
# ---------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2018-01-16
#
# A PowerShell script to build entries remove script used to remove unwanted language or hardware versions of demos or games.


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
	Write-Host ("Reading entries file '{0}'" -f $entriesFile)
	$entries += import-csv -delimiter ';' -path $entriesFile -encoding utf8 
}


# build langiuage and hardware indexes
$languagesIndex = @{}
$hardwaresIndex = @{}


# process entries
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


$removeEntriesLines = @()
$removeEntriesLines += "; Remove entries"
$removeEntriesLines += "; --------------"
$removeEntriesLines += "; Author: Henrik Noerfjand Stengaard"
$removeEntriesLines += ("; Date: {0}" -f (Get-Date -format "yyyy-MM-dd"))
$removeEntriesLines += ";"
$removeEntriesLines += "; An AmigaDOS script to remove unwanted entries language and hardware versions."
$removeEntriesLines += ''
$removeEntriesLines += ''
$removeEntriesLines += ("; Show error, if assign '{0}' doesn't exist" -f $assignName)
$removeEntriesLines += ("Assign >NIL: EXISTS {0}:" -f $assignName)
$removeEntriesLines += "IF WARN"
$removeEntriesLines += ("  REQUESTCHOICE >NIL: ""Error"" ""Assign '{0}' doesn't exist!*N*NPlease verify assign is configured."" ""OK""" -f $assignName)
$removeEntriesLines += "  SKIP end"
$removeEntriesLines += "ENDIF"

$removeEntriesMenuLines = @()
$removeEntriesOptionLines = @()
$removeEntriesRunLines = @()
$removeEntriesTempLines = @()

foreach($language in ($languagesIndex.Keys | Sort-Object))
{
	$languageId = CalculateMd5FromText $language.ToUpper()

	$removeEntriesMenuLines += ""
	$removeEntriesMenuLines += ("; Language '{0}' menu" -f $language.ToUpper())
	$removeEntriesMenuLines += ("echo ""Language {0} : "" NOLINE >>T:removeentriesmenu" -f $language.ToUpper())
	$removeEntriesMenuLines += ("IF EXISTS ""T:{0}""" -f $languageId)
	$removeEntriesMenuLines += "  echo ""YES"" >>T:removeentriesmenu"
	$removeEntriesMenuLines += "ELSE"
	$removeEntriesMenuLines += "  echo ""NO "" >>T:removeentriesmenu"
	$removeEntriesMenuLines += "ENDIF"

	$removeEntriesMenuIndex++
	$removeEntriesOptionLines += ""
	$removeEntriesOptionLines += ("; Language '{0}' option" -f $language.ToUpper())
	$removeEntriesOptionLines += ("IF ""`$removeentriesmenu"" eq ""{0}""" -f $removeEntriesMenuIndex)
	$removeEntriesOptionLines += ("  IF EXISTS ""T:{0}""" -f $languageId)
	$removeEntriesOptionLines += ("    Delete >NIL: ""T:{0}""" -f $languageId)
	$removeEntriesOptionLines += "  ELSE"
	$removeEntriesOptionLines += ("    echo """" NOLINE >""T:{0}""" -f $languageId)
	$removeEntriesOptionLines += "  ENDIF"
	$removeEntriesOptionLines += "ENDIF"
	
	$removeEntriesRunLines += ""
	$removeEntriesRunLines += ("; Remove language '{0}', if it's selected" -f $language.ToUpper())
	$removeEntriesRunLines += ("IF EXISTS ""T:{0}""" -f $languageId)
	$removeEntriesRunLines += ("  echo ""Language {0}...""" -f $language.ToUpper())
	$removeEntriesRunLines += ("  execute ""Remove-Language-{0}""" -f $language.ToUpper())
	$removeEntriesRunLines += "ENDIF"
	
	$removeEntriesTempLines += ("IF EXISTS ""T:{0}""" -f $languageId)
	$removeEntriesTempLines += ("  Delete >NIL: ""T:{0}""" -f $languageId)
	$removeEntriesTempLines += "ENDIF"
	
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
	
	$removeEntriesMenuLines += ""
	$removeEntriesMenuLines += ("; Hardware '{0}' menu" -f $hardware.ToUpper())
	$removeEntriesMenuLines += ("echo ""Hardware {0} : "" NOLINE >>T:removeentriesmenu" -f $hardware.ToUpper())
	$removeEntriesMenuLines += ("IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeEntriesMenuLines += "  echo ""YES"" >>T:removeentriesmenu"
	$removeEntriesMenuLines += "ELSE"
	$removeEntriesMenuLines += "  echo ""NO "" >>T:removeentriesmenu"
	$removeEntriesMenuLines += "ENDIF"

	$removeEntriesMenuIndex++
	$removeEntriesOptionLines += ""
	$removeEntriesOptionLines += ("; Hardware '{0}' option" -f $hardware.ToUpper())
	$removeEntriesOptionLines += ("IF ""`$removeentriesmenu"" eq ""{0}""" -f $removeEntriesMenuIndex)
	$removeEntriesOptionLines += ("  IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeEntriesOptionLines += ("    Delete >NIL: ""T:{0}""" -f $hardwareId)
	$removeEntriesOptionLines += "  ELSE"
	$removeEntriesOptionLines += ("    echo """" NOLINE >""T:{0}""" -f $hardwareId)
	$removeEntriesOptionLines += "  ENDIF"
	$removeEntriesOptionLines += "ENDIF"

	$removeEntriesRunLines += ""
	$removeEntriesRunLines += ("; Remove hardware '{0}', if it's selected" -f $hardware.ToUpper())
	$removeEntriesRunLines += ("IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeEntriesRunLines += ("  echo ""Hardware {0}...""" -f $hardware.ToUpper())
	$removeEntriesRunLines += ("  execute ""Remove-Hardware-{0}""" -f $hardware.ToUpper())
	$removeEntriesRunLines += "ENDIF"

	$removeEntriesTempLines += ("IF EXISTS ""T:{0}""" -f $hardwareId)
	$removeEntriesTempLines += ("  Delete >NIL: ""T:{0}""" -f $hardwareId)
	$removeEntriesTempLines += "ENDIF"
	
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


$removeEntriesLines += ''
$removeEntriesLines += ''
$removeEntriesLines += '; Reset selected remove entries options'
$removeEntriesLines += '; -------------------------------------'
$removeEntriesLines += $removeEntriesTempLines

$removeEntriesLines += ''
$removeEntriesLines += ''
$removeEntriesLines += '; Build remove entries menu'
$removeEntriesLines += '; -------------------------'
$removeEntriesLines += 'LAB removeentriesmenu'
$removeEntriesLines += "echo """" NOLINE >T:removeentriesmenu"

$removeEntriesLines += $removeEntriesMenuLines

$removeEntriesLines += "echo ""=============================="" >>T:removeentriesmenu"
$removeEntriesLines += "echo ""Remove selected entries"" >>T:removeentriesmenu"
$removeEntriesLines += "echo ""Quit"" >>T:removeentriesmenu"
$removeEntriesLines += ''
$removeEntriesLines += "; Show remove entries menu"
$removeEntriesLines += "set removeentriesmenu """""
$removeEntriesLines += "set removeentriesmenu ""``C:RequestList TITLE=""{0}"" LISTFILE=""T:removeentriesmenu"" WIDTH=320 LINES=20``""" -f $menuTitle

$removeEntriesLines += "delete >NIL: T:removeentriesmenu"

$removeEntriesLines += $removeEntriesOptionLines

$removeEntriesLines += ''
$removeEntriesLines += "; Remove selected entries option"
$removeEntriesLines += ("IF ""`$removeentriesmenu"" eq """ + ($removeEntriesMenuIndex + 2) + """")
$removeEntriesLines += "  set confirm ``RequestChoice ""Confirm"" ""Are you sure you want to remove selected entries?"" ""Yes|No""``"
$removeEntriesLines += "  IF ""`$confirm"" EQ ""1"""
$removeEntriesLines += "    SKIP runremoveentries"
$removeEntriesLines += "  ENDIF"
$removeEntriesLines += "ENDIF"
$removeEntriesLines += ""
$removeEntriesLines += "; Quit option"
$removeEntriesLines += ("IF ""`$removeentriesmenu"" eq """ + ($removeEntriesMenuIndex + 3) + """")
$removeEntriesLines += "  SKIP end"
$removeEntriesLines += "ENDIF"
$removeEntriesLines += ''
$removeEntriesLines += "SKIP BACK removeentriesmenu"
$removeEntriesLines += ''
$removeEntriesLines += ''
$removeEntriesLines += "; Remove entries"
$removeEntriesLines += "; ---------------"
$removeEntriesLines += "LAB runremoveentries"
$removeEntriesLines += ''
$removeEntriesLines += "echo ""*e[1mRemoving entries...*e[0m"""

$removeEntriesLines += $removeEntriesRunLines

$removeEntriesLines += "echo ""Done"""
$removeEntriesLines += ''
$removeEntriesLines += ''
$removeEntriesLines += "echo """""
$removeEntriesLines += "echo ""Remove entries is complete."""
$removeEntriesLines += "echo """""
$removeEntriesLines += "ask ""Press ENTER to continue"""
$removeEntriesLines += ''
$removeEntriesLines += "; End"
$removeEntriesLines += "LAB end"
$removeEntriesLines += ''
$removeEntriesLines += '; Delete temp files, if they exist'

$removeEntriesLines += $removeEntriesTempLines

$removeEntriesFile = Join-Path $outputDir -ChildPath 'Remove-Entries'
WriteAmigaTextLines $removeEntriesFile $removeEntriesLines