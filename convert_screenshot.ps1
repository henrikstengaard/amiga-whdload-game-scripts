# Convert Screenshot
# ------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2017-12-22
#
# A PowerShell script to convert a screenshot for iGame and AGS2 in AGA and OCS mode.
#
# Following software is required for running this script.
#
# Image Magick:
# https://www.imagemagick.org/script/binary-releases.php
# https://www.imagemagick.org/download/binaries/ImageMagick-7.0.7-4-Q8-x64-dll.exe
#
# XnView with NConvert
# http://www.xnview.com/en/xnview/#downloads
# http://download3.xnview.com/XnView-win-full.exe
#
# Python for imgtoiff:
# https://www.python.org/downloads/
# https://www.python.org/ftp/python/2.7.14/python-2.7.14.msi
# 
# Pillow for imgtoiff:
# https://pypi.python.org/pypi/Pillow/2.7.0
# https://pypi.python.org/packages/68/c6/43a4e50bd9b1f3b69bda76c466c2fdb0ab2a70159a246ccd0169b0abb374/Pillow-2.7.0.win32-py2.7.exe#md5=a776412924049796bf34e8fa7af680db


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
	[switch]$noOcsScreenshot,
	[Parameter(Mandatory=$false)]
	[switch]$noAmsScreenshot
)


# programs 
$nconvertPath = "${Env:ProgramFiles(x86)}\XnView\nconvert.exe"
$pythonFile = "c:\Python27\python.exe"
$imageToIffPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("ags2_iff\ImageToIff.ps1")
$imgToIffAgaPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("ags2_iff\imgtoiff-aga.py")
$imgToIffOcsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("ags2_iff\imgtoiff-ocs.py")
$amsPaletteImagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("ags2_iff\AMS_palette.png")
$mapImagePalettePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("ags2_iff\map_image_palette.ps1")


# get image magick directory from program files
$imageMagickDirectory = Get-ChildItem $env:ProgramFiles | Where-Object { $_.Name -match 'ImageMagick' } | Select-Object -First 1

# fail, if image magick directory doesn't exist
if (!$imageMagickDirectory)
{
	Write-Error "Error: Image Magick doesn't exist in program files '$env:ProgramFiles'!"
	exit 1
}

# image magick v7 file 
$imageMagickFile = Join-Path -Path $imageMagickDirectory.FullName -ChildPath 'magick.exe'

# check if image magick v6 file exist, if image magick v7 doesn't exist
if (!(Test-Path -path $imageMagickFile))
{
    $imageMagickFile = Join-Path -Path $imageMagickDirectory.FullName -ChildPath 'convert.exe'

    if (!(Test-Path -path $imageMagickFile))
    {
        Write-Error "Error: Image Magick 'magick.exe' or 'convert.exe' file doesn't exist!"
        exit 1
    }
}


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


# make temp png screenshot file
$tempScreenshotFile = [System.IO.Path]::Combine($tempPath, "screenshot.png")
$tempScreenshotArgs = "-out png -o ""$tempScreenshotFile"" ""$screenshotFile"""

# exit, if nconvert fails
if ((StartProcess $nconvertPath $tempScreenshotArgs) -ne 0)
{
	Write-Error "Failed to run '$nconvertPath' for '$screenshotFile' with arguments '$tempScreenshotArgs'"
	remove-item $tempPath -recurse
	exit 1
}


# make igame screenshot
$iGameScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame.iff")

