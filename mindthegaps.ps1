<#
.SYNOPSIS
	Powershell script that analyzes a folder of time-based screenshots (for example, TimeSnapper) to report timespans worked and total hours worked.
.DESCRIPTION
	This script was designed to work with folders like those created by the [TimeSnapper](http://www.timesnapper.com/) software application.  Timesnapper creates a new folder each day, and as you work it stores screenshots of your work every few seconds.  This is useful for tracking what you worked on, and when, throughout your work day.

	Although the tools and reporting from Timesnapper are excellent, manually analyzing the output into a summary for my notes each day was time consuming.  This script was created to automate it.

    Example of output:
		Thu:        5:56 am -  8:12 am:  2.3 hours  (136 minutes)
		            8:42 am - 11:19 am:  2.6 hours  (157 minutes)
		            1:11 pm -  1:15 pm:  0.1 hours    (4 minutes)
		            2:34 pm -  5:32 pm:  3.0 hours  (178 minutes)
		Total worked on Thu 2021-05-13:  7.9 hours  (475 minutes)
.NOTES
	File Name  : MindTheGaps.ps1
	Author     : James Medlin - james@themedlins.com
.LINK
	https://github.com/jmedlinz/MindTheGaps
.EXAMPLE
	.\mindthegaps.ps1

	Output will be the work done for that day, as analyzed from that day's folder of snapshot images:
		Wed:        6:10 am -  7:44 am:  1.6 hours   (94 minutes)
		            8:35 am - 11:06 am:  2.5 hours  (152 minutes)
		           11:39 am -  4:37 pm:  5.0 hours  (299 minutes)
		            5:12 pm -  7:34 pm:  2.4 hours  (143 minutes)
		            8:22 pm -  9:14 pm:  0.9 hours   (52 minutes)
		            9:36 pm -  9:41 pm:  0.1 hours    (4 minutes)
		Total worked on Wed 2021-05-12: 12.4 hours  (744 minutes)
.EXAMPLE
	.\mindthegaps.ps1 -1

	Will analyze the files in yesterday's folder.  The value can be specified as either a positive or negative integer, but it will target a previous folder either way.
.EXAMPLE
	.\mindthegaps.ps1 -DaysBack -7 -SkipDuplicates

	Will analyze data from a week ago, and will skip any duplicate files during the analysis.
.PARAMETER DaysBack
	The number of days back from today to process.  So, -1 would use the data from yesterday, and -7 would use the data from a week ago.  Since positive numbers are meaningless here, the sign is ignored: -7 and 7 would both use the data from a week ago.
	The default is today, ie 0.
.PARAMETER SkipDuplicates
	If this command is included then the images will be examined first for duplicates.  Only the first duplicate in the folder will be kept, all others will be ignored - even if the files was created later on in the day.
	Note that the check for duplicate files will take much longer to run than if the check is skipped.
	The default is FALSE, ie don't check for duplicate files.
.PARAMETER ShowGaps
	If this command is included then the script will output the gaps between work periods.
	The default is TRUE for this command, ie show the gaps.
	#>

#######################################################################

param (
	[int]$DaysBack = 0,
	[switch]$SkipDuplicates = $FALSE,
	[switch]$ShowGaps = $TRUE
)

$DaysBack = [math]::Abs($DaysBack)

# Load the constants.
. .\constants.ps1

# Include Compute-Daily-Stats, the main function to compute the stats for a day.
. .\fx_MindTheGaps.ps1

# Compute this day's stats.
Compute-Daily-Stats $DaysBack -SkipDuplicates:$SkipDuplicates -ShowGaps:$ShowGaps | Out-Null
