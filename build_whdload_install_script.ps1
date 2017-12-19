# Build WHDLoad Install Script
# ----------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-11-07
#
# A PowerShell script to build whdload install script used to install whdload demos or games based on entries files.


Param(
	[Parameter(Mandatory=$true)]
	[string]$entriesFiles,
	[Parameter(Mandatory=$true)]
	[string]$installScriptFile,
	[Parameter(Mandatory=$false)]
	[string]$filterEntriesFiles,
	[Parameter(Mandatory=$false)]
	[string]$userPackageEntriesDir,
	[Parameter(Mandatory=$false)]
	[switch]$copyEntries,
	[Parameter(Mandatory=$false)]
	[switch]$noIndexDirs
)

function WriteAmigaTextLines($path, $lines)
{
	$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1");
	$utf8 = [System.Text.Encoding]::UTF8;

	$amigaTextBytes = [System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($lines -join "`n"))
	[System.IO.File]::WriteAllText($path, $iso88591.GetString($amigaTextBytes), $iso88591)
}


# resolve paths
$installScriptFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($installScriptFile)

# create output directory, if it doesn't exist
$installScriptDir = Split-Path $installScriptFile -Parent
if(!(Test-Path -Path $installScriptDir))
{
	md $installScriptDir | Out-Null
}

# read entries files
$entries = @()
foreach($entriesFile in ($entriesFiles -Split ','))
{
	$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
	Write-Host ("Reading entries file '{0}'" -f $entriesFile)
	$entries += import-csv -delimiter ';' -path $entriesFile -encoding utf8 
}


# read filter entries files
$filterEntriesIndex = @{}
if ($filterEntriesFiles)
{
	foreach($filterEntriesFile in ($filterEntriesFiles -Split ','))
	{
		$filterEntriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($filterEntriesFile)
		Write-Host ("Reading filter entries file '{0}'" -f $filterEntriesFile)
		$filterEntries = @()
		$filterEntries += import-csv -delimiter ';' -path $filterEntriesFile -encoding utf8
	
		foreach($filterEntry in $filterEntries)
		{
			$filterEntriesIndex.Set_Item($filterEntry.RunFile, $true)
		}
	}
}

# install script lines
$installScriptLines = @()
$installScriptLines += '; EAB WHDLoad Pack Install Script'
$installScriptLines += '; -------------------------------'
$installScriptLines += ';'
$installScriptLines += '; Author: Henrik Noerfjand Stengaard'
$installScriptLines += ("; Date: {0}" -f (Get-Date -format "yyyy-MM-dd"))
$installScriptLines += ''
$installScriptLines += "; An AmigaDOS script to install WHDLoads from EAB WHDLoad Packs."
$installScriptLines += ''

$entryIndexes = @{}

$installScriptFilename = Split-Path $installScriptFile -Leaf
$installScriptPartCount = 0;
$installScriptPartLines = @()

