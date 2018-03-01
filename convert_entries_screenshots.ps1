# Convert Entries Screenshots
# ---------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2018-03-01
#
# A PowerShell script to convert existing entries screenshots. Used to generate new igame screenshot in 320x128 and 320x256 resolutions.


Param(
	[Parameter(Mandatory=$true)]
	[string]$screenshotsDir
)

# paths 
$convertScreenshotPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("convert_screenshot.ps1")

# get screenshot files
$screenshotFiles = @()
$screenshotFiles += Get-ChildItem -Path $screenshotsDir -Recurse -Filter 'screenshot.png'

# convert screenshots
Write-Host ("Converting {0} screenshots..." -f $screenshotFiles.Count)
ForEach ($screenshotFile in $screenshotFiles)
{
	# remove old igame screenshot
	$igameScreenshotFile = Join-Path $screenshotFile.Directory -ChildPath "igame.iff"
	if (Test-Path -Path $igameScreenshotFile)
	{
		Remove-Item -Path $igameScreenshotFile -Force
	}

	# convert screenshot
	& $convertScreenshotPath -screenshotFile $screenshotFile.FullName -outputPath $screenshotFile.Directory -noAmsScreenshot
}
Write-Host "Done"