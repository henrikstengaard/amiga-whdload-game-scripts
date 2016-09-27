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
	[string]$paletteImagePath,
	[Parameter(Mandatory=$true)]
	[string]$outputImagePath
)

Add-Type -AssemblyName System.Drawing


# resolve paths
$imagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($imagePath)
$paletteImagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($paletteImagePath)
$outputImagePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputImagePath)


# read image
$image = new-object System.Drawing.Bitmap($imagePath)

# read palette image
$paletteImage = new-object System.Drawing.Bitmap($paletteImagePath)


# build palette image color index
$paletteImageColorIndex = @{}

for ($i = 0; $i -lt $paletteImage.Palette.Entries.Count; $i++)
{
    $color = $paletteImage.Palette.Entries[$i]
    $hash = "{0},{1},{2}" -f $color.R, $color.B, $color.G

    if (!$paletteImageColorIndex.ContainsKey($hash))
    {
        $paletteImageColorIndex.Set_Item($hash, $i)
    }
}


# map palette from image to palette image
$paletteMap = @()

$unmappedPaletteColorsCount = 0

for ($i = 0; $i -lt $image.Palette.Entries.Count; $i++)
{
    $color = $image.Palette.Entries[$i]
    $hash = "{0},{1},{2}" -f $color.R, $color.B, $color.G

    if ($paletteImageColorIndex.ContainsKey($hash))
    {
        $paletteMap += $paletteImageColorIndex.Get_Item($hash)
    }
    else
    {
        $unmappedPaletteColorsCount++
    }
}


# exit, if image palette has unmapped colors
if ($unmappedPaletteColorsCount -gt 0)
{
    # dispose images
    $image.Dispose()
    $paletteImage.Dispose()

    Write-Error ("Image '$imagePath' with pixel format '" + $image.PixelFormat + "' has $unmappedPaletteColorsCount unmapped palette colors!")
    exit 1
}


# read image bytes from image
$rect = [System.Drawing.Rectangle]::FromLTRB(0, 0, $image.width, $image.height)
$lockmode = [System.Drawing.Imaging.ImageLockMode]::ReadOnly               
$imageData = $image.LockBits($rect, $lockmode, $image.PixelFormat)
$dataPointer = $imageData.Scan0
$totalBytes = $imageData.Stride * $image.Height
$imageBytes = New-Object byte[] $totalBytes
[System.Runtime.InteropServices.Marshal]::Copy($dataPointer, $imageBytes, 0, $totalBytes)




# map image pixels using palette map
$unmappedImagePixels = 0

for ($i = 0; $i -lt $imageBytes.Count; $i++)
{
    $paletteIndex = $imageBytes[$i]

    # skip pixel, if palette index is out of range from palette map
    if ($paletteIndex -ge $paletteMap.Count)
    {
        $unmappedImagePixels++
        continue
    }

    # change pixel to palette map
    $imageBytes[$i] = $paletteMap[$paletteIndex]
}


# exit, if image unmapped pixels
if ($unmappedImagePixels -gt 0)
{
    # dispose images
    $image.Dispose()
    $paletteImage.Dispose()

    Write-Warning ("Image '$imagePath' with pixel format '" + $image.PixelFormat + "' has $unmappedImagePixels unmapped pixels!")
    exit 1
}


# write mapped image pixels to image
[System.Runtime.InteropServices.Marshal]::Copy($imageBytes, 0, $dataPointer, $imageBytes.Length)
$image.UnlockBits($imageData);


# copy palette from palette image
$image.Palette = $paletteImage.Palette


# save output image
$image.Save($outputImagePath)


# dispose images
$image.Dispose()
$paletteImage.Dispose()