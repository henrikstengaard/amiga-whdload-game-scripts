:: Demos
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_details.ps1 -entriesFile "details\demos_details\demos_detail_queries.csv" -detailsSourcesFile "details\demos_detail_sources.csv" -minScore 1 -entriesDetailsFile "details\demos_details\demos_details.csv" -noExactEntryNameMatching -noExactFilteredNameMatching -noExactWhdloadSlaveNameMatching

:: Games
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_details.ps1 -entriesFile "details\games_details\games_detail_queries.csv" -detailsSourcesFile "details\games_detail_sources.csv" -minScore 1 -entriesDetailsFile "details\games_details\games_details.csv"