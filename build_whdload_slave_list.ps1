# Build WHDLoad Slave List
# ------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2018-04-23
#
# A PowerShell script to build whdload slave list csv file with a list of whdload name and path to whdload slave file.

Param(
	[Parameter(Mandatory=$true)]
	[string]$entriesDir,
	[Parameter(Mandatory=$true)]
	[string]$entriesFile
)

# imports
$scriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module (join-path -Path $scriptDir -ChildPath 'data.psm1') -Force

# paths
$entriesDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesDir)
$entriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entriesFile)
$readWhdloadSlaveFile = Join-Path -Path $scriptDir -ChildPath "read_whdload_slave.ps1"

# find entries in entries dir
$entries = @()
$entries += FindEntries $readWhdloadSlaveFile $entriesDir

# create output dir, if it doesn't exist
$outputDir = Split-Path $entriesFile -Parent
if(!(test-path -path $outputDir))
{
	mkdir $outputDir | Out-Null
}

# write output file
$entries | ForEach-Object{ New-Object PSObject -Property $_ } | export-csv -delimiter ';' -path $entriesFile -NoTypeInformation -Encoding UTF8