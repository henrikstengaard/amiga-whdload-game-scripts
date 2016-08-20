# Build WHDLoad Slave List
# ------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-06-17
#
# A PowerShell script to build whdload slave list csv file with a list of whdload name and path to whdload slave file.

Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadPath
)

$readWhdloadSlavePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("read_whdload_slave.ps1")

Function IsWhdloadSlaveFile($filePath)
{
	# read file bytes
	$fileBytes = [System.IO.File]::ReadAllBytes($filePath)

	# return false, if file is less than 50 bytes
	if ($fileBytes.Count -lt 50)
	{
		return $false
	}
	
	# get magic bytes from file
	$fileMagicBytes = New-Object byte[](4)
	[Array]::Copy($fileBytes, 0, $fileMagicBytes, 0, 4)

	# return false, if file doesn't have whdload slave magic bytes
	if (Compare-Object -ReferenceObject @(0, 0, 3, 243) -DifferenceObject $fileMagicBytes)
	{
		return $false
	}

	# get whdload id from temp file
	$whdloadIdBytes = New-Object byte[](8)
	[Array]::Copy($fileBytes, 36, $whdloadIdBytes, 0, 8)
	$whdloadId = [System.Text.Encoding]::ASCII.GetString($whdloadIdBytes)
	
	# return false, if whdload id doesn't match 'WHDLOADS'
	if ($whdloadId -ne 'WHDLOADS')
	{
		return $false
	}

	return $true
}


$whdloadSlaves = @()

foreach($file in (Get-ChildItem -Path $whdloadPath -recurse | Where { !$_.PSIsContainer -and (IsWhdloadSlaveFile $_.FullName) }))
{
	$whdloadName = [System.IO.Path]::GetFileName($file.Directory)
	
	if ($whdloadName -match '^data$')
	{
		$whdloadName = $file.Name -replace '\.slave', ''
	}
	
	$whdloadSize = 0 
	Get-ChildItem -Path $file.Directory -Recurse  | Where { !$_.PSIsContainer } | % { $whdloadSize += $_.length } 

	$whdloadPathIndex = $file.FullName.IndexOf($whdloadPath) + $whdloadPath.Length + 1
	$whdloadSlaveFilePath = $file.FullName.Substring($whdloadPathIndex, $file.FullName.Length - $whdloadPathIndex)

	$readmeFile = Get-ChildItem -Path $file.Directory -filter readme*.* | Select-Object -First 1
	
	$readmeAppliesTo = $null
	
	if ($readmeFile)
	{
		$readmeAppliesTo = Get-Content $readmeFile.FullName -encoding ascii | Where { $_ -match '(install|patch) applies to' } | Select-String -Pattern "(install|patch) applies to\s*(.*)?" -AllMatches | % { $_.Matches } | % { $_.Groups[2].Value.Replace("""", "").Trim() } | Select-Object -First 1 
	}

	# read whdload slave information and write to text
	$whdloadSlaveOutput = & $readWhdloadSlavePath -path $file.FullName
	
	$whdloadSlaveName = $whdloadSlaveOutput | Select-String -Pattern  "Name\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
	$whdloadSlaveCopy = $whdloadSlaveOutput | Select-String -Pattern  "Copy\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
	$whdloadSlaveFlags = $whdloadSlaveOutput | Select-String -Pattern  "Flags\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
	$whdloadSlaveBaseMemSize = $whdloadSlaveOutput | Select-String -Pattern  "BaseMemSize\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
	$whdloadSlaveExecInstall = $whdloadSlaveOutput | Select-String -Pattern  "ExecInstall\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1

	$whdloadSlave = @{ "WhdloadName" = $whdloadName; "WhdloadSize" = $whdloadSize; "WhdloadSlaveFilePath" = $whdloadSlaveFilePath; "WhdloadSlaveName" = $whdloadSlaveName; "WhdloadSlaveCopy" = $whdloadSlaveCopy; "WhdloadSlaveFlags" = $whdloadSlaveFlags; "WhdloadSlaveBaseMemSize" = $whdloadSlaveBaseMemSize; "WhdloadSlaveExecInstall" = $whdloadSlaveExecInstall; "ReadmeAppliesTo" = $readmeAppliesTo }

	$whdloadSlaves +=, $whdloadSlave
}

# write game list
$whdloadSlaveListPath = [System.IO.Path]::Combine($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadPath), "whdload_slaves.csv")
$whdloadSlaves | %{ New-Object PSObject -Property $_ } | export-csv -delimiter ';' -path $whdloadSlaveListPath -NoTypeInformation
