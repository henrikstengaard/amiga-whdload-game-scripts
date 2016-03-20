# AGS2 menu settings

This is a settings menu for AGS2, which allows following settings to be changed:

* Turn on WHDLoad Preload
* Turn off WHDLoad Preload
* View settings

When settings are changed, they are saved to the file `AGS:whdloadargs`.

During boot the settings are read from the file `AGS:whdloadargs` put into ENV: as part of `Startup-Sequence`. 

### IF EXISTS AGS:whdloadargs
      copy AGS:whdloadargs ENV:whdloadargs
    ELSE
      setenv whdloadargs ""
    ENDIF 
	
Note: This code is added after ENV: is copied and assigned.

AGS2 run files uses the settings like this:

### IF $whdloadargs EQ ""
      whdload [game].Slave
    ELSE
      whdload [game].Slave $whdloadargs
    ENDIF