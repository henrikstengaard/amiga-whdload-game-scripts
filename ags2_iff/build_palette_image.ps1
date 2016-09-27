# Build Palette Image
# -------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-09-27
#
# A powershell script to build a palette image with a pixel to represent each color in the images palette.

Param(
	[Parameter(Mandatory=$true)]
	[string]$imagePath,
	[Parameter(Mandatory=$true)]
	[string]$paletteImagePath
)

Add-Type -AssemblyName System.Drawing


# read image
$image = new-object System.Drawing.Bitmap($imagePath)


# make new palette image with width set to number of colors in palette and height of 1 pixel
$paletteImage = new-object System.Drawing.Bitmap($image.Palette.Entries.Count, 1, [System.Drawing.Imaging.PixelFormat]::Format8bppIndexed)


# read palette image bytes
$rect = [System.Drawing.Rectangle]::FromLTRB(0, 0, $paletteImage.width, $paletteImage.height)
$lockmode = [System.Drawing.Imaging.ImageLockMode]::ReadOnly               
$imageData = $paletteImage.LockBits($rect, $lockmode, $paletteImage.PixelFormat)
$dataPointer = $imageData.Scan0
$totalBytes = $imageData.Stride * $paletteImage.Height
$imageBytes = New-Object byte[] $totalBytes
[System.Runtime.InteropServices.Marshal]::Copy($dataPointer, $imageBytes, 0, $totalBytes)


# set pixels with palette colors
for ($i = 0; $i -lt $paletteImage.Width; $i++)
{
    $imageBytes[$i] = $i
}


# write palette image bytes
[System.Runtime.InteropServices.Marshal]::Copy($imageBytes, 0, $dataPointer, $imageBytes.Length)
$paletteImage.UnlockBits($imageData);


# copy palette from image to palette image
$paletteImage.Palette = $image.Palette


# save palette image
$paletteImage.Save($paletteImagePath)