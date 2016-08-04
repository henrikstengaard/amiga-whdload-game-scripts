# Build WHDLoad Screenshot Queries
# --------------------------------
#
# Author: Henrik Nørfjand Stengaard
# Date:   2016-08-04
#
# A PowerShell script to .


Param(
	[Parameter(Mandatory=$true)]
	[string]$whdloadSlavesFile,
	[Parameter(Mandatory=$true)]
	[string]$screenshotQueriesFile
)


function MakeComparableName([string]$text)
{
	$text = " " + $text + " "

	# change odd chars to space
	#$text = $text -creplace "[&\-_\(\):\.,!\\/+\*\?]", " "
	#$text = $text -replace "[^a-z0-9]", " "
	$text = $text -replace "[^\w]", " "
	$text = $text -replace '\?', ' '
	$text = $text -replace '[\.]', ''
	$text = $text -replace "[&\-_\(\):\.,!\\/+\*\?]", " "
	# return $text
	
	# $newText = ""
	
	# for($i = 0; $i -lt $text.length; $i++)
	# {
		# if ([char]::IsLetterOrDigit($text[$i]) -or [char]::IsWhiteSpace($text[$i]))
		# {
			# $newText += $text[$i]
		# }
	# }

	# char[] arr = str.Where(c => (char.IsLetterOrDigit(c) || 
                             # char.IsWhiteSpace(c) || 
                             # c == '-')).ToArray(); 


	# $text = $newText
					
					
	# remove the and demo
	#$text = $text -replace "the", " " -replace "demo", " "

	$text = $text -replace "disk", " " -replace "\(c\)", " "
	
	# replace roman numbers
	$text = $text -replace " vii ", " 7 " -replace " vi ", " 6 " -replace " v ", " 5 " -replace " iv ", " 4 " -replace " iii ", " 3 " -replace " ii ", " 2 " -replace " i ", " 1 "

	
	# remove odd chars
	$text = $text -creplace "[']", ""

	# add space between number and letters, if not the character 'D'
	$text = $text -replace "(\d+)([^d\d])", "`$1 `$2"
	
	# add space before and after 3D or 4D
	$text = $text -replace "([34]D)", " `$1 "
	
	# add space between lower and upper case letters or numbers
	$text = $text -creplace "([a-z])([A-Z0-9])", "`$1 `$2"

	# add space between numbers and upper case letters
	$text = $text -replace "([0-9])([a-z])", "`$1 `$2"

	# add space between upper case letters and numbers
	$text = $text -creplace "([A-Z])([0-9])", "`$1 `$2"
	
	# pull 3d and 4d together
	$text = $text -replace "\s+([34])\s+([D])\s+", " `$1`$2 "

	# remove single letters (twice to catch all)
	$text = $text -creplace '\s+([a-z])\s+', ' ' -creplace '\s+([a-z])\s+', ' '
	
	
	# add space between upper letters (twice to catch all)
	#$text = $text -creplace '([A-Z])([A-Z])', '$1 $2' -creplace '([A-Z])([A-Z])', '$1 $2'
	#$text = $text -creplace '([A-Z]+)([a-z0-9])', '$1 $2'
	
	# replace multiple space with a single space
	$text = $text -replace "\s+", " "
	
	return $text.ToLower().Trim()
}

function UniqueWords($text)
{
	$keywords = ($text) -split ' '

	$keywordIndex = @{}
	$uniqueKeywords = @()
	
	foreach($keyword in $keywords)
	{
		if ($keywordIndex.ContainsKey($keyword))
		{
			$keywordCount = $keywordIndex.Get_Item($keyword)
		}
		else
		{
			$keywordCount = 0
		}
		
		$keywordCount++
		
		if ($keywordCount -eq 1)
		{
			$uniqueKeywords +=, $keyword
		}
		
		$keywordIndex.Set_Item($keyword, $keywordCount)
	}
	
	return [string]::Join(" ", $uniqueKeywords)
}

function RemoveDiacritics([string]$text)
{
	$textFormD = $text.Normalize([System.Text.NormalizationForm]::FormD).ToCharArray()
	$sb = New-Object -TypeName "System.Text.StringBuilder"

	ForEach ($c in $textFormD)
	{
		$uc = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
		if ($uc -ne [System.Globalization.UnicodeCategory]::NonSpacingMark)
		{
			[void]$sb.Append($c)
		}
	}
	
	return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function ConvertSuperscript([string]$text)
{
	$textFormKd = $text.Normalize([System.Text.NormalizationForm]::FormKD).ToCharArray()
	$sb = New-Object -TypeName "System.Text.StringBuilder"

	ForEach ($c in $textFormKd)
	{
		$uc = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
		if ($uc -ne [System.Globalization.UnicodeCategory]::NonSpacingMark)
		{
			[void]$sb.Append($c)
		}
	}

	return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormKC)
}

function Normalize([string]$text)
{
	return RemoveDiacritics (ConvertSuperscript $text)
}

#Import-module ([System.IO.Path]::Combine($scriptPath, "TextModule.psm1"))

#$whdloadSlavesFile = "aeb_whdload_packs\demos_whdload\combined\whdload_slaves.csv"
#$whdloadSlavesFile = "aeb_whdload_packs\games_whdload\combined\whdload_slaves.csv"
#$whdloadSlavesFile = "aeb_whdload_packs\games_whdload_aga\combined\whdload_slaves.csv"
$whdloadSlavesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($whdloadSlavesFile)

#$outputFile = "ags2_menu_demos_screenshot_queries.csv"
#$outputFile = "ags2_menu_games_screenshot_queries.csv"
#$outputFile = "ags2_menu_games_aga_screenshot_queries.csv"
$screenshotQueriesFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($screenshotQueriesFile)

$items = import-csv -delimiter ';' -path $whdloadSlavesFile -encoding utf8

foreach($item in $items)
{
	$name = $item.WhdloadName
	
	# needed for games
	#if (($name -cmatch '(De|Fr|It|Se|Pl|Es|Cz)$' -or $name -cmatch '(De|Fr|It|Se|Pl|Es|Cz)Fast$' -or $name -match 'NTSC' -or $name -match 'EnemyDe\(EasyPlay\)') -and $name -notmatch 'xit')
	#{
#		Write-Host "skipping '$name'"
#		continue
#	}

	# needed for demos/games
	if ($item.WhdloadSlaveName)
	{
		$name += " " + $item.WhdloadSlaveName
	}

	# if ($item.WhdloadSlaveCopy)
	# {
		# $name += " " + ([string]$item.WhdloadSlaveCopy)
	# }

	# if ($item.ReadmeAppliesTo)
	# {
		# $name += " " + ([string]$item.ReadmeAppliesTo)
	# }
	
	$screenshotQuery = UniqueWords (MakeComparableName (Normalize $name))
	
	$item | Add-Member -MemberType NoteProperty -Name ScreenshotQuery -Value $screenshotQuery
}

$items | Where { $_.ScreenshotQuery } | export-csv -delimiter ';' -path $screenshotQueriesFile -NoTypeInformation

