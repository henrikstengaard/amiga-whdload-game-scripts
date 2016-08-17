# Convert Screenshot
# ------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-08-17
#
# A PowerShell script to convert a screenshot for iGame and AGS2 in AGA and OCS mode.
#
# Following software is required for running this script.
#
# Image Magick:
# http://www.imagemagick.org/script/binary-releases.php
# http://www.imagemagick.org/download/binaries/ImageMagick-6.9.3-7-Q8-x64-dll.exe

Param(
	[Parameter(Mandatory=$true)]
	[string]$screenshotFile,
	[Parameter(Mandatory=$true)]
	[string]$outputPath,
	[Parameter(Mandatory=$false)]
	[switch]$noiGameScreenshot,
	[Parameter(Mandatory=$false)]
	[switch]$noAgaScreenshot,
	[Parameter(Mandatory=$false)]
	[switch]$noOcsScreenshot
)


# programs 
$imageMagickConvertPath = "$env:ProgramFiles\ImageMagick-6.9.3-Q8\convert.exe"
$imageToIffPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("ags2_iff\ImageToIff.ps1")


# start process
function StartProcess($fileName, $arguments)
{
	# process info
	$processInfo = New-Object System.Diagnostics.ProcessStartInfo
	$processInfo.FileName = $fileName
	$processInfo.RedirectStandardError = $true
	$processInfo.RedirectStandardOutput = $true
	$processInfo.UseShellExecute = $false
	$processInfo.Arguments = $arguments

	# process
	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = $processInfo
	$process.Start() | Out-Null
	$process.WaitForExit()

	if ($process.ExitCode -ne 0)
	{
		$standardOutput = $process.StandardOutput.ReadToEnd()
		$standardError = $process.StandardError.ReadToEnd()

		if ($standardOutput)
		{
			Write-Error ("StandardOutput: " + $standardOutput)
		}

		if ($standardError)
		{
			Write-Error ("StandardError: " + $standardError)
		}
	}

	return $process.ExitCode	
}


