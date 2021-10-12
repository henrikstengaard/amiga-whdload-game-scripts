set eab_whdload_pack=eab_whdload_packs_retroplay_2019-02-25

:: Demos
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "..\..\whdload_packs\%eab_whdload_pack%\Commodore_Amiga_-_WHDLoad_-_Demos" -entriesFile "entries\demos_entries.csv"

:: Games
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "..\..\whdload_packs\%eab_whdload_pack%\Commodore_Amiga_-_WHDLoad_-_Games" -entriesFile "entries\games_entries.csv"
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_slave_list_archive.ps1 -archivesDir "..\..\whdload_packs\%eab_whdload_pack%\Commodore_Amiga_-_WHDLoad_-_Games_-_Beta_&_Unreleased" -entriesFile "entries\games-beta-unreleased_entries.csv"