# AGS2 iff notes

AGS2.conf has a "lock_colors" option, which locks the last x colors in the palette. Other palette colors are used for fading in and out screenshots.

Fixed palette indexes:

* 0: Background color, somehow connected to border color
* 254: Text background color
* 255: Text color

## imgtoiff.py script

Script to generate AGS2 game screenshot iff's with following hacks:

1. Adds black color (0, 0, 0) as palette index 0 and pushed other palette colors by 1 index.

## imgtoiff-background.py script

Script to generate AGS2 menu background iff with following hacks:

1. Moves colors to end of palette by adding black color (0, 0, 0) to push other palette colors.
2. Adds black color (0, 0, 0) as palette index 254.
3. Adds white color (255, 255, 255) as palette index 255.
4. Replaces background color (4, 4, 7) with palette index 254.

## imgtoiff-empty.py script

Script to generate AGS2 menu empty iff, when a game doesn't have a screenshot with following hacks:

1. Moves colors to end of palette by adding black color (0, 0, 0) to push other palette colors.
2. Adds black color (0, 0, 0) as palette index 254.
3. Adds white color (255, 255, 255) as palette index 255.
4. Forcibly sets width to 320 and height to 128 without doing a proper resize.
5. Set pixels to palette index 254.
