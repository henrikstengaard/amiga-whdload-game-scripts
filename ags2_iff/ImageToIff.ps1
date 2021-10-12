# Image To Iff
# ------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2021-10-08
#
# A PowerShell script to convert an image to iff in ILBM format. The image must be a 4-bpp or 8-bpp indexed image.
# Ported from imgtoiff.py python script by Per Olofsson, https://github.com/MagerValp/ArcadeGameSelector 
# c# getpixel from https://stackoverflow.com/questions/51071944/how-can-i-work-with-1-bit-and-4-bit-images
# Pack bits Compress from https://commons.apache.org/proper/commons-imaging/jacoco/org.apache.commons.imaging.common/PackBits.java.html

Param(
	[Parameter(Mandatory=$true)]
	[string]$imagePath,
	[Parameter(Mandatory=$true)]
	[string]$iffPath,
	[Parameter(Mandatory=$false)]
	[int]$pack = 1
)

Add-Type -AssemblyName System.Drawing

# get little endian unsigned short bytes
function GetLittleEndianUnsignedShortBytes([uint16]$value)
{
	$bytes =[System.BitConverter]::GetBytes($value)
	[Array]::Reverse($bytes)
	return ,$bytes 
}

# get little endian unsigned long bytes
function GetLittleEndianUnsignedLongBytes([uint32]$value)
{
	$bytes =[System.BitConverter]::GetBytes($value)
	[Array]::Reverse($bytes)
	return ,$bytes
}

# create iff chunk with id and data
function IffChunk($id, $data)
{
	$chunkStream = New-Object System.IO.MemoryStream
	$chunkWriter = New-Object System.IO.BinaryWriter($chunkStream)

	$chunkLength = $data.Count

	if ($chunkLength -band 1)
	{
		$chunkLength++
		$appendZero = $true
	}
	
	$chunkWriter.Write([System.Text.Encoding]::ASCII.GetBytes($id))
	$chunkWriter.Write((GetLittleEndianUnsignedLongBytes $chunkLength))
	$chunkWriter.Write($data)

	if ($appendZero)
	{
		$chunkWriter.Write([byte]0)
	}
	
	return ,$chunkStream.ToArray()
}

# create bitmap header chunk
function BitMapHeaderChunk($image, $depth)
{
	$bmhdStream = New-Object System.IO.MemoryStream
	$bmhdWriter = New-Object System.IO.BinaryWriter($bmhdStream)

	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes $image.Width)) # width
	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes $image.Height)) # height
	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes 0)) # x
	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes 0)) # y
	$bmhdWriter.Write([byte]$depth) # planes
	$bmhdWriter.Write([byte]0) # mask
	$bmhdWriter.Write([byte]$pack) # tcomp
	$bmhdWriter.Write([byte]0) # pad1
	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes 0)) # transparent color
	$bmhdWriter.Write([byte]60) # xAspect
	$bmhdWriter.Write([byte]60) # yAspect
	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes $image.Width)) # Lpage
	$bmhdWriter.Write((GetLittleEndianUnsignedShortBytes $image.Height)) # Hpage

	return IffChunk 'BMHD' $bmhdStream.ToArray()
}

# create map chunk
function ColorMapChunk($image, $depth)
{
	$cmapStream = New-Object System.IO.MemoryStream

	ForEach ($color in $image.Palette.Entries)
	{
		if ($depth -eq 8)
		{
			$cmapStream.WriteByte($color.R)
			$cmapStream.WriteByte($color.G)
			$cmapStream.WriteByte($color.B)
		}
		else
		{
			$cmapStream.WriteByte((($color.R -band 0xf0) -bor ($color.R -shr $depth)))
			$cmapStream.WriteByte((($color.G -band 0xf0) -bor ($color.G -shr $depth)))
			$cmapStream.WriteByte((($color.B -band 0xf0) -bor ($color.B -shr $depth)))
		}
	}

	return IffChunk 'CMAP' $cmapStream.ToArray()
}

# create camg chunk
function CamgChunk($image, $depth)
{
	$cmagStream = New-Object System.IO.MemoryStream
	
    #$cmagWriter = New-Object System.IO.BinaryWriter($cmagStream)
    #$cmagWriter.WriteByte((GetLittleEndianUnsignedLongBytes $depth))

	#return IffChunk 'CAMG' $cmagStream.ToArray()
    return ,$cmagStream.ToArray()

    # if mode is not None:
        # camg = iff_chunk("CAMG", struct.pack(">L", mode))
    # else:
        # camg = ""
            # //    uint viewmodes = input.ReadBEUInt32();

            # //    bytesloaded = size;
            # //    if ((viewmodes & 0x0800) > 0)
            # //        flagHAM = true;
            # //    if ((viewmodes & 0x0080) > 0)
            # //        flagEHB = true;
            # //}

}

