:: Demos
powershell -ExecutionPolicy Bypass -File build_whdload_screenshots_new.ps1 -queriesFile "data\eab_whdload_packs_3.0\screenshots\demos_screenshot_queries.csv" -sourcesFile "data\eab_whdload_packs_3.0\screenshots\demos_screenshot_sources.csv" -outputPath "data\eab_whdload_packs_3.0\screenshots\demos_screenshots"

:: Games
powershell -ExecutionPolicy Bypass -File build_whdload_screenshots_new.ps1 -queriesFile "data\eab_whdload_packs_3.0\screenshots\games_screenshot_queries.csv" -sourcesFile "data\eab_whdload_packs_3.0\screenshots\games_screenshot_sources.csv" -outputPath "data\eab_whdload_packs_3.0\screenshots\games_screenshots" -minScore 1

:: HD-Games
powershell -ExecutionPolicy Bypass -File build_whdload_screenshots_new.ps1 -queriesFile "data\hd-games\screenshots\hd-games_screenshot_queries.csv" -sourcesFile "data\hd-games\screenshots\hd-games_screenshot_sources.csv" -outputPath "data\hd-games\screenshots\hd-games_screenshots" -minScore 1