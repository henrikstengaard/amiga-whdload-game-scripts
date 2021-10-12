:: Demos OCS
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\demos_filtered.csv" -assignName "A-Demos" -setName "Demos" -outputEntriesSetFile "sets\ocs\demos_set_ocs.csv" -excludeFlagPattern "(reqaga)" -excludeHardwarePattern "^(cd32|aga)$"

:: Demos OCS, 1MB CHIP
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "sets\ocs\demos_set_ocs.csv" -outputEntriesSetFile "sets\ocs_1mb_chip\demos_set_ocs_1mb_chip.csv" -maxWhdloadSlaveBaseMemSize 565248 -maxWhdloadSlaveExpMem 40000

:: Demos AGA
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\demos_filtered.csv" -assignName "A-Demos" -setName "Demos" -outputEntriesSetFile "sets\aga\demos_set_aga.csv"

:: -----------------

:: Games OCS
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\games_filtered.csv" -assignName "A-Games" -setName "Games" -outputEntriesSetFile "sets\ocs\games_set_ocs.csv" -excludeFlagPattern "(reqaga)" -excludeHardwarePattern "^(cd32|aga)$"
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\games-beta-unreleased_filtered.csv" -assignName "A-Beta" -setName "Games Beta/Unreleased" -appendName " (Beta/Unreleased)" -outputEntriesSetFile "sets\ocs\games-beta-unreleased_set_ocs.csv" -excludeFlagPattern "(reqaga)" -excludeHardwarePattern "^(cd32|aga)$"

:: Games OCS, 1MB CHIP
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "sets\ocs\games_set_ocs.csv" -outputEntriesSetFile "sets\ocs_1mb_chip\games_set_ocs_1mb_chip.csv" -maxWhdloadSlaveBaseMemSize 565248 -maxWhdloadSlaveExpMem 40000
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "sets\ocs\games-beta-unreleased_set_ocs.csv" -assignName "A-Beta" -setName "Games Beta/Unreleased" -appendName " (Beta/Unreleased)" -outputEntriesSetFile "sets\ocs_1mb_chip\games-beta-unreleased_set_ocs_1mb_chip.csv" -maxWhdloadSlaveBaseMemSize 565248 -maxWhdloadSlaveExpMem 40000

:: Games AGA
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\games_filtered.csv" -assignName "A-Games" -setName "Games" -outputEntriesSetFile "sets\aga\games_set_aga.csv"
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\games-beta-unreleased_filtered.csv" -assignName "A-Beta" -setName "Games Beta/Unreleased" -appendName " (Beta/Unreleased)" -outputEntriesSetFile "sets\aga\games-beta-unreleased_set_aga.csv"

:: -----------------

:: Magazines OCS
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\magazines_filtered.csv" -assignName "A-Magazines" -setName "Magazines" -outputEntriesSetFile "sets\ocs\magazines_set_ocs.csv" -excludeFlagPattern "(reqaga)" -excludeHardwarePattern "^(cd32|aga)$"

:: Magazines OCS, 1MB CHIP
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "sets\ocs\magazines_set_ocs.csv" -outputEntriesSetFile "sets\ocs_1mb_chip\magazines_set_ocs_1mb_chip.csv" -maxWhdloadSlaveBaseMemSize 565248 -maxWhdloadSlaveExpMem 40000

:: Magazines AGA
powershell -ExecutionPolicy Bypass -File ..\..\build_entries_set.ps1 -entriesFiles "filtered\magazines_filtered.csv" -assignName "A-Magazines" -setName "Magazines" -outputEntriesSetFile "sets\aga\magazines_set_aga.csv"
