# Build Amiga English Board WHDLoad Package
# -----------------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-01-04
#
# A PowerShell script to build whdload package.


Param(
	[Parameter(Mandatory=$true)]
	[string]$eabWhdloadPath,
	[Parameter(Mandatory=$true)]
	[string]$packageName,
	[Parameter(Mandatory=$true)]
	[string]$packageVersion,
	[Parameter(Mandatory=$true)]
	[string]$packageInstallDir
)


Add-Type -Assembly System.IO.Compression.FileSystem


function WriteAmigaTextLines($path, $lines)
{
	$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1");
	$utf8 = [System.Text.Encoding]::UTF8;

	$amigaTextBytes = [System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($lines -join "`n"))
	[System.IO.File]::WriteAllText($path, $iso88591.GetString($amigaTextBytes), $iso88591)
}


# resolve paths
$eabWhdloadPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($eabWhdloadPath)
$packagePath = [System.IO.Path]::Combine($eabWhdloadPath, "package")


$installLines = @()

$packageInstallDeviceName = $packageInstallDir.Substring(0, $packageInstallDir.IndexOf(":") + 1)
$packageInstallPath = $packageInstallDir.Substring($packageInstallDir.IndexOf(":") + 1, $packageInstallDir.Length - $packageInstallDir.IndexOf(":") - 1)

$currentPath = $packageInstallDeviceName
foreach ($directoryName in ($packageInstallPath -split '/'))
{
	if (!$currentPath.EndsWith(":"))
	{
		$currentPath += "/"
	}
	$currentPath += $directoryName

	$installLines += ("IF NOT EXISTS ""$currentPath""")
	$installLines += ("  makedir >NIL: ""$currentPath""")
	$installLines += ("ENDIF")
}


if(!(test-path -path $packagePath))
{
	mkdir $packagePath | Out-Null
}

$indexInfoFiles = Get-ChildItem -Path $eabWhdloadPath -Filter "*.info"

foreach ($indexInfoFile in $indexInfoFiles)
{
	$indexName = $indexInfoFile.Basename

	$whdloadIndexDir = [System.IO.Path]::Combine($eabWhdloadPath, $indexName)

	$packageIndexZipFileName = "{0}.zip" -f $indexName
	$packageIndexZipFile = [System.IO.Path]::Combine($packagePath, $packageIndexZipFileName)

	$installLines += ("echo ""Extracting '{0}'...""" -f $packageIndexZipFileName)
	$installLines += ("unzip -qq -o -x ""PACKAGEDIR:{0}"" -d ""{1}""" -f $packageIndexZipFileName, $packageInstallDir)

	if (Test-Path -path $packageIndexZipFile)
	{
		Remove-Item -path $packageIndexZipFile
	}

	Write-Host "compress $whdloadIndexDir to $packageIndexZipFile"

	$packageIndexZipArchive = [System.IO.Compression.ZipFile]::Open($packageIndexZipFile, "Create")
	[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($packageIndexZipArchive, $indexInfoFile.Fullname, $indexInfoFile.Name) | Out-Null

	$files = Get-ChildItem -Path $whdloadIndexDir -Recurse | Where-Object { ! $_.PSIsContainer }
	foreach($file in $files)
	{
		$entryName = $file.Fullname.Replace($eabWhdloadPath + "\", "").Replace("\", "/")
		[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($packageIndexZipArchive, $file.Fullname, $entryName) | Out-Null
	}

	$packageIndexZipArchive.Dispose()
}

# write package install script file
$packageInstallScriptFile = [System.IO.Path]::Combine($packagePath, "Install")
WriteAmigaTextLines $packageInstallScriptFile $installLines

# write package ini file
$packageIniLines = @("[Package]",("Name={0}" -f $packageName), ("Version={0}" -f $packageVersion), "Dependencies=")
$packageIniFile = [System.IO.Path]::Combine($packagePath, "package.ini")
[System.IO.File]::WriteAllText($packageIniFile, ($packageIniLines -join [System.Environment]::NewLine))
