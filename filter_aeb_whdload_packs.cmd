:: Obsolete
::powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "games_whdload_data\aeb_whdload_pack_games_sources.csv" -outputPath "aeb_whdload_games" -excludeHardwarePattern "^(cd32|aga)$" -excludeLanguagePattern "^(de|fr|it|se|pl|es|cz|fi|gr)" -bestVersion
::powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "games_whdload_data\aeb_whdload_pack_games_aga_sources.csv" -outputPath "aeb_whdload_games_aga" -excludeHardwarePattern "^(cd32)$" -excludeLanguagePattern "^(de|fr|it|se|pl|es|cz|fi|gr)" -bestVersion
::powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "games_whdload_data\aeb_whdload_pack_games_aga_sources.csv" -outputPath "aeb_whdload_games_cd32" -excludeLanguagePattern "^(de|fr|it|se|pl|es|cz|fi|gr)" -bestVersion
::powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "demos_whdload_data\aeb_whdload_pack_demos_sources.csv" -outputPath "aeb_whdload_demos" -excludeFlagPattern "(reqaga)"
::powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "demos_whdload_data\aeb_whdload_pack_demos_sources.csv" -outputPath "aeb_whdload_demos_aga"

:: Demos
powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "demos_whdload_data\aeb_whdload_pack_demos_sources.csv" -outputPath "aeb_whdload_demos_ocs" -excludeFlagPattern "(reqaga)"
powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "demos_whdload_data\aeb_whdload_pack_demos_sources.csv" -outputPath "aeb_whdload_demos_aga"

:: Games
powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "games_whdload_data\aeb_whdload_pack_games_sources.csv" -outputPath "aeb_whdload_games_ocs" -excludeFlagPattern "(reqaga)" -excludeHardwarePattern "^(cd32|aga)$"
powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "games_whdload_data\aeb_whdload_pack_games_aga_sources.csv" -outputPath "aeb_whdload_games_aga"
