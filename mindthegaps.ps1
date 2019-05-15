<#
.SYNOPSIS
	Powershell script that analyzes a folder of time-based screenshots (for example, TimeSnapper) to report timespans worked and total hours worked.
.DESCRIPTION
	This script was designed to work with folders like those created by the [TimeSnapper](http://www.timesnapper.com/) software application.  Timesnapper create a new folder each day, and as you work it stores screenshots of your work every few seconds.  This is useful for tracking what you worked on, and when, throughout your work day.

	Although the tools and reporting from Timesnapper are excellent, manually analyzing the output into a summary for my notes each day was time consuming.  This script was created to automate it.

	Example of output:
	9:44 am - 10:18 am : 0.6 hours (34 minutes)
	12:00 pm - 12:33 pm : 0.6 hours (33 minutes)
	12:55 pm - 1:53 pm : 1 hours (59 minutes)
	2:22 pm - 4:24 pm : 2 hours (122 minutes)
	Total worked: 4.1 hours (247 minutes)
.NOTES
	File Name  : MindTheGaps.ps1
	Author     : James Medlin - james@themedlins.com
.LINK
	https://github.com/jmedlinz/MindTheGaps
.EXAMPLE
	.\mindthegaps.ps1

	Output will be the work done for that day, as analyzed from that day's folder of snapshot images:
		7:52 am - 8:15 am : 0.4 hours (23 minutes)
		8:26 am - 11:37 am : 3.2 hours (191 minutes)
		12:57 pm - 1:52 pm : 0.9 hours (55 minutes)
		2:33 pm - 4:04 pm : 1.5 hours (91 minutes)
		8:33 pm - 8:59 pm : 0.4 hours (26 minutes)
		Total worked: 6.4 hours (386 minutes)
.EXAMPLE
	.\mindthegaps.ps1 -1

	Will analyze the files in yesterday's folder.  The value can be specified as either a positive or negative 1, but it will target yesterday's folder either way.
.EXAMPLE
	.\mindthegaps.ps1 -DaysBack -7 -SkipDuplicates 

	Will analyze data from a week ago, and will skip any duplicate files during the analysis.
.PARAMETER DaysBack
	The number of days back from today to process.  So, -1 would use the data from yesterday, and -7 would use the data from a week ago.  Since positive numbers are meaningless here, the sign is ignored: -7 and 7 would both use the data from a week ago.
	The default is today, ie 0.
.PARAMETER SkipDuplicates
	If this command is included then the images will be examined first for duplicates.  Only the first duplicate in the folder will be kept, all others will be ignored - even if the files was created later on in the day.
	Note that the check for duplicate files may take much longer to run that if the check is skipped.
	The default is TRUE, ie skip any duplicate files.
#>

#######################################################################

param (
	[int]$DaysBack = 0,
	[switch]$SkipDuplicates = $FALSE
 )

##################

# Constant that indicates how many minutes of inactivity to ignore.
# If we're inactive for more than this many minutes then treat it as a break, and a gap begins.
$BreakLimit = 10;

# If we're not active for at least this many minutes, don't count it as "work".
$WorkLimit = 10;

# The base folder to the snapshot folders.
$BasePath = "J:\Snapshots"

#The file extension that the files are saved in: png, jpg, gif, etc.
$FileExt = "jpg"

##################

$FileIndex = 0;
$TotalWorkTime = New-TimeSpan -Hours 0 -Minutes 0;

#######################################################################

$DaysBack = [math]::Abs($DaysBack)

# The sub-folder to process.  Defaults to the current date.
$ThisDay = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")

# Get a list of all the files in the target folder, sorted by the UTC CreationTime.
# Use UTC in all the internal calculations so we don't have to worry about Daylight Saving times.
$Files = Get-ChildItem "$BasePath\$ThisDay" -Filter "*.$FileExt" |
Where-Object { -not $_.PsIsContainer } |
Sort-Object -Property @{Expression = "CreationTimeUtc"}, @{Expression = "Name"}

$LastIndex = ($Files | Measure-Object).Count

if ($SkipDuplicates) {
	# Find files containing duplicate images.
	# Credit: https://stackoverflow.com/questions/16845674/removing-duplicate-files-with-powershell
	$DuplicateFiles = 
		Get-ChildItem "$BasePath\$ThisDay" | 
		Get-FileHash -Algorithm MD5 |
		Group-Object -Property Hash |
		Where-Object -Property Count -gt 1 |
		ForEach-Object {
			$_.Group.Path |
			Select -First ($_.Count -1)}
}

Foreach ($ThisFile in $Files) {

	$FileIndex += 1

	if (-not $SkipDuplicates -or $DuplicateFiles -notcontains $ThisFile.FullName) {

		# If this is the first file we're examining, set up the tracking variables.
		if ($FileIndex -eq 1) {

			Write-Output "Processing $LastIndex files in the $ThisDay folder"

			# This is when we first start working.
			$StartWork = $ThisFile

			$LastFile = $ThisFile

		} else {

			Write-Information ("T.utc={0} T={1} S={2} L={3}" `
					-f $ThisFile.CreationTimeUtc, $ThisFile.Name, $StartWork.Name, $LastFile.Name)

			$FileTimeDiff = $ThisFile.CreationTimeUtc - $LastFile.CreationTimeUtc

			# If the time difference between the last two files is greater than the BreakLimit then treat it as a break.
			if ($FileTimeDiff.TotalMinutes -ge $BreakLimit -or $FileIndex -eq $LastIndex) {

				# If the time difference between the last and first files is greater than the WorkLimit then treat it as work.
				$WorkTimeDiff = $LastFile.CreationTimeUtc - $StartWork.CreationTimeUtc

				if ($WorkTimeDiff.TotalMinutes -ge $WorkLimit) {

					$TotalWorkTime += $WorkTimeDiff

					#Output a line showing the timespan, the hours worked, and minutes worked.
					$WorkTimeStringHours   = [math]::Round($WorkTimeDiff.TotalHours, 1)
					$WorkTimeStringMinutes = [math]::Round($WorkTimeDiff.TotalMinutes)
					$StartString    = $StartWork.CreationTime.ToShortTimeString().ToLower()
					$FinishString   = $LastFile.CreationTime.ToShortTimeString().ToLower()
					Write-Output ("{0} - {1} : {2} hours ({3} minutes)"  `
							-f $StartString, $FinishString,              `
							   $WorkTimeDiff.TotalHours.ToString("0.0"), `
							   $WorkTimeDiff.TotalMinutes.ToString("0"))

				}

				$StartWork = $ThisFile

			}

			$LastFile = $ThisFile

		}

	} else {

		Write-Information ("T={0} Skipped" -f $ThisFile.Name)

	}

}

Write-Output ("Total worked: {0} hours ({1} minutes)" `
		-f $TotalWorkTime.TotalHours.ToString("0.0"), $TotalWorkTime.TotalMinutes.ToString("0"))
