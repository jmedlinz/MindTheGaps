<#
.SYNOPSIS
	The Compute-Daily-Stats function is used internally as the main processing function to extract useful time worked and gap data from a folder of time-based screenshots (for example, TimeSnapper).
.PARAMETER DaysAgo
	The number of days back from today to process.  So, -1 would use the data from yesterday, and -7 would use the data from a week ago.  Since positive numbers are meaningless here, the sign is ignored: -7 and 7 would both use the data from a week ago.
.PARAMETER SkipDuplicates
	If this command is included then the images will be examined first for duplicates.  Only the first duplicate in the folder will be kept, all others will be ignored - even if the files was created later on in the day.
	Note that the check for duplicate files will take much longer to run than if the check is skipped.
	The default is FALSE, ie don't check for duplicate files.
.PARAMETER ShowGaps
	If this command is included then the script will output the gaps between work periods.
	The default is FALSE, ie don't show the gaps.
#>

#######################################################################

function Compute-Daily-Stats {
	param (
		[Parameter()]
		[int]$DaysAgo,
		[Parameter()]
		[switch]$SkipDuplicates = $FALSE,
		[Parameter()]
		[switch]$ShowGaps = $FALSE
	 )

	# The sub-folder to process.  Defaults to the current date.
	$ThisDay   = (Get-Date).AddDays(-$DaysAgo).ToString("yyyy-MM-dd")
	$DayFormat = (Get-Date).AddDays(-$DaysAgo).ToString("ddd")

	# The base folder to the snapshot folders.
	Set-Variable BasePath    -option Constant -value (Join-Path -Path $SnapshotFolder -ChildPath $ThisDay)
	Set-Variable ArchivePath -option Constant -value ($BasePath + $ArchivePostfix)

	$FileIndex = 0;
	$RowIndex  = 0;
	$DailyWorkTime = New-TimeSpan -Hours 0 -Minutes 0;
	$DailyGapTime  = New-TimeSpan -Hours 0 -Minutes 0;

	# Colors hashtable
	$Colors = @{
		Sat = "DarkGray"
		Sun = "DarkGray"
		Mon = "DarkCyan"
		Tue = "DarkYellow"
		Wed = "Green"
		Thu = "Magenta"
		Fri = "Red"
	}

	# ANSI escape codes for underlining text.
	$UnderlineStart = "$([char]27)[4m"
	$UnderlineEnd   = "$([char]27)[24m"

	function DeleteLoneArchiveFolders {

		$Folders = Get-ChildItem "$SnapshotFolder" -ErrorAction SilentlyContinue |
			Where-Object { $_.PsIsContainer } |
			Where-Object {($_.Name -like "????-??-??$ArchivePostfix")} |
			Where-Object {$_.CreationTimeUtc -lt (Get-Date).AddDays(-$KeepFilesDays)} |
			Sort-Object -Property @{Expression = "Name"}, @{Expression = "CreationTimeUtc"}

		Foreach ($Folder in $Folders) {

			$FolderPath = $Folder.FullName | Split-Path
			$FolderLeafArch = Join-Path -Path $FolderPath -ChildPath $Folder.Name
			$LeafBase = ($Folder.Name.Split("."))[0]
			$FolderLeafBase = Join-Path -Path $FolderPath -ChildPath $LeafBase

			# If there's no "2021-10-13" folder but there is a
			# "2021-10-13.archive" folder, then delete the lone archive folder.
			if (-not (Test-Path "$FolderLeafBase") -and (Test-Path "$FolderLeafArch")) {
				Get-ChildItem -Path "$FolderLeafArch" -Recurse | Remove-Item -Force -Recurse
				Remove-Item "$FolderLeafArch" -Force -Recurse -ErrorAction SilentlyContinue
				Write-Host ("{0} deleted" -f "$FolderLeafArch")
			}
		}
	}


	#######################################################################

	# If there are .archive folders that don't have a corresponding base
	# folder, then TimeSnapper has most likely deleted teh base folder because
	# it was too old.  We can delete the .archive folder too.
	DeleteLoneArchiveFolders

	# Get a list of all the files in the target folders, sorted by the UTC CreationTime.
	# Use UTC in all the internal calculations so we don't have to worry about Daylight Saving times.
	$BaseFiles    = Get-ChildItem "$BasePath"    -ErrorAction SilentlyContinue
	$ArchiveFiles = Get-ChildItem "$ArchivePath" -ErrorAction SilentlyContinue


	if (($BaseFiles | Measure-Object).Count -gt 0) {
		$AllFiles = $AllFiles + $BaseFiles
	}

	if (($ArchiveFiles | Measure-Object).Count -gt 0) {
		$AllFiles = $AllFiles + $ArchiveFiles
	}

	$AllFiles = $AllFiles |
		Where-Object {$_.extension -in ".png",".jpg",".gif",".wmf",".tiff",".bmp",".emf"} |
		Where-Object { -not $_.PsIsContainer } |
		Where-Object {($_.Name -notlike "$ClearFilePrefix*")} |
		Sort-Object -Property @{Expression = "CreationTimeUtc"}, @{Expression = "Name"}

	$LastIndex = ($AllFiles | Measure-Object).Count

	if ($SkipDuplicates) {
		# Find files containing duplicate images.
		# Credit: https://stackoverflow.com/questions/16845674/removing-duplicate-files-with-powershell
		$DuplicateFiles =
			Get-ChildItem "$BasePath" |
			Get-FileHash -Algorithm MD5 |
			Group-Object -Property Hash |
			Where-Object -Property Count -gt 1 |
			ForEach-Object {
				$_.Group.Path |
				Select-Object -First ($_.Count -1)}
	}

	Foreach ($ThisFile in $AllFiles) {

		$FileIndex += 1

		if (-not $SkipDuplicates -or $DuplicateFiles -notcontains $ThisFile.FullName) {

			# If this is the first file we're examining, set up the tracking variables.
			if ($FileIndex -eq 1) {

				Write-Information "Processing $LastIndex files in the $BasePath folder"

				# This is when we first start working.
				$StartWork = $ThisFile

				$LastFile = $ThisFile

				$LastWorkedFile = ""

			} else {

				Write-Information ("T.utc={0} T={1} S={2} L={3}" `
						-f $ThisFile.CreationTimeUtc, $ThisFile.Name, $StartWork.Name, $LastFile.Name)

				$FileTimeDiff = $ThisFile.CreationTimeUtc - $LastFile.CreationTimeUtc

				# If the time difference between the last two files is greater than the BreakLimit then treat it as a break.
				if ($FileTimeDiff.TotalMinutes -ge $BreakLimit -or $FileIndex -eq $LastIndex) {

					# If the time difference between the last and first files is greater than the WorkLimit then treat it as work.
					$WorkTimeDiff = $LastFile.CreationTimeUtc - $StartWork.CreationTimeUtc

					if ($WorkTimeDiff.TotalMinutes -ge $WorkLimit) {


						$RowIndex += 1
						$Prefix = "    "
						if ($RowIndex -eq 1) {
							$Prefix = $DayFormat + ":"
						}

						# When ShowGaps is true, a breakdown of the gaps between work periods is shown.
						# This is useful for identifying when you're not working, and for how long.
						if ($ShowGaps) {
							# Skip the first gap (when LastWorkedFile == ""), as it's not really a gap.
							if ($LastWorkedFile -ne "") {

								# Compute the stats for the gap.
								$StartString   = $LastWorkedFile.CreationTime.ToShortTimeString().ToLower()
								$FinishString  = $StartWork.CreationTime.ToShortTimeString().ToLower()
								$GapTimeDiff   = $StartWork.CreationTimeUtc - $LastWorkedFile.CreationTimeUtc
								$DailyGapTime += $GapTimeDiff

								# Output a line showing the timespan and hours/minutes of the gap.
								Write-Host $Prefix -NoNewline -ForegroundColor Black -BackgroundColor $Colors[$DayFormat]
								Write-Host ("Gap:   {0} - {1}: {2} hours {3} minutes)" -f `
										$StartString.PadLeft(8),  `
										$FinishString.PadLeft(8), `
										$GapTimeDiff.TotalHours.ToString("0.0").PadLeft(4),  `
										$GapTimeDiff.TotalMinutes.ToString("(0").PadLeft(5)) `
										-ForegroundColor DarkGray
							}
						}

						# Compute the stats for the work period.
						$StartString    = $StartWork.CreationTime.ToShortTimeString().ToLower()
						$FinishString   = $LastFile.CreationTime.ToShortTimeString().ToLower()
						$DailyWorkTime += $WorkTimeDiff

						# Output a line showing the timespan and hours/minutes worked.
						Write-Host $Prefix -NoNewline -ForegroundColor Black -BackgroundColor $Colors[$DayFormat]
						Write-Host ("       {0} - {1}: {2} hours {3} minutes)" -f `
								#$Prefix, `
								$StartString.PadLeft(8),  `
								$FinishString.PadLeft(8), `
								$WorkTimeDiff.TotalHours.ToString("0.0").PadLeft(4),  `
								$WorkTimeDiff.TotalMinutes.ToString("(0").PadLeft(5)) `
								-ForegroundColor White

						# We're starting a gap, so record the last file we worked on, ie the start of the gap.
						$LastWorkedFile = $LastFile

					}

					$StartWork = $ThisFile

				}

				$LastFile = $ThisFile

			}

		} else {

			Write-Information ("T={0} Skipped" -f $ThisFile.Name)

		}

	}

	# The last line should be underlined.  If we're not showing gaps then we'll need to underline the total worked line.
	if ($ShowGaps) {
		# Don't underline text.
		$Preformat  = ""
		$Postformat = ""
	} else {
		# Underline text.
		$Preformat  = $UnderlineStart
		$Postformat = $UnderlineEnd
	}

	# Output the total worked for the day.
	Write-Host ("{0}Total worked on {1}: {2} hours {3} minutes){4}" `
			-f $Preformat, `
			"$DayFormat $ThisDay", `
			$DailyWorkTime.TotalHours.ToString("0.0").PadLeft(4), `
			$DailyWorkTime.TotalMinutes.ToString("(0").PadLeft(5), `
			$Postformat) `
			-ForegroundColor Black -BackgroundColor $Colors[$DayFormat]

	# If we're showing gaps then output the total gap time for the day.
	if ($ShowGaps) {
		$Preformat  = $UnderlineStart
		$Postformat = $UnderlineEnd
		Write-Host ("{0}Total gaps:                     {1} hours {2} minutes{3})" `
				-f $Preformat, `
				# "$DayFormat $ThisDay",
				$DailyGapTime.TotalHours.ToString("0.0").PadLeft(4), `
				$DailyGapTime.TotalMinutes.ToString("(0").PadLeft(5), `
				$Postformat) `
				-ForegroundColor Black -BackgroundColor $Colors[$DayFormat]
	}

	Return $DailyWorkTime, $DailyGapTime

}
