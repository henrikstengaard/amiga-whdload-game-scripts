# Amiga WHDLoad Game Scripts

This is a collection of scripts for Amiga WHDLoad Games.

**Requirements**

The minimum requirements for running the scripts are:

* Windows 7, 8, 8.1 or 10.

## Installation

Installation of the scripts is quite easy and can be done one the following ways: 

* Clone git repository.
* Click 'Download ZIP' and afterwards extract files.


# Amiga English Board WHDLoad Packs

This section describes scripts developed for English Amiga Board WHDLoad Packs.

## 1. Download English Amiga Board WHDLoad Packs

A PowerShell script to download whdload packs from English Amiga Board ftp server. The script downloads games and demoes whdload packs, uncompress archives and copies whdload packs with update packs in combined folders.

1. Double-click 'download_aeb_whdload_packs.cmd' in Windows Explorer or start 'download_aeb_whdload_packs.ps1' from Powershell to run script.
2. Wait for whdload packs being downloaded, uncompressed and copied to combined folders in output folder 'aeb_whdload_packs'.

## 2. Build WHDLoad Slave List

A PowerShell script to build whdload slave list csv file with a list of whdload slave path and details read from slave files.

1. Double-click 'build_whdload_slave_list.cmd' in Windows Explorer or start from command prompt to run script.
2. Wait for whdload slave list being built.

## 3. Filter English Amiga Board WHDLoad Packs

A PowerShell script to filter whdload packs from English Amiga Board by excluding hardware and language versions and picking best version.

1. Double-click 'filter_eab_whdload_packs.cmd' in Windows Explorer or start from command prompt to run script.
2. Wait for whdload packs being filtered and copied to output folders 'eab_whdload_games' and 'eab_whdload_games_aga'.

## 4. Build whdload queries

A PowerShell script to build whdload queries used for finding best matching screenshot and details.

1. Double-click 'build_whdload_queries.cmd' in Windows Explorer or start from command prompt to run script.
2. Wait for whdload queries being built.

## 5. Build whdload screenshots

A PowerShell script to build whdload screenshots for iGame and AGS2 in AGA and OCS mode. Lucene is used to index screenshots for better search and matching between demos/games and screenshots.

1. Double-click 'build_whdload_screenshots_new.cmd' in Windows Explorer or start from command prompt to run script.
2. Wait for whdload screenshots being converted to iGame, AGS2 AGA and OCS iff files.

## 6. Build whdload details

A PowerShell script to build whdload details for iGame and AGS2 in AGA and OCS mode. Lucene is used to index details for better search and matching between demos/games and details.

1. Double-click 'build_whdload_details.cmd' in Windows Explorer or start from command prompt to run script.
2. Wait for whdload details being built.

# Whdownload Games

## Download Whdownload Games

A PowerShell script to download all games from www.whdownload.com.

1. Double-click 'download_whdownload_games.cmd' in Windows Explorer or start 'download_whdownload_games.ps1' from Powershell to run script.
2. Wait for all games being downloaded to folder 'whdownload_games'.

## Filter Whdownload Games

A PowerShell script to filter games downloaded from www.whdownload.com by excluding unwanted versions and picking spreferred versions.

1. Double-click 'filter_whdownload_games.cmd' in Windows Explorer or start 'filter_whdownload_games.ps1' from Powershell to run script.
2. Wait for all filtered games being copied to folder 'whdload_games'.

## Download WHDLoad Installs

A PowerShell script to download all whdload installs from www.whdload.de.

1. Double-click 'download_whdload_installs.cmd' in Windows Explorer or start 'download_whdload_installs.ps1' from Powershell to run script.
2. Wait for all installs being downloaded to folder 'whdload_installs'.

## Read WHDLoad Slave

A PowerShell script to read and print whdload slave information.

* Open Command Prompt and type 'read_whdload_slave.cmd [PATH-TO-SLAVE]'.
* Open Powershell and type 'read_whdload_slave.ps1 [PATH-TO-SLAVE]' to run script.

## Build WHDLoad Index

A PowerShell script to build whdload index .csv file by extracting archive files, scan for whdload slave files and read available information from whdload slave depending on whdload slave version.
Note: The script uses drive Z:\ as temp to extract and scan whdload archives, if drive is present. Otherwise it will use [SystemDrive]:\Temp, which is usually C:\Temp.

**Requires 7-zip installed**

1. Double-click 'build_whdload_index.cmd' in Windows Explorer or start 'build_whdload_index.ps1' from Powershell to run script.
2. Wait for whdload indexes being built to folders 'whdload_installs_index' and 'whdownload_games_index'.



PS C:\Work\First Realize\amiga-whdload-game-scripts\aeb_whdload_packs\demos_whdload\combined> import-csv -delimiter ';' -path .\whdload_slaves.csv | % { $name = $_.WhdloadName; if ($_.WhdloadSlaveName) { $name = $_.WhdloadSlaveName + " " + $_.WhdloadSlaveCopy + " " +$_.W
hdloadName }; $name + ";" + $_.WhdloadSlaveFilePath } > names.txt