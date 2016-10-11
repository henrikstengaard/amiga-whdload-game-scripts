# Build Extra Games Screenshots
# -----------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-10-11
#
# A PowerShell script to build extra games screenshots.


# resolve paths
$convertScreenshotPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("convert_screenshot.ps1")
$screenshotDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("extra_games\Screenshots")

# get screenshot files
$screenshotFiles = Get-ChildItem -Path $screenshotDir -filter *.png

# convert screenshots
foreach ($screenshotFile in $screenshotFiles)
{
	$screenshotOutputDir = [System.IO.Path]::Combine($screenshotDir, [System.IO.Path]::GetFileNameWithoutExtension($screenshotFile.FullName))

	if(!(Test-Path -Path $screenshotOutputDir))
	{
		md $screenshotOutputDir | Out-Null
	}

	& $convertScreenshotPath -screenshotFile $screenshotFile.FullName -outputPath $screenshotOutputDir
}




