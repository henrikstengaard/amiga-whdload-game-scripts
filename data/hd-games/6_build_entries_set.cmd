:: HD-Games
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\hd-games_filtered.csv" -outputEntriesSetFile "sets\hd-games_set_ocs.csv" -excludeFlagPattern "(reqaga)" -excludeHardwarePattern "^(cd32|aga)$"
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\hd-games_filtered.csv" -outputEntriesSetFile "sets\hd-games_set_aga.csv"

:: HD-Games 4GB
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "sets\hd-games_set_ocs.csv" -outputEntriesSetFile "sets\hd-games_set_ocs_4gb.csv" -maxEntrySize 10000000
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "sets\hd-games_set_aga.csv" -outputEntriesSetFile "sets\hd-games_set_aga_4gb.csv" -maxEntrySize 10000000