:: Demos
powershell -ExecutionPolicy Bypass -File build_whdload_slave_list.ps1 -entriesDir "whdload_packs\eab_whdload_packs_3.0\Demos_WHDLoad" -entriesFile "data\eab_whdload_packs_3.0\entries\Demos_WHDLoad_entries.csv"
powershell -ExecutionPolicy Bypass -File build_whdload_slave_list_archive.ps1 -archivesDir "whdload_packs\eab_whdload_packs_3.0\Demos_WHDLoad_UnpackOnAmiga" -entriesFile "data\eab_whdload_packs_3.0\entries\Demos_WHDLoad_UnpackOnAmiga_entries.csv"

:: Games
powershell -ExecutionPolicy Bypass -File build_whdload_slave_list.ps1 -entriesDir "whdload_packs\eab_whdload_packs_3.0\Games_WHDLoad" -entriesFile "data\eab_whdload_packs_3.0\entries\Games_WHDLoad_entries.csv"
powershell -ExecutionPolicy Bypass -File build_whdload_slave_list.ps1 -entriesDir "whdload_packs\eab_whdload_packs_3.0\Games_WHDLoad_AGA" -entriesFile "data\eab_whdload_packs_3.0\entries\Games_WHDLoad_AGA_entries.csv"
powershell -ExecutionPolicy Bypass -File build_whdload_slave_list_archive.ps1 -archivesDir "whdload_packs\eab_whdload_packs_3.0\Games_WHDLoad_UnpackOnAmiga" -entriesFile "data\eab_whdload_packs_3.0\entries\Games_WHDLoad_UnpackOnAmiga_entries.csv"

:: HD-Games
powershell -ExecutionPolicy Bypass -File build_whdload_slave_list.ps1 -entriesDir "c:\Work\First Realize\hd-games" -entriesFile "data\hd-games\entries\hd-games_entries.csv"