:: Games OCS
powershell -ExecutionPolicy Bypass -File build_whdload_remove_script.ps1 "data\eab_whdload_packs_3.0\sets\ocs\Games_WHDLoad_set_OCS.csv,data\eab_whdload_packs_3.0\sets\ocs\Games_WHDLoad_UnpackOnAmiga_set_OCS.csv" -assignName "A-Games" -menuTitle "Remove Game WHDLoads" -outputDir "data\eab_whdload_packs_3.0\removescripts\ocs"

:: Games AGA
powershell -ExecutionPolicy Bypass -File build_whdload_remove_script.ps1 "data\eab_whdload_packs_3.0\sets\aga\Games_WHDLoad_set_AGA.csv,data\eab_whdload_packs_3.0\sets\aga\Games_WHDLoad_AGA_set_AGA.csv,data\eab_whdload_packs_3.0\sets\aga\Games_WHDLoad_UnpackOnAmiga_set_AGA.csv" -assignName "A-Games" -menuTitle "Remove Game WHDLoads" -outputDir "data\eab_whdload_packs_3.0\removescripts\aga"

:: Games OCS 4GB
powershell -ExecutionPolicy Bypass -File build_whdload_remove_script.ps1 "data\eab_whdload_packs_3.0\sets\ocs_4gb\Games_WHDLoad_set_OCS_4GB.csv,data\eab_whdload_packs_3.0\sets\ocs_4gb\Games_WHDLoad_UnpackOnAmiga_set_OCS_4GB.csv" -assignName "A-Games" -menuTitle "Remove Game WHDLoads" -outputDir "data\eab_whdload_packs_3.0\removescripts\ocs_4gb"

:: Games AGA 4GB
powershell -ExecutionPolicy Bypass -File build_whdload_remove_script.ps1 "data\eab_whdload_packs_3.0\sets\aga_4gb\Games_WHDLoad_set_AGA_4GB.csv,data\eab_whdload_packs_3.0\sets\aga_4gb\Games_WHDLoad_AGA_set_AGA_4GB.csv,data\eab_whdload_packs_3.0\sets\aga_4gb\Games_WHDLoad_UnpackOnAmiga_set_AGA_4GB.csv" -assignName "A-Games" -menuTitle "Remove Game WHDLoads" -outputDir "data\eab_whdload_packs_3.0\removescripts\aga_4gb"