foreach($entry in ($entries | Sort-Object @{expression={$_.EntryName};Ascending=$true}))
{
	if ($copyEntries -and $filterEntriesIndex.Count -gt 0 -and !$filterEntriesIndex.ContainsKey($entry.RunFile))
	{
		continue
	}

	if ($entry.EntryName -match '^[0-9]')
	{
		$indexName = '0-9'
	}
	else
	{
		$indexName = $entry.EntryName.Substring(0, 1).ToUpper()
	}

	if ($installScriptPartLines.Count -gt 2000)
	{
		# write install script part file
		$installScriptPartCount++
		$installScriptPartFilename = '{0}_{1}' -f $installScriptFilename, $installScriptPartCount
		WriteAmigaTextLines (Join-Path $installScriptDir -ChildPath $installScriptPartFilename) $installScriptPartLines
	
		# add install script part file
		$installScriptLines += 'execute USERPACKAGEDIR:Install/{0}' -f $installScriptPartFilename

		$installScriptPartLines = @()
	}

	if (!$entryIndexes.ContainsKey($indexName))
	{
		$installScriptPartLines += "; '{0}' index directory" -f $indexName
		$installScriptPartLines += "echo ""Installing '{0}'...""" -f $indexName

		if (!$noIndexDirs)
		{
			$installScriptPartLines += "set indexdir ""``execute INSTALLDIR:S/CombinePath ""`$INSTALLDIR"" ""{0}""``""" -f $indexName
			$installScriptPartLines += "IF NOT EXISTS ""`$indexdir"""
			$installScriptPartLines += "  MakePath >NIL: ""`$indexdir"""
			$installScriptPartLines += "ENDIF"
			$installScriptPartLines += "IF EXISTS ""`USERPACKAGEDIR:{0}{1}.info""" -f $userPackageEntriesDir, $indexName
			$installScriptPartLines += "  Copy >NIL: ""`USERPACKAGEDIR:{0}{1}.info"" ""`$INSTALLDIR""" -f $userPackageEntriesDir, $indexName
			$installScriptPartLines += "ENDIF"
			$installScriptPartLines += ''
			
			if (!$copyEntries)
			{
				$installScriptPartLines += "; Copy '{0}' index directory" -f $indexName
				$installScriptPartLines += "IF EXISTS ""`USERPACKAGEDIR:{0}{1}""" -f $userPackageEntriesDir, $indexName
				$installScriptPartLines += "  Copy >NIL: ""`USERPACKAGEDIR:{0}{1}"" ""`$INSTALLDIR"" ALL" -f $userPackageEntriesDir, $indexName
				$installScriptPartLines += "ENDIF"
				$installScriptPartLines += ''
			}
		}
		else
		{
			$installScriptPartLines += ''
		}

		$entryIndexes.Set_Item($indexName, $true)
	}

	if ($copyEntries)
	{
		if ($entry.ArchiveFile)
		{
			$installScriptPartLines += "; Extract '{0}' entry archive" -f $entry.EntryName
			$installScriptPartLines += "IF EXISTS ""USERPACKAGEDIR:{0}{1}""" -f $userPackageEntriesDir, $entry.ArchiveFile.Replace("\", "/")
			if ($entry.ArchiveFile -match '\.lha$')
			{
				$installScriptPartLines += "  lha -q -m1 x ""USERPACKAGEDIR:{0}{1}"" ""`$indexdir/""" -f $userPackageEntriesDir, $entry.ArchiveFile.Replace("\", "/")
			}
			elseif ($entry.ArchiveFile -match '\.zip$')
			{
				$installScriptPartLines += "  unzip -qq -o -x ""USERPACKAGEDIR:{0}{1}"" -d ""`$indexdir""" -f $userPackageEntriesDir, $entry.ArchiveFile.Replace("\", "/")
			}
			$installScriptPartLines += "ENDIF"
		}
		else
		{
			$installScriptPartLines += "; Copy '{0}' entry directory" -f $entry.EntryName
			$runDir = $entry.RunDir.Replace("\", "/")
			$installScriptPartLines += "IF EXISTS ""USERPACKAGEDIR:{0}{1}.info""" -f $userPackageEntriesDir, $runDir
			if (!$noIndexDirs)
			{
				$installScriptPartLines += "  Copy >NIL: ""USERPACKAGEDIR:{0}{1}.info"" ""`$indexdir""" -f $userPackageEntriesDir, $runDir
			}
			else
			{
				$installScriptPartLines += "  Copy >NIL: ""USERPACKAGEDIR:{0}{1}.info"" ""`$INSTALLDIR""" -f $userPackageEntriesDir, $runDir
			}
			$installScriptPartLines += "ENDIF"
			$installScriptPartLines += "set entrydir ""``execute INSTALLDIR:S/CombinePath ""`$INSTALLDIR"" ""{0}""``""" -f $runDir
			$installScriptPartLines += "IF NOT EXISTS ""`$entrydir"""
			$installScriptPartLines += "  MakePath >NIL: ""`$entrydir"""
			$installScriptPartLines += "ENDIF"
			$installScriptPartLines += "IF EXISTS ""USERPACKAGEDIR:{0}{1}""" -f $userPackageEntriesDir, $runDir
			$installScriptPartLines += "  Copy >NIL: ""USERPACKAGEDIR:{0}{1}"" ""`$entrydir"" ALL" -f $userPackageEntriesDir, $runDir
			$installScriptPartLines += "ENDIF"
		}

		$installScriptPartLines += ''
	}
}

# write install script part file, if install script part lines are present
if ($installScriptPartLines.Count -gt 0)
{
	$installScriptPartCount++
	$installScriptPartFilename = '{0}_{1}' -f $installScriptFilename, $installScriptPartCount
	WriteAmigaTextLines (Join-Path $installScriptDir -ChildPath $installScriptPartFilename) $installScriptPartLines
}

# add install script part file
$installScriptLines += 'execute USERPACKAGEDIR:Install/{0}' -f $installScriptPartFilename

# write install script file
WriteAmigaTextLines $installScriptFile $installScriptLines