::AGA
imgtoiff-background-aga.py --aga --pack 1 AGA.pal AGA-Background.png AGA-Background.iff
imgtoiff-background-aga.py --aga --pack 1 AGA.pal AGA-Empty.png AGA-Empty.iff

powershell -ExecutionPolicy Bypass -File ImageToIff.ps1 -imagePath AGA-Background.png -iffPath AGA-Background2.iff
powershell -ExecutionPolicy Bypass -File ImageToIff.ps1 -imagePath AGA-Empty.png -iffPath AGA-Empty2.iff

::OCS
imgtoiff-background-ocs.py --ocs --pack 1 OCS.pal OCS-Background.png OCS-Background.iff
imgtoiff-background-ocs.py --ocs --pack 1 OCS.pal OCS-Empty.png OCS-Empty.iff

powershell -ExecutionPolicy Bypass -File ImageToIff.ps1 -imagePath OCS-Background.png -iffPath OCS-Background2.iff
powershell -ExecutionPolicy Bypass -File ImageToIff.ps1 -imagePath OCS-Empty.png -iffPath OCS-Empty2.iff