# set temp path using drive Z:\ (ramdisk), if present
if (Test-Path -path "Z:\")
{
	$tempPath = [System.IO.Path]::Combine("Z:\", [System.IO.Path]::GetRandomFileName())
}
else
{
	$tempPath = [System.IO.Path]::Combine("$env:SystemDrive\Temp", [System.IO.Path]::GetRandomFileName())
}


# create temp path
if(!(test-path -path $tempPath))
{
	md $tempPath | Out-Null
}


# make igame screenshot
$imageToIffiGameScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame.iff")

if (!$noiGameScreenshot)
{
	# use ImageMagick to make iGame screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors) and limit colors to 255
	$imageMagickConvertiGameScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame.png")
	$imageMagickConvertiGameArgs = """$screenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 255 ""$imageMagickConvertiGameScreenshotFile"""

	# exit, if ImageMagick fails
	if ((StartProcess $imageMagickConvertPath $imageMagickConvertiGameArgs) -ne 0)
	{
		Write-Error "Failed to run ImageMagick for '$screenshotFile' with arguments '$imageMagickConvertiGameArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertiGameFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertiGameScreenshotFile = $imageMagickConvertiGameFirstScreenshotFile
	}


	# use ImageToIff to convert iGame screenshot to iff
	$imageToIffiGameScreenshotArgs = "-ExecutionPolicy Bypass -file ""$imageToIffPath"" -imagePath ""$imageMagickConvertiGameScreenshotFile"" -iffPath ""$imageToIffiGameScreenshotFile"""

	# exit, if ImageToIff fails
	if ((StartProcess "powershell.exe" $imageToIffiGameScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run ImageToIff for '$imageMagickConvertiGameScreenshotFile' with arguments '$imageToIffiGameScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}
}


# make aga acreenshot
$imageToIffAgs2AgaScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga.iff")

if (!$noAgaScreenshot)
{
	# use ImageMagick to make AGS2 AGA screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors) and limit colors to 200
	$imageMagickConvertAgs2AgaScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga.png")
	$imageMagickConvertAgs2AgaArgs = """$screenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 200 ""$imageMagickConvertAgs2AgaScreenshotFile"""

	# exit, if ImageMagick convert fails
	if ((StartProcess $imageMagickConvertPath $imageMagickConvertAgs2AgaArgs) -ne 0)
	{
		Write-Error "Failed to run ImageMagick convert for '$screenshotFile' with arguments '$imageMagickConvertAgs2AgaArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertAgs2AgaFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertAgs2AgaScreenshotFile = $imageMagickConvertAgs2AgaFirstScreenshotFile
	}


	# use ImageToIff to make AGS2 AGA Game screenshot file
	$imageToIffAgs2AgaScreenshotArgs = "-ExecutionPolicy Bypass -file ""$imageToIffPath"" -imagePath ""$imageMagickConvertAgs2AgaScreenshotFile"" -iffPath ""$imageToIffAgs2AgaScreenshotFile"""

	# exit, if ImageToIff fails
	if ((StartProcess "powershell.exe" $imageToIffAgs2AgaScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run ImageToIff for '$imageMagickConvertAgs2AgaScreenshotFile' with arguments '$imageToIffAgs2AgaScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}
}


# make ocs screenshot
$imageToIffAgs2OcsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs.iff")

if (!$noOcsScreenshot)
{
	# use ImageMagick to make AGS2 OCS screenshot: Resize to 320 x 128 pixels, set bit depth to 4 (16 colors) and limit colors to 11
	$imageMagickConvertAgs2OcsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs.png")
	$imageMagickConvertAgs2OcsArgs = """$screenshotFile"" -resize 320x128! -filter Point -depth 4 -colors 11 ""$imageMagickConvertAgs2OcsScreenshotFile"""

	# exit, if ImageMagick convert fails
	if ((StartProcess $imageMagickConvertPath $imageMagickConvertAgs2OcsArgs) -ne 0)
	{
		Write-Error "Failed to run ImageMagick convert for '$screenshotFile' with arguments '$imageMagickConvertAgs2OcsArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertAgs2OcsFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertAgs2OcsScreenshotFile = $imageMagickConvertAgs2OcsFirstScreenshotFile
	}


	# use ImageToIff to make AGS2 OCS Game screenshot file
	$imageToIffAgs2OcsScreenshotArgs = "-ExecutionPolicy Bypass -file ""$imageToIffPath"" -imagePath ""$imageMagickConvertAgs2OcsScreenshotFile"" -iffPath ""$imageToIffAgs2OcsScreenshotFile"""

	# exit, if ImageToIff fails
	if ((StartProcess "powershell.exe" $imageToIffAgs2OcsScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run ImageToIff for '$imageMagickConvertAgs2OcsScreenshotFile' with arguments '$imageToIffAgs2OcsScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}
}


# create output path
if(!(test-path -path $outputPath))
{
	md $outputPath | Out-Null
}


# screenshot files
$outputScreenshotFile = [System.IO.Path]::Combine($outputPath, "screenshot.png")
$outputiGameScreenshotFile = [System.IO.Path]::Combine($outputPath, "igame.iff")
$outputAgs2AgaScreenshotFile = [System.IO.Path]::Combine($outputPath, "ags2aga.iff")
$outputAgs2OcsScreenshotFile = [System.IO.Path]::Combine($outputPath, "ags2ocs.iff")



# copy screenshots files to output 
Copy-Item $screenshotFile $outputScreenshotFile -force

if (test-path -path $imageToIffiGameScreenshotFile)
{
	Copy-Item $imageToIffiGameScreenshotFile $outputiGameScreenshotFile -force
}

if (test-path -path $imageToIffAgs2AgaScreenshotFile)
{
	Copy-Item $imageToIffAgs2AgaScreenshotFile $outputAgs2AgaScreenshotFile -force
}

if (test-path -path $imageToIffAgs2OcsScreenshotFile)
{
	Copy-Item $imageToIffAgs2OcsScreenshotFile $outputAgs2OcsScreenshotFile -force
}


# remove temp path
remove-item $tempPath -recurse