if (!$noiGameScreenshot)
{
	# use ImageMagick to make iGame screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors) and limit colors to 255
	$imageMagickConvertiGameScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame.png")
	$imageMagickConvertiGameArgs = """$tempScreenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 255 ""$imageMagickConvertiGameScreenshotFile"""

	# exit, if ImageMagick fails
	if ((StartProcess $imageMagickFile $imageMagickConvertiGameArgs) -ne 0)
	{
		Write-Error "Failed to run '$imageMagickFile' for '$tempScreenshotFile' with arguments '$imageMagickConvertiGameArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertiGameFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "igame-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertiGameScreenshotFile = $imageMagickConvertiGameFirstScreenshotFile
	}


	# use nconvert to make iGame screenshot file
	$nconvertiGameScreenshotArgs = "-out iff -c 1 -o ""$iGameScreenshotFile"" ""$imageMagickConvertiGameScreenshotFile"""
	if ((StartProcess $nconvertPath $nconvertiGameScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run '$nconvertPath' for '$imageMagickConvertiGameScreenshotFile' with arguments '$nconvertiGameScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}
}


# make aga acreenshot
$ags2AgaScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga.iff")

if (!$noAgaScreenshot)
{
	# use ImageMagick to make AGS2 AGA screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors) and limit colors to 200
	$imageMagickConvertAgs2AgaScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga.png")
	$imageMagickConvertAgs2AgaArgs = """$tempScreenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 200 ""$imageMagickConvertAgs2AgaScreenshotFile"""

	# exit, if ImageMagick convert fails
	if ((StartProcess $imageMagickFile $imageMagickConvertAgs2AgaArgs) -ne 0)
	{
		Write-Error "Failed to run '$imageMagickFile' convert for '$tempScreenshotFile' with arguments '$imageMagickConvertAgs2AgaArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertAgs2AgaFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2aga-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertAgs2AgaScreenshotFile = $imageMagickConvertAgs2AgaFirstScreenshotFile
	}


	# use imgtoiff-aga to make AGS2 AGA Game screenshot file
	$imgToIffAgs2AgaScreenshotArgs = """$imgToIffAgaPath"" --aga --pack 1 ""$imageMagickConvertAgs2AgaScreenshotFile"" ""$ags2AgaScreenshotFile"""

	if ((StartProcess $pythonFile $imgToIffAgs2AgaScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run '$pythonFile' for '$imageMagickConvertAgs2AgaScreenshotFile' with arguments '$imgToIffAgs2AgaScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# # use ImageToIff to make AGS2 AGA Game screenshot file
	# $imageToIffAgs2AgaScreenshotArgs = "-ExecutionPolicy Bypass -file ""$imageToIffPath"" -imagePath ""$imageMagickConvertAgs2AgaScreenshotFile"" -iffPath ""$imageToIffAgs2AgaScreenshotFile"""

	# # exit, if ImageToIff fails
	# if ((StartProcess "powershell.exe" $imageToIffAgs2AgaScreenshotArgs) -ne 0)
	# {
	# 	Write-Error "Failed to run ImageToIff for '$imageMagickConvertAgs2AgaScreenshotFile' with arguments '$imageToIffAgs2AgaScreenshotArgs'"
	# 	remove-item $tempPath -recurse
	# 	exit 1
	# }
}


# make ocs screenshot
$ags2OcsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs.iff")

if (!$noOcsScreenshot)
{
	# use ImageMagick to make AGS2 OCS screenshot: Resize to 320 x 128 pixels, set bit depth to 4 (16 colors) and limit colors to 11
	$imageMagickConvertAgs2OcsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs.png")
	$imageMagickConvertAgs2OcsArgs = """$tempScreenshotFile"" -resize 320x128! -filter Point -depth 4 -colors 11 ""$imageMagickConvertAgs2OcsScreenshotFile"""

	# exit, if ImageMagick convert fails
	if ((StartProcess $imageMagickFile $imageMagickConvertAgs2OcsArgs) -ne 0)
	{
		Write-Error "Failed to run '$imageMagickFile' convert for '$tempScreenshotFile' with arguments '$imageMagickConvertAgs2OcsArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertAgs2OcsFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "ags2ocs-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertAgs2OcsScreenshotFile = $imageMagickConvertAgs2OcsFirstScreenshotFile
	}


	# use imgtoiff-ocs to make AGS2 OCS Game screenshot file
	$imgToIffAgs2OcsScreenshotArgs = """$imgToIffOcsPath"" --ocs --pack 1 ""$imageMagickConvertAgs2OcsScreenshotFile"" ""$ags2OcsScreenshotFile"""

	if ((StartProcess $pythonFile $imgToIffAgs2OcsScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run '$pythonFile' for '$imageMagickConvertAgs2OcsScreenshotFile' with arguments '$imgToIffAgs2OcsScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# # use ImageToIff to make AGS2 OCS Game screenshot file
	# $imageToIffAgs2OcsScreenshotArgs = "-ExecutionPolicy Bypass -file ""$imageToIffPath"" -imagePath ""$imageMagickConvertAgs2OcsScreenshotFile"" -iffPath ""$imageToIffAgs2OcsScreenshotFile"""

	# # exit, if ImageToIff fails
	# if ((StartProcess "powershell.exe" $imageToIffAgs2OcsScreenshotArgs) -ne 0)
	# {
	# 	Write-Error "Failed to run ImageToIff for '$imageMagickConvertAgs2OcsScreenshotFile' with arguments '$imageToIffAgs2OcsScreenshotArgs'"
	# 	remove-item $tempPath -recurse
	# 	exit 1
	# }
}


# make ams screenshot
$amsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ams.iff")

if (!$noAmsScreenshot)
{
	# use ImageMagick to make AMS screenshot: Resize to 320 x 128 pixels, set bit depth to 8 (255 colors) and limit colors to 200, dither and remap AMS palette
	$imageMagickConvertAmsScreenshotFile = [System.IO.Path]::Combine($tempPath, "ams.png")
	$imageMagickConvertAmsArgs = """$tempScreenshotFile"" -resize 320x128! -filter Point -depth 8 -colors 200 +dither -map ""$amsPaletteImagePath"" PNG8:""$imageMagickConvertAmsScreenshotFile"""

	# exit, if ImageMagick convert fails
	if ((StartProcess $imageMagickFile $imageMagickConvertAmsArgs) -ne 0)
	{
		Write-Error "Failed to run '$imageMagickFile' convert for '$tempScreenshotFile' with arguments '$imageMagickConvertAmsArgs'"
		remove-item $tempPath -recurse
		exit 1
	}

	# use first screenshot, image magick converted an animated gif
	$imageMagickConvertAmsFirstScreenshotFile = [System.IO.Path]::Combine($tempPath, "ams-0.png")
	if (test-path -path $imageMagickConvertiGameFirstScreenshotFile)
	{
		$imageMagickConvertAmsScreenshotFile = $imageMagickConvertAmsFirstScreenshotFile
	}

	# use map image palette to map palette screenshot palette to AMS palette
	$amsMappedScreenshotFile = [System.IO.Path]::Combine($tempPath, "ams-mapped.png")
	$mapImagePaletteAmsScreenshotArgs = "-ExecutionPolicy Bypass -file ""$mapImagePalettePath"" -imagePath ""$imageMagickConvertAmsScreenshotFile"" ""$amsPaletteImagePath"" -outputImagePath ""$amsMappedScreenshotFile"""
	if ((StartProcess "powershell.exe" $mapImagePaletteAmsScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run 'powershell.exe' for '$imageMagickConvertAmsScreenshotFile' with arguments '$mapImagePaletteAmsScreenshotArgs'"
		remove-item $tempPath -recurse
		exit 1
	}


	# use nconvert to make AMS screenshot file
	$nconvertAmsScreenshotArgs = "-out iff -c 1 -o ""$amsScreenshotFile"" ""$amsMappedScreenshotFile"""
	if ((StartProcess $nconvertPath $nconvertAmsScreenshotArgs) -ne 0)
	{
		Write-Error "Failed to run '$nconvertPath' for '$imageMagickConvertAmsScreenshotFile' with arguments '$nconvertAmsScreenshotArgs'"
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
$outputAmsScreenshotFile = [System.IO.Path]::Combine($outputPath, "ams.iff")


# copy screenshots files to output 
Copy-Item $tempScreenshotFile $outputScreenshotFile -force

if (test-path -path $iGameScreenshotFile)
{
	Copy-Item $iGameScreenshotFile $outputiGameScreenshotFile -force
}

if (test-path -path $ags2AgaScreenshotFile)
{
	Copy-Item $ags2AgaScreenshotFile $outputAgs2AgaScreenshotFile -force
}

if (test-path -path $ags2OcsScreenshotFile)
{
	Copy-Item $ags2OcsScreenshotFile $outputAgs2OcsScreenshotFile -force
}

if (test-path -path $amsScreenshotFile)
{
	Copy-Item $amsScreenshotFile $outputAmsScreenshotFile -force
}


# remove temp path
remove-item $tempPath -recurse
