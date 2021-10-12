:: Demos
powershell -ExecutionPolicy Bypass -File ..\..\filter_eab_whdload_packs.ps1 -entriesFile "entries\demos_entries.csv" -outputEntriesFile "filtered\demos_filtered.csv"

:: Games
powershell -ExecutionPolicy Bypass -File ..\..\filter_eab_whdload_packs.ps1 -entriesFile "entries\games_entries.csv" -outputEntriesFile "filtered\games_filtered.csv"
powershell -ExecutionPolicy Bypass -File ..\..\filter_eab_whdload_packs.ps1 -entriesFile "entries\games-beta-unreleased_entries.csv" -outputEntriesFile "filtered\games-beta-unreleased_filtered.csv"

:: Magazines
powershell -ExecutionPolicy Bypass -File ..\..\filter_eab_whdload_packs.ps1 -entriesFile "entries\magazines_entries.csv" -outputEntriesFile "filtered\magazines_filtered.csv"
