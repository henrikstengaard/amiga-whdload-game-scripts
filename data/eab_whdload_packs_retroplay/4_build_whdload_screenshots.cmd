:: Demos
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_screenshots_new.ps1 -queriesFile "screenshots\demos_screenshots\demos_screenshot_queries.csv" -sourcesFile "screenshots\demos_screenshot_sources.csv" -outputPath "screenshots\demos_screenshots"

:: Games
powershell -ExecutionPolicy Bypass -File ..\..\build_whdload_screenshots_new.ps1 -queriesFile "screenshots\games_screenshots\games_screenshot_queries.csv" -sourcesFile "screenshots\games_screenshot_sources.csv" -outputPath "screenshots\games_screenshots" -minScore 1