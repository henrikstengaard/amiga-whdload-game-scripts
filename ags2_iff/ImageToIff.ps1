# Image To Iff
# ------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-04-04
#
# A PowerShell script to convert an image to iff in ILBM format. The image must be a 4-bpp or 8-bpp indexed image.
# Ported from imgtoiff.py python script by Per Olofsson, https://github.com/MagerValp/ArcadeGameSelector 
# PackBits is originally written by Mikhail Korobov, https://github.com/kmike/packbits

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
function CamgChunk()
{
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

# convert image to planes
function ConvertPlanar($image, $depth)
{
	$rect = [System.Drawing.Rectangle]::FromLTRB(0, 0, $image.width, $image.height)
	$lockmode = [System.Drawing.Imaging.ImageLockMode]::ReadOnly               
	$imageData = $image.LockBits($rect, $lockmode, $image.PixelFormat);
	$dataPointer = $imageData.Scan0;
	$totalBytes = $imageData.Stride * $image.Height;
	$values = New-Object byte[] $totalBytes
	[System.Runtime.InteropServices.Marshal]::Copy($dataPointer, $values, 0, $totalBytes);                
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
		For ($x = 0; $x -lt $imageData.width; $x++)
		{
			$offset = $rowoffset + [math]::floor($x / 8)
			$xmod = 7 - ($x -band 7)
			
			if ($depth -eq 8)
			{
				$p = $values[($y * $image.width) + $x]
			}
			else
			{
				$p = $values[($y * $imageData.Stride) + [math]::floor($x / 2)] -shr $depth
			}
			
			For ($plane = 0; $plane -lt $depth; $plane++)
			{
				$planes[$plane][$offset] = $planes[$plane][$offset] -bor ((($p -shr $plane) -band 1) -shl $xmod)
			}
		}
	}
	
	return $bpr, $planes
}

# finish raw encoding
function FinishRaw($rleStream, $bufferStream)
{
	if ($bufferStream.length -eq 0)
	{
		return
	}

	$rleStream.WriteByte($bufferStream.length - 1)
	$bufferStream.WriteTo($rleStream)
	$bufferStream.SetLength(0)
}

# finish rle encoding
function FinishRle($rleStream, $count, $byte)
{
    $rleStream.WriteByte(256 - ($count - 1))
    $rleStream.WriteByte($byte)
}

# pack using run length encoding
function PackBits($data)
{
    # https://github.com/kmike/packbits
    # 
    # Copyright (c) 2013 Mikhail Korobov
    # 
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    # 
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    # 
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    # THE SOFTWARE.

    if ($data.Count -eq 0)
	{
        return $data
	}

    $rleStream = New-Object System.IO.MemoryStream
    
    if ($data.Count -eq 1)
	{
		$rleStream.WriteByte(0)
		$rleStream.WriteByte($data[0])
		return ,$rleStream.ToArray()
	}
	
    $count = 0
    $maxLength = 127
	
    $bufferStream = New-Object System.IO.MemoryStream

	$state = 'raw'
    
    For ($pos = 0; $pos -lt $data.Count - 1; $pos++)
	{
		$byte = $data[$pos]
	
		if ($byte -eq $data[$pos + 1])
		{
            if ($state -eq 'raw')
			{
                # end of RAW data
                FinishRaw $rleStream $bufferStream
                $state = 'rle'
                $count = 1
			}
            elseif ($state -eq 'rle')
			{
				if ($count -eq $maxLength)
				{
					FinishRle $rleStream $count $byte

					$count = 0
				}
				$count++
			}
		}
		else
		{
            if ($state -eq 'rle')
			{
				$count++
				FinishRle $rleStream $count $byte
				$state = 'raw'
				$count = 0
			}
            elseif($state -eq 'raw')
			{
				if ($bufferStream.length -eq $maxLength)
				{
                    # restart the encoding
					FinishRaw $rleStream $bufferStream
				}
				
				$bufferStream.WriteByte($byte)
			}
		}
	}
	
    if ($state -eq 'raw')
	{
		$bufferStream.WriteByte($byte)
		FinishRaw $rleStream $bufferStream
	}
	else
	{
		$count++
		FinishRle $rleStream $count $byte
	}
	
	return ,$rleStream.ToArray()
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
				$row = PackBits $row
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

# check if image is a 4-bpp or 8-bpp indexed image
if ($image.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format4bppIndexed -and $image.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format8bppIndexed)
{
	Write-Error "Image '$imagePath' is not a 4-bpp or 8-bpp indexed image"
	exit 1
}

# write iff
[System.IO.File]::WriteAllBytes($iffPath, (CreateIlbmImage $image $pack))
