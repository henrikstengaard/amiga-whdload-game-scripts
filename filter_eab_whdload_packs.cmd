:: Demos
powershell -ExecutionPolicy Bypass -File filter_eab_whdload_packs.ps1 -entriesFile "data\eab_whdload_packs_3.0\entries\Demos_WHDLoad_entries.csv" -outputEntriesFile "data\eab_whdload_packs_3.0\filtered\Demos_WHDLoad_filtered.csv"
powershell -ExecutionPolicy Bypass -File filter_eab_whdload_packs.ps1 -entriesFile "data\eab_whdload_packs_3.0\entries\Demos_WHDLoad_UnpackOnAmiga_entries.csv" -outputEntriesFile "data\eab_whdload_packs_3.0\filtered\Demos_WHDLoad_UnpackOnAmiga_filtered.csv"

:: Games
powershell -ExecutionPolicy Bypass -File filter_eab_whdload_packs.ps1 -entriesFile "data\eab_whdload_packs_3.0\entries\Games_WHDLoad_entries.csv" -outputEntriesFile "data\eab_whdload_packs_3.0\filtered\Games_WHDLoad_filtered.csv"
powershell -ExecutionPolicy Bypass -File filter_eab_whdload_packs.ps1 -entriesFile "data\eab_whdload_packs_3.0\entries\Games_WHDLoad_AGA_entries.csv" -outputEntriesFile "data\eab_whdload_packs_3.0\filtered\Games_WHDLoad_AGA_filtered.csv"
powershell -ExecutionPolicy Bypass -File filter_eab_whdload_packs.ps1 -entriesFile "data\eab_whdload_packs_3.0\entries\Games_WHDLoad_UnpackOnAmiga_entries.csv" -outputEntriesFile "data\eab_whdload_packs_3.0\filtered\Games_WHDLoad_UnpackOnAmiga_filtered.csv"

:: HD-Games
powershell -ExecutionPolicy Bypass -File filter_eab_whdload_packs.ps1 -entriesFile "data\hd-games\entries\hd-games_entries.csv" -outputEntriesFile "data\hd-games\filtered\hd-games_filtered.csv"