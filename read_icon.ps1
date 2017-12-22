# http://krashan.ppa.pl/articles/amigaicons/

# convert bytes from little endian to int16
function ConvertToInt16([byte[]]$bytes)
{
	[Array]::Reverse($bytes)
	return [System.BitConverter]::ToInt16($bytes, 0)
}

# convert bytes from little endian to int32
function ConvertToInt32([byte[]]$bytes)
{
	[Array]::Reverse($bytes)
	return [System.BitConverter]::ToInt32($bytes, 0)
}

# convert bytes from little endian to uint16
function ConvertToUInt16([byte[]]$bytes)
{
	[Array]::Reverse($bytes)
	return [System.BitConverter]::ToUInt16($bytes, 0)
}

# convert bytes from little endian to uint32
function ConvertToUInt32([byte[]]$bytes)
{
	[Array]::Reverse($bytes)
	return [System.BitConverter]::ToUInt32($bytes, 0)
}


$iconFile = 'c:\Work\First Realize\amiga-whdload-game-scripts\whdload_packs\eab_whdload_packs_3.0\Games_WHDLoad\W\Wings\Wings.info'

# open hdf file stream and binary reader
$stream = New-Object System.IO.FileStream $iconFile, 'Open', 'Read', 'Read'
$binaryReader = New-Object System.IO.BinaryReader($stream)

if (!((ConvertToUInt16 $binaryReader.ReadBytes(2)) -eq 0xE310 -and (ConvertToUInt16 $binaryReader.ReadBytes(2)) -eq 1))
{
	throw "invalid icon file"
}

$nextGadget = ConvertToUInt32 $binaryReader.ReadBytes(4)
$leftEdge = ConvertToInt16 $binaryReader.ReadBytes(2)
$rightEdge = ConvertToInt16 $binaryReader.ReadBytes(2)
$width = ConvertToUInt16 $binaryReader.ReadBytes(2)
$height = ConvertToUInt16 $binaryReader.ReadBytes(2)
$flags = ConvertToUInt16 $binaryReader.ReadBytes(2)
$activation = ConvertToUInt16 $binaryReader.ReadBytes(2)
$gadgetType = ConvertToUInt16 $binaryReader.ReadBytes(2)
$gadgetRender = ConvertToUInt32 $binaryReader.ReadBytes(4)
$selectRender = ConvertToUInt32 $binaryReader.ReadBytes(4)

$gadgetText = ConvertToUInt32 $binaryReader.ReadBytes(4)
$mutualExclude = ConvertToUInt32 $binaryReader.ReadBytes(4)
$specialInfo = ConvertToUInt32 $binaryReader.ReadBytes(4)
$gadgetId = ConvertToUInt16 $binaryReader.ReadBytes(2)
$userData = ConvertToUInt32 $binaryReader.ReadBytes(4)
$type = $binaryReader.ReadByte
$padding = $binaryReader.ReadByte
$defaultTool = ConvertToUInt32 $binaryReader.ReadBytes(4)
$toolTypes = ConvertToUInt32 $binaryReader.ReadBytes(4)
$currentX = ConvertToInt32 $binaryReader.ReadBytes(4)
$currentY = ConvertToInt32 $binaryReader.ReadBytes(4)
$drawerData = ConvertToUInt32 $binaryReader.ReadBytes(4)
$toolWindow = ConvertToUInt32 $binaryReader.ReadBytes(4)
$stackSize = ConvertToUInt32 $binaryReader.ReadBytes(4)

$leftEdge
$rightEdge
$width
$height
$currentX
$currentY

exit

$first = ConvertToUInt32 $binaryReader.ReadBytes(4)
$last = ConvertToUInt32 $binaryReader.ReadBytes(4)

Write-Output ("Table Size: {0}" -f $x)
Write-Output ("First: {0}" -f $first)
Write-Output ("Last: {0}" -f $last)

for ($i = $first; $i -le $last; $i++)
{
    $t = ConvertToUInt32 $binaryReader.ReadBytes(4)
    Write-Output ("Hunk {0}: {1} longwords" -f $i, $t)
}

$hunkId = ConvertToUInt32 $binaryReader.ReadBytes(4)
Write-Output ("Hunk Id: {0}" -f $hunkId)


# close and dispose binary reader and stream
$binaryReader.Close()
$binaryReader.Dispose()
$stream.Close()
$stream.Dispose()