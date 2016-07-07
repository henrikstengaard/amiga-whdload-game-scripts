# Backup Highscores and Saves Script

This is a script to backup highscores and saves for Amiga WHDLoad Games directory to a Lha backup file and a script to restore Lha backup file back to Amiga WHDLoad Games directory. It's easy to update which highscores and saves to backup by updating a .csv with patterns and run a Powershell script to generate a backup patterns part of the scripts.

Use of scripts at your own risk!

**Requirements**

The minimum requirements are:

* Windows 7, 8, 8.1 or 10 to run Powershell scripts.
* Amiga/WinUAE with 68000+ CPU and Wordbench 3.x to run backup script. It might run on earlier Workbench versions.

## Installation

Installation of the scripts is quite easy and can be done one the following ways: 

* Clone git repository.
* Click 'Download ZIP' and afterwards extract files.

## Updating highscores and saves to backup

Updating highscores and saves to backup with the following steps:

1. Update "highscores_saves_patterns.csv" file with name and pattern. Name column is only used for displaying, when files are found with pattern in Pattern column. Pattern column doesn't support wildcards.
2. Double-click 'build_backup_patterns.cmd' in Windows Explorer or start 'build_backup_patterns.ps1' from Powershell to run script.

Please fork or mail updates to "highscores_saves_patterns.csv" file :-).

## Add backup script directory in WinUAE

Add backup script directory in WinUAE with the following steps:

1. Start WinUAE and load your configuration.
2. Goto Hardware, CD & Hard drives.
3. Click "Add Directory or Archive".
4. Enter "BACKUP" in device name.
5. Enter "Backup" in volume name.
6. Uncheck bootable checkbox.
7. Click "Select Directory" and select the "backup_highscores_saves" directory where scripts are installed.
8. Click "Ok" to add directory.
9. Start WinUAE.

## Start backup script from Workbench in WinUAE

Start backup script from Workbench in WinUAE with the following steps:

1. Double-click "Backup" drive.
2. Click and holddown right mouse button, move cursor to menu bar in the top in the screen and select Window, Show, All files and release mouse button.
3. Double-click "backup" file.
4. In the execute a file dialog change command to "execute backup".
5. Select drawer to backup, where backup script should search for highscores or saves to backup.
6. Enter backup file, select drawer and enter name for backup file.
7. Use RAM:, if Yes is selected then cache files are written to ram disk instead of hard disk.
8. Wait for script to write "Done" and close output window.
9. Copy backup file .lha to be stored somewhere safe.

Note: Repeat step 3 to backup other directories.

## Start backup script from Shell in WinUAE

Start backup script from Shell in WinUAE with the following steps:

1. Double-click "System" drive.
2. Double-click "System" drawer.
3. Double-click "Shell" icon.
4. Type "backup:" and hit enter.
5. Type "execute backup" and hit enter.
5. Select drawer to backup, where backup script should search for highscores or saves to backup.
6. Enter backup file, select drawer and enter name for backup file.
7. Use RAM:, if Yes is selected then cache files are written to ram disk instead of hard disk.
8. Wait for script to write "Done" and optionally close Shell by typing "endcli" and hit enter.
9. Copy backup file .lha to be stored somewhere safe.

Note: Repeat step 5 to backup other directories. 

## Start restore script from Workbench in WinUAE

Start restore script from Workbench in WinUAE with the following steps:

1. Double-click "Backup" drive.
2. Click and holddown right mouse button, move cursor to menu bar in the top in the screen and select Window, Show, All files and release mouse button.
3. Double-click "restore" file.
4. In the execute a file dialog change command to "execute restore".
5. Select backup file containing backup of highscores or saves to restore.
6. Select drawer to restore backup to, where restore script should put highscores or saves from backup file.
7. Wait for script to write "Done" and close output window.

Note: Repeat step 3 to restore other backup files. 

## Start restore script from Shell in WinUAE

Start restore script from Shell in WinUAE with the following steps:
1. Double-click "System" drive.
2. Double-click "System" drawer.
3. Double-click "Shell" icon.
4. Type "backup:" and hit enter.
5. Type "execute restore" and hit enter.
6. Select backup file containing backup of highscores or saves to restore.
7. Select drawer to restore backup to, where restore script should put highscores or saves from backup file.
8. Wait for script to write "Done" and optionally close Shell by typing "endcli" and hit enter.

Note: Repeat step 5 to restore other backup files. 

**Screenshots**

![Image of select drawer to backup dialog](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen1.png)
![Image of enter backup file dialog](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen2.png)
![Image of use ram dialog](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen3.png)
![Image of backup output window](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen4.png)
![Image of select backup file dialog](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen5.png)
![Image of select drawer to restore backup to dialog](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen6.png)
![Image of confirm restore dialog](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen7.png)
![Image of restore output window](https://raw.githubusercontent.com/henrikstengaard/amiga-whdload-game-scripts/master/backup_highscores_saves/screen8.png)
