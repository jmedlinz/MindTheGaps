<#
.SYNOPSIS
	Powershell script that analyzes a folder of time-based screenshots (for example, TimeSnapper) to report timespans worked and total hours worked for a week.
.DESCRIPTION
	This script was designed to work with folders like those created by the [TimeSnapper](http://www.timesnapper.com/) software application.  Timesnapper creates a new folder each day, and as you work it stores screenshots of your work every few seconds.  This is useful for tracking what you worked on, and when, throughout your work day.

	Although the tools and reporting from Timesnapper are excellent, manually analyzing the output into a summary for my notes each day was time consuming.  The MindTheGaps.psh powershell script was created to automate it.  This script, WeeklyGaps.psh, expands that by summarizing an entire week at once.

.NOTES
	File Name  : WeeklyGaps.ps1
	Author     : James Medlin - james@themedlins.com
.LINK
	https://github.com/jmedlinz/MindTheGaps
.EXAMPLE
	.\weeklygaps.ps1

	Output will be the work done for this week, starting on Saturday and ending with today.:
		Sat:       10:32 am - 10:47 am:  0.3 hours   (15 minutes)
		            6:25 pm -  6:33 pm:  0.1 hours    (8 minutes)
		Total worked on Sat 2021-05-15:  0.4 hours   (23 minutes)
		Sun:        7:04 am -  8:53 am:  1.8 hours  (109 minutes)
		            8:15 pm -  8:51 pm:  0.6 hours   (36 minutes)
		Total worked on Sun 2021-05-16:  2.4 hours  (144 minutes)
		Mon:        5:53 am -  6:59 am:  1.1 hours   (66 minutes)
		            8:00 am - 11:56 am:  3.9 hours  (236 minutes)
		           12:10 pm - 12:23 pm:  0.2 hours   (13 minutes)
		            1:09 pm -  2:10 pm:  1.0 hours   (60 minutes)
		            3:35 pm -  3:45 pm:  0.2 hours    (9 minutes)
		            3:58 pm -  4:18 pm:  0.3 hours   (20 minutes)
		            6:16 pm -  6:21 pm:  0.1 hours    (5 minutes)
		Total worked on Mon 2021-05-17:  6.8 hours  (409 minutes)
		Tue:        5:29 am -  8:35 am:  3.1 hours  (186 minutes)
		            8:57 am -  9:20 am:  0.4 hours   (23 minutes)
		Total worked on Tue 2021-05-18:  3.5 hours  (209 minutes)

		Total hours worked this week:   13.1 hours  (786 minutes)

.EXAMPLE
	.\weeklygaps.ps1 -1

	Will analyze the files in last week's folder.  The value can be specified as either a positive or negative integer, but it will target a previous week either way.  Previous weeks always start on Saturday and end on Friday.
.EXAMPLE
	.\weeklygaps.ps1 -WeeksBack -2 -SkipDuplicates

	Will analyze data from two weeks ago, and will skip any duplicate files during the analysis.
.EXAMPLE
	.\weeklygaps.ps1 -WeeksBack -1 -ExportWeeklyImage

	Will analyze last week and export the weekly summary image to the archive folder.
.PARAMETER WeeksBack
	The number of weeks back from today to process.  So, -1 would use the data from last week.  Since positive numbers are meaningless here, the sign is ignored: -1 and 1 would both use the data from a week ago.
	For the current week, the week starts on Saturday and ends on the current day.  For previous weeks, it starts on Saturday and ends on Friday.
	The default is this week, ie 0.
.PARAMETER SkipDuplicates
	If this command is included then the images will be examined first for duplicates.  Only the first duplicate in the folder will be kept, all others will be ignored - even if the files was created later on in the day.
	Note that the check for duplicate files will take much longer to run than if the check is skipped.
	The default is FALSE, ie don't check for duplicate files.
.PARAMETER ShowGaps
	If this command is included then the script will output the gaps between work periods.
	The default is FALSE, ie don't show the gaps.
.PARAMETER ExportWeeklyImage
	If this command is included then the script will export the weekly summary image to the archive folder.
	The default is FALSE, ie don't create an image.
#>

#######################################################################

param (
	[int]$WeeksBack = 0,
	[switch]$SkipDuplicates = $FALSE,
	[switch]$ShowGaps = $FALSE,
	[switch]$ExportWeeklyImage = $FALSE
)

$WeeksBack = [math]::Abs($WeeksBack)

$LastSaturday = ([System.Datetime] $(get-date).AddDays(1)).DayOfWeek.value__

$StartDaysAgo = ($WeeksBack * 7) + $LastSaturday
$StopDaysAgo  = ($WeeksBack * 7) + $LastSaturday - 7 + 1

if ($StopDaysAgo -lt 0) {
	$StopDaysAgo = 0
}

$WeeklyWorkTime = New-TimeSpan -Hours 0 -Minutes 0;
$WeeklyGapTime  = New-TimeSpan -Hours 0 -Minutes 0;

# Load the constants.
. .\constants.ps1

# Include PNG export helpers only when image export is requested.
if ($ExportWeeklyImage) {
	. .\fx_Export-WeeklyPng.ps1
	$script:WeeklyPngRows = @()
}

# Include Get-DailyStats, the main function to compute the stats for a day.
. .\fx_Get-DailyStats.ps1

# Compute this week's stats.
for ($DaysBack = $StartDaysAgo; $DaysBack -GE $StopDaysAgo; $DaysBack--) {

	$DailyWorkTime, $DailyGapTime = Get-DailyStats $DaysBack -SkipDuplicates:$SkipDuplicates -ShowGaps:$ShowGaps

	$WeeklyWorkTime += $DailyWorkTime
	$WeeklyGapTime  += $DailyGapTime
}

# Output the weekly hours worked.
$SummaryLabelWidth = 31
$WeeklyWorkedLabel = "Total hours worked this week:".PadRight($SummaryLabelWidth)
$WeeklyWorkedLabelConsole = "Total hours worked this week:   "
$WeeklyWorkedDetail = ("{0} hours {1} minutes)" -f `
		$WeeklyWorkTime.TotalHours.ToString("0.0").PadLeft(4), `
		$WeeklyWorkTime.TotalMinutes.ToString("(0").PadLeft(5))

if ($ExportWeeklyImage) {
	Add-WeeklyPngRow -Segments @(
		[pscustomobject]@{ Text = $WeeklyWorkedLabel; ForegroundColor = "Black"; BackgroundColor = "White" }
		[pscustomobject]@{ Text = $WeeklyWorkedDetail; ForegroundColor = "DarkGreen"; BackgroundColor = "White" }
	) -Underline:(-not $ShowGaps)
}

Write-Host $WeeklyWorkedLabelConsole -ForegroundColor Black -BackgroundColor White -NoNewline
Write-ConsoleMessage ("{0} hours {1} minutes)" -f `
		$WeeklyWorkTime.TotalHours.ToString("0.0").PadLeft(4), `
		$WeeklyWorkTime.TotalMinutes.ToString("(0").PadLeft(5))    `
		-ForegroundColor DarkGreen `
		-BackgroundColor White `
		-NoNewline

# If we're showing gaps then output the weekly gap hours and the weekly total time spent.
if ($ShowGaps) {
	$WeeklyGapLabel = "Total gap hours this week:      "
	$WeeklyGapDetail = ("{0} hours {1} minutes)" -f `
		$WeeklyGapTime.TotalHours.ToString("0.0").PadLeft(4), `
		$WeeklyGapTime.TotalMinutes.ToString("(0").PadLeft(5))

	if ($ExportWeeklyImage) {
		Add-WeeklyPngRow -Segments @(
			[pscustomobject]@{ Text = $WeeklyGapLabel; ForegroundColor = "Black"; BackgroundColor = "White" }
			[pscustomobject]@{ Text = $WeeklyGapDetail; ForegroundColor = "DarkRed"; BackgroundColor = "White" }
		)
	}

	Write-Host ("Total gap hours this week:      ") -ForegroundColor Black -BackgroundColor White -NoNewline
	Write-ConsoleMessage ("{0} hours {1} minutes)" -f `
		$WeeklyGapTime.TotalHours.ToString("0.0").PadLeft(4), `
		$WeeklyGapTime.TotalMinutes.ToString("(0").PadLeft(5))    `
		-ForegroundColor DarkRed `
		-BackgroundColor White `
		-NoNewline

	$WeeklyTotalTime = $WeeklyWorkTime + $WeeklyGapTime
	$WeeklySpentLabel = "Total hours spent this week:    "
	$WeeklySpentDetail = ("{0} hours {1} minutes)" -f `
		$WeeklyTotalTime.TotalHours.ToString("0.0").PadLeft(4), `
		$WeeklyTotalTime.TotalMinutes.ToString("(0").PadLeft(5))

	if ($ExportWeeklyImage) {
		Add-WeeklyPngRow -Segments @(
			[pscustomobject]@{ Text = $WeeklySpentLabel; ForegroundColor = "Black"; BackgroundColor = "White" }
			[pscustomobject]@{ Text = $WeeklySpentDetail; ForegroundColor = "DarkMagenta"; BackgroundColor = "White" }
		) -Underline
	}

	Write-Host ("Total hours spent this week:    ") -NoNewline -ForegroundColor Black -BackgroundColor White
	Write-ConsoleMessage ("{0} hours {1} minutes)" -f `
		$WeeklyTotalTime.TotalHours.ToString("0.0").PadLeft(4), `
		$WeeklyTotalTime.TotalMinutes.ToString("(0").PadLeft(5))    `
		-ForegroundColor DarkMagenta `
		-BackgroundColor White `
		-NoNewline
}

if ($ExportWeeklyImage) {
	try {
		$ArchiveFolder = Join-Path -Path $PSScriptRoot -ChildPath "archive"
		$WeekEndingStamp = (Get-Date).AddDays(-$StopDaysAgo).ToString("yyyyMMdd")
		$ImagePath = Join-Path -Path $ArchiveFolder -ChildPath ("mtg_weekly_{0}.png" -f $WeekEndingStamp)

		Export-WeeklyPng -Rows (Get-WeeklyPngRows) -OutputPath $ImagePath
		Write-Host ("Weekly PNG saved: {0}" -f $ImagePath) -ForegroundColor DarkGray
	} catch {
		Write-Warning ("Could not export weekly PNG: {0}" -f $_.Exception.Message)
	}
}
