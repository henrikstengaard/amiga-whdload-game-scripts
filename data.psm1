function IsWhdloadSlaveFile($filePath)
{
	# read file bytes
	$fileBytes = [System.IO.File]::ReadAllBytes($filePath)

	# return false, if file is less than 50 bytes
	if ($fileBytes.Count -lt 50)
	{
		return $false
	}
	
	# get magic bytes from file
	$fileMagicBytes = New-Object byte[](4)
	[Array]::Copy($fileBytes, 0, $fileMagicBytes, 0, 4)

	# return false, if file doesn't have whdload slave magic bytes
	if (Compare-Object -ReferenceObject @(0, 0, 3, 243) -DifferenceObject $fileMagicBytes)
	{
		return $false
	}

	# get whdload id from temp file
	$whdloadIdBytes = New-Object byte[](8)
	[Array]::Copy($fileBytes, 36, $whdloadIdBytes, 0, 8)
	$whdloadId = [System.Text.Encoding]::ASCII.GetString($whdloadIdBytes)
	
	# return false, if whdload id doesn't match 'WHDLOADS'
	if ($whdloadId -ne 'WHDLOADS')
	{
		return $false
	}

	return $true
}

function FindEntries($readWhdloadSlaveFile, $entriesDir)
{
    $entries = @()

    $runFilesIndex = @{}
    $runDirsIndex = @{}
    
    foreach($file in (Get-ChildItem -Path $entriesDir -recurse | Where-Object { !$_.PSIsContainer }  | Sort-Object @{expression={$_.FullName};Ascending=$true}))
    {
        $entry = @{}
    
        $entriesDirIndex = $file.FullName.IndexOf($entriesDir) + $entriesDir.Length + 1
        $runFile = $file.FullName.Substring($entriesDirIndex, $file.FullName.Length - $entriesDirIndex)
    
        $entry.RunDir = Split-Path $runFile -Parent
    
        if (IsWhdloadSlaveFile $file.FullName)
        {
            $readmeFile = Get-ChildItem -Path $file.Directory -filter readme*.* | Select-Object -First 1
            
            $whdloadReadmeAppliesTo = ''
            
            if ($readmeFile)
            {
                $whdloadReadmeAppliesTo = Get-Content $readmeFile.FullName -encoding ascii | Where { $_ -match '(install|patch) applies to' } | Select-String -Pattern "(install|patch) applies to\s*(.*)?" -AllMatches | % { $_.Matches } | % { $_.Groups[2].Value.Replace("""", "").Trim() } | Select-Object -First 1 
            }
        
            # read whdload slave information and write to text
            $whdloadSlaveOutput = & $readWhdloadSlaveFile -path $file.FullName
            
            $runType = 'whdload'
            $entry.WhdloadSlaveName = $whdloadSlaveOutput | Select-String -Pattern  "Name\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value -replace '\r', '' -replace '\n', ' ' } | Select-Object -first 1
            $entry.WhdloadSlaveCopy = $whdloadSlaveOutput | Select-String -Pattern  "Copy\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value -replace '\r', '' -replace '\n', ' ' } | Select-Object -first 1
            $entry.WhdloadSlaveFlags = $whdloadSlaveOutput | Select-String -Pattern  "Flags\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
            $entry.WhdloadSlaveBaseMemSize = $whdloadSlaveOutput | Select-String -Pattern  "BaseMemSize\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
            $entry.WhdloadSlaveExpMem = $whdloadSlaveOutput | Select-String -Pattern  "ExpMem\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
            $entry.WhdloadSlaveExecInstall = $whdloadSlaveOutput | Select-String -Pattern  "ExecInstall\s+=\s+'([^']+)" -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value } | Select-Object -first 1
            $entry.WhdloadReadmeAppliesTo = $whdloadReadmeAppliesTo
        }
        elseif ($file.Name -match '^_run$')
        {
            if (!$runFilesIndex.ContainsKey($entry.RunDir.ToLower()))
            {
                $runFilesIndex.Set_Item($entry.RunDir.ToLower(), $runFile)
            }

            $runType = 'runscript'
            $firstRunFileLine = Get-Content $file.FullName | Select-Object -First 1
    
            if (!$firstRunFileLine)
            {
                continue
            }
    
            $directRunFile = Join-Path $file.Directory -ChildPath $firstRunFileLine
    
            if ((Test-Path $directRunFile -IsValid) -and (Test-Path $directRunFile))
            {
                $runType = 'file'
                $runFile = Join-Path $entry.RunDir -ChildPath $firstRunFileLine
            }
        }
        else
        {
            continue
        }
    
        $entry.RunType = $runType
        $entry.RunFile = $runFile
        
        # get entry name from directory name
        $entryName = Split-Path $file.Directory -Leaf
        
        # change entry name to filename, if entry name is 'data' and not equal to filename without '.slave'
        $tempEntryName = $file.Name -replace '\.slave$', ''
        if ($entryName -match '^data$' -and $entryName -ne $tempEntryName)
        {
            $entryName = $tempEntryName
        }

        # get entry size
        $entrySize = 0 
        Get-ChildItem -Path $file.Directory -Recurse | Where-Object { !$_.PSIsContainer } | ForEach-Object { $entrySize += $_.length } 
    
        $entry.EntryName = $entryName
        $entry.EntrySize = $entrySize


        $currentRunDir = $entry.RunDir.ToLower()
        
        while ($currentRunDir -match '\\' -and !$runDirsIndex.ContainsKey($currentRunDir))
        {
            $currentRunDir = Split-Path $currentRunDir -Parent
        }

        if ($runDirsIndex.ContainsKey($currentRunDir))
        {
            $entry.EntryName = $runDirsIndex.Get_Item($currentRunDir)
        }
        else {
            $runDirsIndex.Set_Item($entry.RunDir.ToLower(), $entryName)
        }
    
        $entries += $entry
    }

    # $filteredEntries = @()
    
    # foreach ($entry in ($entries | Sort-Object @{expression={$_.RunDir};Ascending=$true}, @{expression={$_.EntryName};Ascending=$true}))
    # {

    #     # skip entry, if it's not run or file run type and a run file exists for run dir
    #     # if ($entry.RunType -notmatch '(run|file)' -and $runFilesIndex.ContainsKey($runDir))
    #     # {
    #     #     continue
    #     # }

    #     $filteredEntries += $entry
    # }
    
    return $entries
}