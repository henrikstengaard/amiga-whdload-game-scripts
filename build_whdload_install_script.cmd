:: Demos OCS
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\ocs\Demos_WHDLoad_set_OCS.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Demos_WHDLoad\OCS" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\ocs\Demos_WHDLoad_UnpackOnAmiga_set_OCS.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Demos_WHDLoad_UnpackOnAmiga\OCS" -copyEntries

:: Demos AGA
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga\Demos_WHDLoad_set_AGA.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Demos_WHDLoad\AGA" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga\Demos_WHDLoad_UnpackOnAmiga_set_AGA.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Demos_WHDLoad_UnpackOnAmiga\AGA" -copyEntries

:: Games OCS
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\ocs\Games_WHDLoad_set_OCS.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad\OCS" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\ocs\Games_WHDLoad_UnpackOnAmiga_set_OCS.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad_UnpackOnAmiga\OCS" -copyEntries

:: Games AGA
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga\Games_WHDLoad_set_AGA.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad\AGA" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga\Games_WHDLoad_AGA_set_AGA.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad_AGA\AGA" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga\Games_WHDLoad_UnpackOnAmiga_set_AGA.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad_UnpackOnAmiga\AGA" -copyEntries

:: Games OCS 4GB
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\ocs_4gb\Games_WHDLoad_set_OCS_4GB.csv" -filterEntriesFiles "data\eab_whdload_packs_3.0\sets\ocs_4gb\games_ocs_4gb.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad\OCS_4GB" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\ocs_4gb\Games_WHDLoad_UnpackOnAmiga_set_OCS_4GB.csv" -filterEntriesFiles "data\eab_whdload_packs_3.0\sets\ocs_4gb\games_ocs_4gb.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad_UnpackOnAmiga\OCS_4GB" -copyEntries

:: Games AGA 4GB
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga_4gb\Games_WHDLoad_set_AGA_4GB.csv" -filterEntriesFiles "data\eab_whdload_packs_3.0\sets\aga_4gb\games_aga_4gb.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad\AGA_4GB" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga_4gb\Games_WHDLoad_AGA_set_AGA_4GB.csv" -filterEntriesFiles "data\eab_whdload_packs_3.0\sets\aga_4gb\games_aga_4gb.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad_AGA\AGA_4GB" -copyEntries
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\eab_whdload_packs_3.0\sets\aga_4gb\Games_WHDLoad_UnpackOnAmiga_set_AGA_4GB.csv" -filterEntriesFiles "data\eab_whdload_packs_3.0\sets\aga_4gb\games_aga_4gb.csv" -installScriptFile "data\eab_whdload_packs_3.0\installscripts\Games_WHDLoad_UnpackOnAmiga\AGA_4GB" -copyEntries

:: HD-Games
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\hd-games\sets\hd-games_set_ocs.csv" -installScriptFile "data\hd-games\installscripts\OCS" -copyEntries -userPackageEntriesDir "HD-Games/" -noIndexDirs
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\hd-games\sets\hd-games_set_aga.csv" -installScriptFile "data\hd-games\installscripts\AGA" -copyEntries -userPackageEntriesDir "HD-Games/" -noIndexDirs

:: HD-Games 4GB
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\hd-games\sets\hd-games_set_ocs_4gb.csv" -installScriptFile "data\hd-games\installscripts\OCS_4GB" -copyEntries -userPackageEntriesDir "HD-Games/" -noIndexDirs
powershell -ExecutionPolicy Bypass -File build_whdload_install_script.ps1 -entriesFiles "data\hd-games\sets\hd-games_set_aga_4gb.csv" -installScriptFile "data\hd-games\installscripts\AGA_4GB" -copyEntries -userPackageEntriesDir "HD-Games/" -noIndexDirs