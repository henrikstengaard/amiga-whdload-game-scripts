


# root
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


$whdloadGameSlaveIndexPath = [System.IO.Path]::Combine($scriptPath, "whdownload_games\whdownload_games_index.csv")
$whdloadInstallSlaveIndexPath = [System.IO.Path]::Combine($scriptPath, "whdload_installs\whdload_installs_index.csv")


# simplify name by removing "the" word, special characters and converting roman numbers
function SimplifyName($name)
{
	return $name -replace "[\(\)\&,_\-!':]", " " -replace "the", "" -replace "[-_ ]vii", " 7 " 	-replace "[-_ ]vi", " 6 " -replace "[-_ ]v", " 5 " -replace "[-_ ]iv", " 4 " -replace "[-_ ]iii", " 3 " -replace "[-_ ]ii", " 2 " -replace "[-_ ]i", " 1 " -replace "\s+", " "
}


# make comparable name by simplifying name, removing whitespaces and non-word characters
function MakeComparableName($name)
{
    return ((SimplifyName $name) -replace "\s+", "" -replace "[^\w]", "").ToLower()
}


# read whdload slave index
function ReadWhdloadSlaveIndex($whdloadSlaveIndexFile)
{
	$index = @{}

	ForEach($line in (Get-Content $whdloadSlaveIndexFile | Select-Object -Skip 1))
	{
		$columns = $line -split ";"
		
		$name = MakeComparableName (([System.IO.Path]::GetFileNameWithoutExtension($columns[0])) -split '_' | Select-Object -First 1 )
		#$name = MakeComparableName $columns[1]

		$item = $index.Get_Item($name)
		
		if (!$item)
		{
			$item = @()
		}
		
		$item += , $columns
		
		$index.Set_Item($name, $item)
	}

	return $index
}


# Read whdload games index
Write-Output "Reading whdload game slave index file '$whdloadGameSlaveIndexPath'..."
$whdloadGameSlaves = ReadWhdloadSlaveIndex $whdloadGameSlaveIndexPath
$whdloadGameSlaves.Count


Write-Output "Reading whdload install slave index file '$whdloadInstallSlaveIndexPath'..."
$whdloadInstallSlaves = ReadWhdloadSlaveIndex $whdloadInstallSlaveIndexPath
$whdloadInstallSlaves.Count



# 13. Process whdload game files
ForEach ($whdloadInstallSlaveName in $whdloadInstallSlaves.Keys)
{

	$whdloadGameSlave = $whdloadGameSlaves.Get_Item($whdloadInstallSlaveName)
	
	if (!$whdloadGameSlave)
	{
		#Write-Output $whdloadInstallSlaveName
	}
}


$whdloadInstallSlaves.Keys | where { !$whdloadGameSlaves.ContainsKey($_) } | Sort-Object
