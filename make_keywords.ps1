
function MakeKeywords([string]$text)
{
	$text = $text -creplace "([&\-_\(\):'\.,])", " "
	$text = $text -replace "([34]D)", " `$1 "
	$text = $text -creplace "([a-z])([A-Z0-9&_\(\):])", "`$1 `$2"
	$text = $text -replace "\s+", " "
	
	return $text.ToLower().Trim() -split " "
}

function IsMatching([string]$text1, [string]$text2)
{
	$text1Keywords = MakeKeywords $text1
	$text2Keywords = MakeKeywords $text2

	return (Compare-Object $text1Keywords $text2Keywords -IncludeEqual -ExcludeDifferent -PassThru).Count -gt 0
}


IsMatching "archer-maclean-presents-billard-americain" "ArcherMacleansBillardAmericain"
IsMatching "4d-sports-driving" "4DSportsDriving&MasterTracks"
IsMatching "alien-breed-tower-assault" "AlienBreedTowerAssault11"


#Write-Host (MakeKeywords "AlienBreedTowerAssault11")
#Write-Host (MakeKeywords "AlienBreed3DDemoLatestDemo")
#Write-Host (MakeKeywords "4DSportsDriving&MasterTracks")
#Write-Host (MakeKeywords "ArcherMacleansBillardAmericain")