function GetPaletteIndex($imageBytes, $stride, $height, $depth, $x, $y)
{
    # Get the bit index of the specified pixel
    #$biti = (if ($stride -gt 0) { $y } else { $y - $height + 1}) * $stride * 8 + $x * $depth
    $offset = $y
    if ($stride -lt 0)
    {
        $offset = ($y - $height + 1)
    }

    $biti = ($offset * $stride * 8) + ($x * $depth)

    # Get the byte index
    $i = [math]::floor($biti / 8)

    # Get color components count
    #$cCount = [math]::floor($depth / 8)

    #$dataLength = $imageBytes.Length - $cCount

    #Write-Host $biti, $i

    #if ($i -gt $dataLength)
    #{
    #    throw 'IndexOutOfRangeException'
    #}

#    if ($image.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format4bppIndexed -and $image.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format8bppIndexed)

    # if (ColorDepth == 32) // For 32 bpp get Red, Green, Blue and Alpha
    # {
    #     byte b = _imageData[i];
    #     byte g = _imageData[i + 1];
    #     byte r = _imageData[i + 2];
    #     byte a = _imageData[i + 3]; // a
    #     clr = Color.FromArgb(a, r, g, b);
    # }
    # if (ColorDepth == 24) // For 24 bpp get Red, Green and Blue
    # {
    #     byte b = _imageData[i];
    #     byte g = _imageData[i + 1];
    #     byte r = _imageData[i + 2];
    #     clr = Color.FromArgb(r, g, b);
    # }
    $c = 0
    if ($depth -eq 8)
    {
        $c = $imageBytes[$i]
    }
    if ($depth -eq 4)
    {
        if ($biti % 8 -eq 0)
        {
            $c = $imageBytes[$i] -shr 4
        }
        else
        {
            $c = $imageBytes[$i] -band 0x0F
        }
    }
    if ($depth -eq 1)
    {
        $bbi = $biti % 8
        $mask = $bbi -shl 1
        $c = if (($imageBytes[$i] -band $mask) -ne 0) { 1 } else { 0 }
    }

    return $c
}


# convert image to planes
function ConvertPlanar($image, $depth)
{
	$rect = [System.Drawing.Rectangle]::FromLTRB(0, 0, $image.width, $image.height)
	$lockmode = [System.Drawing.Imaging.ImageLockMode]::ReadOnly               
	$imageData = $image.LockBits($rect, $lockmode, $image.PixelFormat);
	$dataPointer = $imageData.Scan0;

    $totalBytes = $imageData.Stride * $image.Height;
	$imageBytes = New-Object byte[] $totalBytes
	[System.Runtime.InteropServices.Marshal]::Copy($dataPointer, $imageBytes, 0, $totalBytes);                
	$image.UnlockBits($imageData);

    # Calculate dimensions.
    $planeWidth = [math]::floor((($image.width + 15) / 16)) * 16
    $bpr = [math]::floor($planeWidth / 8)
    $planeSize = $bpr * $image.height
	
	$planes = New-Object System.Collections.Generic.List[System.Object]
	
	For ($plane = 0; $plane -lt $depth; $plane++)
	{
		$planes.Add((New-Object 'byte[]' $planeSize))
	}

	For ($y = 0; $y -lt $image.height; $y++)
	{
		$rowoffset = $y * $bpr
		For ($x = 0; $x -lt $image.width; $x++)
		{
			$offset = $rowoffset + [math]::floor($x / 8)
			$xmod = 7 - ($x -band 7)
			
            $paletteIndex = GetPaletteIndex $imageBytes $imageData.Stride $image.Height $depth $x $y
			
			For ($plane = 0; $plane -lt $depth; $plane++)
			{
				$planes[$plane][$offset] = $planes[$plane][$offset] -bor ((($paletteIndex -shr $plane) -band 1) -shl $xmod)
			}
		}
	}
	
	return $bpr, $planes
}

function FindNextDuplicate($bytes, $start) {
    #// int last = -1;
    if ($start -ge $bytes.length) {
        return -1
    }

    $prev = $bytes[$start]

    for ($i = $start + 1; $i -lt $bytes.length; $i++) {
        $b = $bytes[$i]

        if ($b -eq $prev) {
            return $i - 1
        }

        $prev = $b
    }

    return -1
}

function FindRunLength($bytes, $start)
{
    $b = $bytes[$start]

    $i = 0

    for ($i = $start + 1; ($i -lt $bytes.length) -and ($bytes[$i] -eq $b); $i++)
    {
        # do nothing
    }

    return $i - $start
}

