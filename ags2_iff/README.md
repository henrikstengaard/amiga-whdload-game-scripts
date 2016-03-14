# AGS2 iff

## AGA iff notes

AGA game screenshot iff palette index notes:

* 0: For game screenshots this color has to be the same as background color in AGA menu background. This is to prevent border color fading, when AGS2 starts first time after reboot.

AGA menu background iff palette index notes:

* 254: Text background color.
* 255: Text color.

AGA menu background png notes:

* AGA menu background image for AGA2.
* Palette exported to file used to force a fixed palette for iff. First 204 colors in palette file is 1, 1, 1 to make palette remap skip these colors.
* Palette indexes 205-255 is used for background image.
* Palette index 254 is used for background color.

AGA menu empty png notes:

* AGA menu empty image for AGS2, when a game doesn't have a screenshot.
* Palette exported to file used to force a fixed palette for iff. First 204 colors in palette file is 1, 1, 1 to make palette remap skip these colors.
* Palette indexes 205-255 is used for background image.
* Palette index 0 is used for background color.

## OCS iff notes

OCS game screenshot iff palette index notes:

* 0: For game screenshots this color has to be the same as background color in OCS menu background. This is to prevent border color fading, when AGS2 starts first time after reboot.

OCS menu background iff palette index notes:

* 14: Text background color.
* 15: Text color.

OCS menu background png notes:

* OCS menu background image for AGA2.
* Palette exported to file used to force a fixed palette for iff. First 12 colors in palette file is 1, 1, 1 to make palette remap skip these colors.
* Palette indexes 12-15 is used for background image.
* Palette index 14 is used for background color.

OCS menu empty png notes:

* OCS menu empty image for AGS2, when a game doesn't have a screenshot.
* Palette exported to file used to force a fixed palette for iff. First 12 colors in palette file is 1, 1, 1 to make palette remap skip these colors.
* Palette indexes 12-15 for background image.
* Palette index 0 is used for background color.



## imgtoiff-aga.py script

Python script used to generate AGA game screenshot iff's with following hacks:

* Add color 0, 0, 0 as palette index 0 to prevent border color fading in AGS2.

Usage: imgtoiff-aga.py --aga --pack 1 [INPUT.PNG] [OUTPUT.IFF]



## imgtoiff-background-aga.py script

Python script used to generate AGA menu background and empty iff's with following hacks:

* Read palette file for preserving a fixed palette.
* Remaps palette in input file to fixed palette.

Usage: imgtoiff-background-aga.py --aga [PALETTE-FILE] [INPUT.PNG] [OUTPUT.IFF]



## imgtoiff-ocs.py script

Python script used to generate OCS game screenshot iff's with following hacks:

* Force 4 bit depth
* Add color 0, 0, 0 as palette index 0 to prevent border color fading in AGS2.

Usage: imgtoiff-ocs.py --ocs --pack 1 [INPUT.PNG] [OUTPUT.IFF]



## imgtoiff-background-ocs.py script

Python script used to generate OCS menu background and empty iff's with following hacks:

* Force 4 bit depth
* Read palette file for preserving a fixed palette.
* Remaps palette in input file to fixed palette.

Usage: imgtoiff-background-ocs.py --ocs [PALETTE-FILE] [INPUT.PNG] [OUTPUT.IFF]
