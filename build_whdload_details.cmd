:: Demos
powershell -ExecutionPolicy Bypass -File build_whdload_details.ps1 -entriesFile "data\eab_whdload_packs_3.0\details\demos_detail_queries.csv" -detailsSourcesFile "data\eab_whdload_packs_3.0\details\demos_detail_sources.csv" -minScore 1 -entriesDetailsFile "data\eab_whdload_packs_3.0\details\demos_details\demos_details.csv" -noExactEntryNameMatching -noExactFilteredNameMatching -noExactWhdloadSlaveNameMatching

:: Games
powershell -ExecutionPolicy Bypass -File build_whdload_details.ps1 -entriesFile "data\eab_whdload_packs_3.0\details\games_detail_queries.csv" -detailsSourcesFile "data\eab_whdload_packs_3.0\details\games_detail_sources.csv" -minScore 1 -entriesDetailsFile "data\eab_whdload_packs_3.0\details\games_details\games_details.csv"

:: HD-Games
powershell -ExecutionPolicy Bypass -File build_whdload_details.ps1 -entriesFile "data\hd-games\details\hd-games_detail_queries.csv" -detailsSourcesFile "data\hd-games\details\hd-games_detail_sources.csv" -minScore 1 -entriesDetailsFile "data\hd-games\details\hd-games_details.csv"