function Compress($bytes)
{
    $baos = New-Object System.IO.MemoryStream
    # max length 1 extra byte for every 128
    $ptr = 0;
    while ($ptr -lt $bytes.length) {
        $dup = FindNextDuplicate $bytes $ptr

        if ($dup -eq $ptr) {
            # write run length
            $len = FindRunLength $bytes $dup
            $actualLen = [Math]::min($len, 128)
            $baos.WriteByte(256-($actualLen - 1))
            $baos.WriteByte($bytes[$ptr])
            $ptr += $actualLen
        } else {
            # write literals
            $len = $dup - $ptr

            # if ($dup -gt 0) {
            #     $runlen = FindRunLength $bytes $dup
            #     if ($runlen -lt 3) {
            #         # may want to discard next run.
            #         $nextptr = $ptr + $len + $runlen
            #         $nextdup = FindNextDuplicate $bytes $nextptr
            #         if ($nextdup -ne $nextptr) {
            #             # discard 2-byte run
            #             $dup = $nextdup
            #             $len = $dup - $ptr
            #         }
            #     }
            # }

            if ($dup -lt 0) {
                $len = $bytes.length - $ptr
            }
            $actualLen = [Math]::min($len, 128)

            $baos.WriteByte($actualLen - 1)
            for ($i = 0; $i -lt $actualLen; $i++) {
                $baos.WriteByte($bytes[$ptr])
                $ptr++
            }
        }
    }
    return ,$baos.ToArray()
}


# create body chunk
function CreateBodyChunk($image, $depth, $pack)
{
    # Get planar bitmap.
	$bpr, $planes = ConvertPlanar $image $depth

	$bodyStream = New-Object System.IO.MemoryStream
	
	For ($y = 0; $y -lt $image.height; $y++)
	{
		For ($plane = 0; $plane -lt $depth; $plane++)
		{
			$row = New-Object 'byte[]' $bpr
			
			[Array]::Copy($planes[$plane], $y * $bpr, $row, 0, $bpr)

			if ($pack)
			{
				$row = Compress $row
			}
			
			$bodyStream.Write($row, 0, $row.Count)
		}
	}

    return IffChunk 'BODY' $bodyStream.ToArray()
}

# cfreate ilbm image
function CreateIlbmImage($image, $pack)
{
	$depth = [System.Drawing.Image]::GetPixelFormatSize($image.PixelFormat)

	$ilbmStream = New-Object System.IO.MemoryStream
	$ilbmWriter = New-Object System.IO.BinaryWriter($ilbmStream)

	$ilbmWriter.Write([System.Text.Encoding]::ASCII.GetBytes('ILBM'))
	$ilbmWriter.Write((BitMapHeaderChunk $image $depth))
	$ilbmWriter.Write((ColorMapChunk $image $depth))
	$ilbmWriter.Write((CamgChunk $image $depth))
	$ilbmWriter.Write((CreateBodyChunk $image $depth $pack))
    
    return IffChunk 'FORM' $ilbmStream.ToArray()
} 

#UNUSED $image2 = ResizeImage $image1 100 100
function ResizeImage($image, $width, $height)
{
	$resizedImage = new-object System.Drawing.Bitmap $width,$height
	$graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
	#$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality;
	#$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	#$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality;
	$graphics.DrawImage($image, 0, 0, $width, $height)
	return $resizedImage
}


# check if image path exists
if (!(test-path -path $imagePath))
{
	Write-Error "Image '$imagePath' doesn't exist"
	exit 1
}


# read image
$image = new-object System.Drawing.Bitmap($imagePath)

# TODO convert image to 4 or 8 bpp indexed
# $colors = @{}

# for ($y = 0; $y -lt $image.Height; $y++)
# {
#     for ($x = 0; $x -lt $image.Height; $x++)
#     {
#         $color = $image.GetPixel($x, $y)

#         $hash = "{0},{1},{2}" -f $color.R, $color.B, $color.G

#         if (!$colors.ContainsKey($hash))
#         {
#             $colors.Set_Item($hash, $color)
#         }
#     }
# }


# check if image is a 4-bpp or 8-bpp indexed image
if ($image.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format4bppIndexed -and $image.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format8bppIndexed)
{
	# dispose image
	$image.Dispose()

	Write-Error ("Image '$imagePath' with pixel format '" + $image.PixelFormat + "'. Only 4-bpp or 8-bpp indexed image is supported!")
	exit 1
}

# write iff
[System.IO.File]::WriteAllBytes($iffPath, (CreateIlbmImage $image $pack))

# dispose image
$image.Dispose()