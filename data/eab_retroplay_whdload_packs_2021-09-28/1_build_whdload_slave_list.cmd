set whdload_packs_dir=d:\Temp\EAB Retroplay WHDLoad Packs 2021-09-28

:: Demos
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "%whdload_packs_dir%\Commodore_Amiga_-_WHDLoad_-_Demos" -entriesFile "entries\demos_entries.csv"

:: Games
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "%whdload_packs_dir%\Commodore_Amiga_-_WHDLoad_-_Games" -entriesFile "entries\games_entries.csv"
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "%whdload_packs_dir%\Commodore_Amiga_-_WHDLoad_-_Games_-_Beta_&_Unreleased" -entriesFile "entries\games-beta-unreleased_entries.csv"

:: Magazines
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "%whdload_packs_dir%\Commodore_Amiga_-_WHDLoad_-_Magazines" -entriesFile "entries\magazines_entries.csv"