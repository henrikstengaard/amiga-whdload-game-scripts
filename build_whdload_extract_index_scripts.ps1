# Build WHDLoad Extract Index Scripts
# -----------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-18
#
# A PowerShell script to build whdload extract index and scripts for extracting whdload acrhives on Amiga partitions.


# 7-zip:
# http://7-zip.org/download.html
# http://7-zip.org/a/7z1514-x64.exe


Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadGamesPath,
	[Parameter(Mandatory=$true)]
	[string]$outputPath
)


# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


# programs 
$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"


# input and output paths
$whdownloadGamesSlaveIndexPath = [System.IO.Path]::Combine($scriptPath, "whdownload_games_slave_index")


# get game index name from first character in game name
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


# read whdload games index
function ReadWhdloadGamesIndex($whdloadGameIndexFile)
{
	$index = @{}

	ForEach($line in (Get-Content $whdloadGameIndexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		$index.Set_Item($columns[0], $columns)
	}
	
	return $index
}



# 1. check if 7-zip is installed, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}



# 2. Get whdload game files
Write-Output "Reading whdload games from '$whdloadGamesPath'..."
$whdloadGameFiles = Get-ChildItem -recurse -Path $whdloadGamesPath -exclude *.html,*.csv -File
Write-Output "$($whdloadGameFiles.Count) entries"
Write-Output ""



# 3. Read whdload games index
$whdloadGameIndexFile = [System.IO.Path]::Combine($whdloadGamesPath, "whdload_games_index.csv")
Write-Output "Reading whdload games index file '$whdloadGameIndexFile'..."
$whdloadGameIndex = ReadWhdloadGamesIndex $whdloadGameIndexFile
$whdloadGameIndex.Count



# 4. Create output path, if it doesn't exist
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}



$partitionNumber = 1
$partitionSize = 0
$assignName = "A-Games"

$whdloadExtractScriptFile = [System.IO.Path]::Combine($outputPath, "whdload_extract_partition$partitionNumber")
$whdloadExtractScript = "; Extract whdload to $($assignName)$($partitionNumber):`n"
$whdloadExtractScript += "; assign $($assignName)$($partitionNumber): DH$($partitionNumber):WHDLoad/Games`n"
$whdloadExtractScript += "; execute whdload_extract_partition$partitionNumber`n`n"

$whdloadExtractIndexFile = [System.IO.Path]::Combine($outputPath, "whdload_extract_index.csv")
$whdloadExtractIndex = "Whdload Game FileName;Whdload Game Extract Path`r`n"

$currentWhdownloadGameIndexName = ""


# 13. Process whdload game files
ForEach ($whdloadGameFile in $whdloadGameFiles)
{
	# get whdload game from index
	$whdloadGame = $whdloadGameIndex.Get_Item($whdloadGameFile.Name)

	# skip, if no whdload game
	if (!$whdloadGame)
	{
		continue
	}
	
	$whdloadGameName = $whdloadGame[1]
	$whdloadGameUncompressedSize = $whdloadGame[2]

	# if partition is full, increase partition number 
	if (($partitionSize + $whdloadGameUncompressedSize) -gt 1900000000)
	{
		# write whdload extract script
		[System.IO.File]::WriteAllText($whdloadExtractScriptFile, $whdloadExtractScript, [System.Text.Encoding]::ASCII)

		$partitionNumber++
		$partitionSize = 0;

		$whdloadExtractScriptFile = [System.IO.Path]::Combine($outputPath, "whdload_extract_partition$partitionNumber")
		$whdloadExtractScript = "; Extract whdload to $($assignName)$($partitionNumber):`n"
		$whdloadExtractScript += "; assign $($assignName)$($partitionNumber): DH$($partitionNumber):WHDLoad/Games`n"
		$whdloadExtractScript += "; execute whdload_extract_partition$partitionNumber`n`n"
	}

	# add uncompressed whdload game size to partition size
	$partitionSize += $whdloadGameUncompressedSize
	

	$whdownloadGameIndexName = GetGameIndexName $whdloadGameFile.Name

	
	$whdloadGameExtractPath = "$($assignName)$($partitionNumber):$whdownloadGameIndexName"

	if ($currentWhdownloadGameIndexName -ne $whdownloadGameIndexName)
	{
		$whdloadExtractScript += "`nIF NOT EXISTS $whdloadGameExtractPath`n"
		$whdloadExtractScript += "  makedir $whdloadGameExtractPath`n"
		$whdloadExtractScript += "ENDIF`n`n"

		$currentWhdownloadGameIndexName = $whdownloadGameIndexName
	}
	
	$whdloadGameArchivePath = $whdownloadGameIndexName + "/" + $whdloadGameFile.Name
	
	# get whdload game file extension
	$whdloadGameFileExtension = [System.IO.Path]::GetExtension($whdloadGameFile.Name)

	# extract zip archive
	if ($whdloadGameFileExtension -eq '.zip')
	{
		$whdloadExtractScript += "unzip -o -x $whdloadGameArchivePath -d $whdloadGameExtractPath`n"
		$whdloadExtractIndex += "$($whdloadGameFile.Name);$whdloadGameExtractPath`r`n"
	}

	# extract lha archive
	if ($whdloadGameFileExtension -eq '.lha')
	{
		$whdloadExtractScript += "lha -m1 x $whdloadGameArchivePath $whdloadGameExtractPath/`n"
		$whdloadExtractIndex += "$($whdloadGameFile.Name);$whdloadGameExtractPath`r`n"
	}

}

# write whdload extract index and script
[System.IO.File]::WriteAllText($whdloadExtractIndexFile, $whdloadExtractIndex, [System.Text.Encoding]::ASCII)
[System.IO.File]::WriteAllText($whdloadExtractScriptFile, $whdloadExtractScript, [System.Text.Encoding]::ASCII)
