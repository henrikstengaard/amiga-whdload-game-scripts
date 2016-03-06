# Build WHDLoad Index
# -------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-06
#
# A PowerShell script to build whdload index .csv file by extracting archive files, scan for whdload slave files and read available information from whdload slave depending on whdload slave version.
# Note: The script uses drive Z:\ as temp to extract and scan whdload archives, if drive is present. Otherwise it will use [SystemDrive]:\Temp, which is usually C:\Temp.
Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadArchiveFilesPath,
	[Parameter(Mandatory=$true)]
	[string]$outputPath
)

$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
$readWhdloadSlavePath = [System.IO.Path]::GetFullPath("read_whdload_slave.ps1")

# use Z:\ as temp, if present
if (Test-Path -path "Z:\")
{
	$tempPath = [System.IO.Path]::Combine("Z:\", [System.IO.Path]::GetRandomFileName())
}
else
{
	$tempPath = [System.IO.Path]::Combine("$env:SystemDrive\Temp", [System.IO.Path]::GetRandomFileName())
}

# build whdload index from files
function BuildWhdloadIndexFromFiles($outputPath, $whdloadArchiveFiles)
{
	# create output path, if it doesn'tr exist
	if(!(test-path -path $outputPath))
	{
		md $outputPath | Out-Null
	}	

	$whdloadIndexPath = [System.IO.Path]::Combine($outputPath, "whdload_index.csv")

	# add header to index
	Add-Content $whdloadIndexPath "ArchiveFile;SlaveFile;Name;Copy;Size;Version;Flags;BaseMemSize;KeyDebug;KeyExit;ExpMem"

	ForEach ($whdloadArchiveFile in $whdloadArchiveFiles)
	{
		Write-Output $whdloadArchiveFile.Name
		
		# delete temp path, if it exists
		if(test-path -path $tempPath)
		{
			remove-item $tempPath -recurse
		}
		
		md $tempPath | out-null

		# extract whdload archive using 7-zip
		$sevenZipExtractInstallArgs = "x ""$whdloadArchiveFile"" -aoa"
		$sevenZipExtractInstallProcess = Start-Process $sevenZipPath $sevenZipExtractInstallArgs -WorkingDirectory $tempPath -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul
		
		# add extract failed to index, if 7-zip extract fails
		if ($sevenZipExtractInstallProcess.ExitCode -ne 0)
		{
			Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);ERROR - FAILED TO EXTRACT"
			continue
		}

		# get temp files from temp path
		$tempFiles = Get-ChildItem -Recurse -File -Path $tempPath

		# add no files to index, if no files exist in temp path
		if (!$tempFiles)
		{
			Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);ERROR - NO FILES"
		}
		
		$whdloadSlaves = 0;
		
		ForEach ($tempFile in $tempFiles)
		{
			# read temp file bytes
			$tempFileBytes = [System.IO.File]::ReadAllBytes($tempFile.FullName)
		
			# get magic bytes from temp file
			$tempFileMagicBytes = New-Object byte[](4)
			[Array]::Copy($tempFileBytes, 0, $tempFileMagicBytes, 0, 4)
		
			# continue, if temp file doesn't have whdload slave magic bytes
			if (Compare-Object -ReferenceObject @(0, 0, 3, 243) -DifferenceObject $tempFileMagicBytes)
			{
				continue
			}

			# get whdload id from temp file
			$whdloadIdBytes = New-Object byte[](8)
			[Array]::Copy($tempFileBytes, 36, $whdloadIdBytes, 0, 8)
			$whdloadId = [System.Text.Encoding]::ASCII.GetString($whdloadIdBytes)
			
			# continue, if whdload id doesn't match 'WHDLOADS'
			if ($whdloadId -ne 'WHDLOADS')
			{
				continue
			}
			
			Write-Output $tempFile.Name
			
			$whdloadSlaves++
			$whdloadSlaveFile = $tempFile
			
			$whdloadSlaveTextFile = [System.IO.Path]::Combine($outputPath, "$($whdloadArchiveFile.Name)_$($whdloadSlaveFile.Name).txt")
		
			# read whdload slave information and write to text
			& $readWhdloadSlavePath -path $whdloadSlaveFile.FullName | Out-File $whdloadSlaveTextFile
			
			# read whdload slave text
			$whdloadSlaveText = Get-Content $whdloadSlaveTextFile
			
			# delete whdload slave text file, if file is empty
			if ($whdloadSlaveText.length -eq 0)
			{
				Remove-Item $whdloadSlaveTextFile
				continue
			}
			
			# get whdload information
			$size = $whdloadSlaveText | Select-String -Pattern  "Size\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$version = $whdloadSlaveText | Select-String -Pattern  "Version\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$flags = $whdloadSlaveText | Select-String -Pattern  "Flags\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$baseMemSize = $whdloadSlaveText | Select-String -Pattern  "BaseMemSize\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$keyDebug = $whdloadSlaveText | Select-String -Pattern  "KeyDebug\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$keyExit = $whdloadSlaveText | Select-String -Pattern  "KeyExit\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$expMem = $whdloadSlaveText | Select-String -Pattern  "ExpMem\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$name = $whdloadSlaveText | Select-String -Pattern  "Name\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
			$copy = $whdloadSlaveText | Select-String -Pattern  "Copy\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1

			# add whdload details to index
			Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);$($whdloadSlaveFile.Name);$name;$copy;$size;$version;$flags;$baseMemSize;$keyDebug;$keyExit;$expMem"
		}
		
		# add no slaves to index, if no slaves exist in temp path
		if ($whdloadSlaves -eq 0)
		{
			Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);ERROR - NO SLAVES"
		}
	}	

	# remove temp path
	if(test-path -path $tempPath)
	{
		remove-item $tempPath -recurse
	}
}

# 1. Check if 7-zip is present, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}

# 2. Get whdload archive files
$whdloadArchiveFiles = Get-ChildItem -recurse -Path $whdloadArchiveFilesPath -exclude *.html -File

# 3. Build whdload index from whdload archive files
BuildWhdloadIndexFromFiles $outputPath $whdloadArchiveFiles
