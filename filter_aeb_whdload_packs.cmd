powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "aeb_whdload_pack_games_sources.csv" -outputPath "aeb_whdload_games" -excludeHardwarePattern "^(cd32|aga)" -excludeLanguagePattern "^(de|fr|it|se|pl|es|cz)" -bestVersion
powershell -ExecutionPolicy Bypass -File filter_aeb_whdload_packs.ps1 -whdloadSourceFile "aeb_whdload_pack_games_aga_sources.csv" -outputPath "aeb_whdload_games_aga" -excludeLanguagePattern "^(de|fr|it|se|pl|es|cz)" -bestVersion

