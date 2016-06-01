

$outputPath = "whdload_installs_index"

function RebuildWhdloadIndexFromFiles($outputPath, $whdloadArchiveFiles)
{
	$whdloadIndexPath = [System.IO.Path]::Combine($outputPath, "whdload_index_rebuild.csv")

	if(test-path -path $whdloadIndexPath)
	{
		Remove-Item $whdloadIndexPath
	}	
	
	# add header to index
	Add-Content $whdloadIndexPath "Whdload Archive File;Whdload Slave File;Whdload Name"

	# get whdload text files from temp path
	$whdloadTextFiles = Get-ChildItem -recurse -filter *.txt -Path $outputPath

	# add no slaves to index, if no slaves exist in temp path
	if (!$whdloadTextFiles)
	{
		Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);ERROR - NO SLAVES"
	}
	
	ForEach ($whdloadSlaveFile in $whdloadSlaveFiles)
	{
		$whdloadSlaveTextFile = [System.IO.Path]::Combine($outputPath, "$($whdloadArchiveFile.Name)_$($whdloadSlaveFile.Name).txt")
	
		# read whdload slave information and write to text
		& $readWhdloadSlavePath -path $whdloadSlaveFile.FullName | Out-File $whdloadSlaveTextFile
		
		# get whdload name
		$name = Get-Content $whdloadSlaveTextFile | Select-String -Pattern  "Name\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1

		# add whdload details to index
		Add-Content $whdloadIndexPath "$($whdloadArchiveFile.Name);$($whdloadSlaveFile.Name);$name"
	}
}