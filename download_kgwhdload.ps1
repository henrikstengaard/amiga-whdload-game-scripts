# Download KGWHDLoad
# ------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-15
#
# A PowerShell script to download game packs from http://kg.whdownload.com/kgwhd/.

# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

$kgwhdloadGamePacksPath = [System.IO.Path]::Combine($scriptPath, "kgwhdload")

$sevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"

# Get kgwhdload game pack urls by downloading html and use regex to find game pack urls
function GetKGWHDLoadGamePackUrls($outputPath)
{
	if(!(Test-Path -Path $outputPath))
	{
		md $outputPath | Out-Null
	}		

	$kgwhdloadBaseUrl = 'http://kg.whdownload.com/kgwhd/';

	$kgwhdloadHtmlPath = [System.IO.Path]::Combine($outputPath, "kgwhdload.html")
	
	if (Test-Path -Path $kgwhdloadHtmlPath)
	{
		$kgwhdloadHtml = [System.IO.File]::ReadAllText($kgwhdloadHtmlPath)
	}
	else
	{
		Write-Host "Downloading kgwhdload html...";

		$webclient = New-Object System.Net.WebClient
		$kgwhdloadHtml = [System.Text.Encoding]::UTF8.GetString($webclient.DownloadData($kgwhdloadBaseUrl))
		
		$kgwhdloadHtml | Out-File $kgwhdloadHtmlPath
	}

	$kgwhdloadGamePackUrls = $kgwhdloadHtml | Select-String -Pattern "<a\s+href=""(files/(GamePacks|GameUpdates)/WHDLOAD Games.*[^""<>]+\.zip)" -AllMatches | % { $_.Matches } | % { $kgwhdloadBaseUrl + $_.Groups[1].Value }

	Write-Host "$($kgwhdloadGamePackUrls.Count) whdload install urls found in html"
	
	return $kgwhdloadGamePackUrls
}

# Download kgwhdload game pack urls
function DownloadKGWHDLoadGamePackUrls($outputPath, $kgwhdloadGamePackUrls)
{
	if(!(Test-Path -Path $outputPath))
	{
		md $outputPath | Out-Null
	}		
	
	$webclient = New-Object System.Net.WebClient

	For ($i = 0; $i -lt $kgwhdloadGamePackUrls.Count; $i++)
	{
		$kgwhdloadGamePackUrl = $kgwhdloadGamePackUrls[$i]
	
		$kgwhdloadGamePackFileName = [System.IO.Path]::GetFileName($kgwhdloadGamePackUrl)
		$kgwhdloadGamePackFile = [System.IO.Path]::Combine($outputPath, $kgwhdloadGamePackFileName)

		if (Test-Path -Path $kgwhdloadGamePackFile)
		{
			continue;
		}

		Write-Host -NoNewline "Downloading '$kgwhdloadGamePackFileName' ($($i + 1) / $($kgwhdloadGamePackUrls.Count))...                                `r"
		
		Start-Sleep -s 1
		
		$webclient.DownloadFile($kgwhdloadGamePackUrl, $kgwhdloadGamePackFile)
	}
	
	Write-Host ""
}

# Download whdload installs to output path
function UnzipKGWHDLoadGamePackFiles($outputPath, $kgwhdloadGamePackUrls)
{
	$gamesPath = [System.IO.Path]::Combine($outputPath, "games")

	if(!(Test-Path -Path $gamesPath))
	{
		md $gamesPath | Out-Null
	}

	[array]::Reverse($kgwhdloadGamePackUrls)
	
	ForEach ($kgwhdloadGamePackUrl in $kgwhdloadGamePackUrls)
	{
		$kgwhdloadGamePackFileName = [System.IO.Path]::GetFileName($kgwhdloadGamePackUrl)
		$kgwhdloadGamePackFile = [System.IO.Path]::Combine($outputPath, $kgwhdloadGamePackFileName)

		# extract whdload archive using 7-zip
		$sevenZipExtractInstallArgs = "x ""$kgwhdloadGamePackFile"" -aoa"
		$sevenZipExtractInstallProcess = Start-Process $sevenZipPath $sevenZipExtractInstallArgs -WorkingDirectory $gamesPath -Wait -Passthru -NoNewWindow -RedirectStandardOutput nul
		
		# add extract failed to index, if 7-zip extract fails
		if ($sevenZipExtractInstallProcess.ExitCode -ne 0)
		{
			Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);ERROR - FAILED TO EXTRACT"
			continue
		}
	}
}


# 1. check if 7-zip is installed, exit if not
if (!(Test-Path -path $sevenZipPath))
{
	Write-Error "7-zip is not installed at '$sevenZipPath'"
	Exit 1
}


# 2. Get kgwhdload game pack urls
$kgwhdloadGamePackUrls = GetKGWHDLoadGamePackUrls $kgwhdloadGamePacksPath


# 3. Download kgwhdload game pack urls
DownloadKGWHDLoadGamePackUrls $kgwhdloadGamePacksPath $kgwhdloadGamePackUrls


# 4. Unzip kgwhdload game pack files
UnzipKGWHDLoadGamePackFiles $kgwhdloadGamePacksPath $kgwhdloadGamePackUrls
