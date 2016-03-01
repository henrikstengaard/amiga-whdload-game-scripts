# Download WHDLoad Installs
# -------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-03-01
#
# A PowerShell script to download all whdload installs from www.whdload.de.

$whdloadInstallsPath = "whdload_installs"
$installsPath = [System.IO.Path]::Combine($whdloadInstallsPath, "installs")

# Get whdload install urls by downloading html and use regex to find install urls
function GetWhdloadInstallUrls($outputPath)
{
	if(!(Test-Path -Path $outputPath))
	{
		md $outputPath | Out-Null
	}		

	$whdloadBaseUrl = 'http://www.whdload.de/games/';

	$whdloadInstallsHtmlPath = [System.IO.Path]::Combine($outputPath, "whdload_installs.html")
	
	if (Test-Path -Path $whdloadInstallsHtmlPath)
	{
		$whdloadInstallsHtml = [System.IO.File]::ReadAllText($whdloadInstallsHtmlPath)
	}
	else
	{
		$whdloadInstallsUrl = $whdloadBaseUrl + 'all.html'

		Write-Host "Downloading whdload installs html...";

		$webclient = New-Object System.Net.WebClient
		$whdloadInstallsHtml = [System.Text.Encoding]::UTF8.GetString($webclient.DownloadData($whdloadInstallsUrl))
		
		$whdloadInstallsHtml | Out-File $whdloadInstallsHtmlPath
	}

	$whdloadInstallUrls = $whdloadInstallsHtml | Select-String -Pattern "<tr><td\s+align=center><a\s+href=""([^""<>]+\.lha)" -AllMatches | % { $_.Matches } | % { $whdloadBaseUrl + $_.Groups[1].Value }

	Write-Host "$($whdloadInstallUrls.Count) whdload install urls found in html"
	
	return $whdloadInstallUrls
}

# Download whdload installs to output path
function DownloadWhdloadInstallsFromUrls($outputPath, $whdloadInstallUrls)
{
	if(!(Test-Path -Path $outputPath))
	{
		md $outputPath | Out-Null
	}		
	
	$webclient = New-Object System.Net.WebClient

	For ($i = 0; $i -lt $whdloadInstallUrls.Count; $i++)
	{
		$whdloadInstallUrl = $whdloadInstallUrls[$i]
	
		$whdloadInstallFileName = [System.IO.Path]::GetFileName($whdloadInstallUrl)
		$whdloadInstallFile = [System.IO.Path]::Combine($outputPath, $whdloadInstallFileName)

		if (Test-Path -Path $whdloadInstallFile)
		{
			continue;
		}

		Write-Host -NoNewline "Downloading '$whdloadInstallFileName' ($($i + 1) / $($whdloadInstallUrls.Count))...                                `r"
		
		Start-Sleep -s 1
		
		$webclient.DownloadFile($whdloadInstallUrl, $whdloadInstallFile)
	}
	
	Write-Host ""
}

# 1. Get whdload install urls
$whdloadInstallUrls = GetWhdloadInstallUrls $whdloadInstallsPath

# 2. Download whdload installs from urls
DownloadWhdloadInstallsFromUrls $installsPath $whdloadInstallUrls
