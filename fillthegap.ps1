<#
.SYNOPSIS
    Powershell script that adds new files to a folder of time-based screenshots (for example, TimeSnapper) to account for a meeting or other activity that did not generate (enough) files in the folder.
.DESCRIPTION
	This script was designed to work with folders like those created by the [TimeSnapper](http://www.timesnapper.com/) software application.  Timesnapper creates a new folder each day, and as you work it stores screenshots of your work every few seconds.  This is useful for tracking what you worked on, and when, throughout your work day.

	Although the tools and reporting from Timesnapper are excellent, sometimes during an online meeting or webinar no files would be generated due to no activity (by me) on the PC.  Other times I may have a meeting in another location, away from the PC.  This resulted in the MindTheGaps script showing gaps in my activity when I was actually working.

	Instead of having to manually account for these times outside of the MindTheGaps script, the FillTheGap script was created to fill these gaps.

.NOTES
	File Name  : FillTheGap.ps1
	Author     : James Medlin - james@themedlins.com
.LINK
	https://github.com/jmedlinz/MindTheGaps
.EXAMPLE
	.\fillthegap.ps1 9:30am 10:00am

	Output will be the files created for those times:
        Created J:\Snapshots\2019-12-27\filled-09.30.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-09.35.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-09.40.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-09.45.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-09.50.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-09.55.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-10.00.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-10.00.01.0000.jpg

.EXAMPLE
	.\fillthegap.ps1 9:30am 10am

	Same as above but using shorthand time format (no minutes specified for end time):
        Created J:\Snapshots\2019-12-27\filled-09.30.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-09.35.00.0000.jpg
        ...
        Created J:\Snapshots\2019-12-27\filled-10.00.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-10.00.01.0000.jpg

.EXAMPLE
	.\fillthegap.ps1 8a 9p

	Using ultra-short format for both start and end times:
        Created J:\Snapshots\2019-12-27\filled-08.00.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-08.05.00.0000.jpg
        ...
        Created J:\Snapshots\2019-12-27\filled-21.00.00.0000.jpg
        Created J:\Snapshots\2019-12-27\filled-21.00.01.0000.jpg

.EXAMPLE
	.\fillthegap.ps1 9:30pm 10:00pm -1

    Will create the files in yesterday's folder.  The value can be specified as either a positive or negative 1, but it will target a previous folder either way.

    If this example is run on Dec 27, 2019, the output would be:
        Created J:\Snapshots\2019-12-26\filled-21.30.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-21.35.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-21.40.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-21.45.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-21.50.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-21.55.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-22.00.00.0000.jpg
        Created J:\Snapshots\2019-12-26\filled-22.00.01.0000.jpg

.PARAMETER StartTime
    The time to start the file creation, ie the start of the gap or meeting.  Supports multiple time formats.
    Valid values:
        10:30am (full format)
        9:00pm (full format)
        8pm (short format)
        12am (short format)
        8:01a (abbreviated format)
        5:55p (abbreviated format)
        8a (ultra-short format)
        5p (ultra-short format)
    Invalid values:
        10:30 am (space before am/pm)
        9 pm (space before am/pm)
.PARAMETER StopTime
    The time to stop the file creation, ie the end of the gap or meeting.  Supports multiple time formats.
    Valid values:
        10:30am (full format)
        9:00pm (full format)
        8pm (short format)
        12am (short format)
        8:01a (abbreviated format)
        5:55p (abbreviated format)
        8a (ultra-short format)
        5p (ultra-short format)
    Invalid values:
        10:30 am (space before am/pm)
        9 pm (space before am/pm)
.PARAMETER DaysBack
	The number of days back from today to process.  So, -1 would use the data from yesterday, and -7 would use the data from a week ago.  Since positive numbers are meaningless here, the sign is ignored: -7 and 7 would both use the data from a week ago.
	The default is today, ie 0.
#>

#######################################################################

param (
    [Parameter(Position = 0, Mandatory=$True, HelpMessage="Enter the Start Time, for example: 9:00am")]
    [ValidateNotNull()]
    [string]$StartTime,
    [Parameter(Position = 1, Mandatory=$True, HelpMessage="Enter the Stop Time, for example: 9:30am")]
    [ValidateNotNull()]
    [string]$StopTime,
    [Parameter(Position = 2, HelpMessage="The number of days back to create the file in.  Default is 0.  Yesterday would be -1.")]
    [int]$DaysBack = 0
 )

# Lets the script create files in previous days/folders.
$DaysBack = [math]::Abs($DaysBack)

 # Load the common constants.
. ".\constants.ps1"

# Load the time parsing function.
. ".\fx_ConvertFrom-TimeString.ps1"

# The sub-folder to process.  Defaults to the current date.
$ThisDay = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")

# The base folder to the snapshot folders.
Set-Variable BasePath    -option Constant -value (Join-Path -Path $SnapshotFolder -ChildPath $ThisDay)
Set-Variable ArchivePath -option Constant -value ($BasePath + $ArchivePostfix)

# This is the minimal time between files.
#    Creating a file every minute unnecessarily uses more storage and processing time.
#    Creating a file every $BreakLimit isn't long enough.
#    Creating a file every $BreakLimit-1 fails if $Breaklimit is set to 1.
# The formula used below avoids these issues and should work for all values of $Breaklimit while still being somewhat efficient.
Set-Variable MinimalGap -option Constant -value (New-TimeSpan -Minutes ([int][Math]::Ceiling($BreakLimit / 4)))

# A gap of 1 second.  Used for a workaround - see below for more info.
Set-Variable FinalGap -option Constant -value (New-TimeSpan -Seconds 1)

$global:FileIndex = 0;

# This function takes care of creating a file and setting the Create and Modified dates.
function CreateDatedFile {
    $FileDateTime = $args[0]

    # The full path of the file that will be created.
    $WorkFile = "$ArchivePath\$FillFilePrefix" + $FileDateTime.ToString("HH.mm.ss.ffff") + ".$FileExt_Fill"

    # Create the file.
    New-Item -Path $WorkFile -ItemType File -Force | Out-Null

    # Change the Creation and Modified dates.
    Get-ChildItem $WorkFile | ForEach-Object {$_.CreationTime  = $FileDateTime}
    Get-ChildItem $WorkFile | ForEach-Object {$_.LastWriteTime = $FileDateTime}

    Write-Host "Created" -NoNewline -ForegroundColor Black -BackgroundColor Green
    Write-Host " $WorkFile" -ForegroundColor Gray

    $global:FileIndex += 1
}

#######################################################################

# Test the params by converting the date strings to datetime-type variables.
try {
    $WorkStart = (ConvertFrom-TimeString $StartTime).AddDays(-$DaysBack)
    $WorkStop  = (ConvertFrom-TimeString $StopTime).AddDays(-$DaysBack)
}
catch {
    Write-Host ""
    Write-Host "Invalid values were supplied for the StartTime and/or StopTime parameters."
    Write-Host ""
    Write-Host "Valid values must be supplied for the StartTime and StopTime parameters."
    Write-Host "For example:"
    Write-Host "   fillthegap 9:30am 10:00am"
    Write-Host "   fillthegap 9:30am 10am"
    Write-Host "   fillthegap 9:30a 10a"
    Write-Host "This command would create several new files dated between 9:30 and 10am."
    Write-Host ""
    Exit
}

# No problems found with the params so create the files (fill the gaps).

# If the archive folder isn't already created then create it now.
if (-not (Test-Path $ArchivePath)) {
    New-Item -ItemType Directory -Path $ArchivePath -ErrorAction SilentlyContinue | Out-Null
}

# Loop through the date range, creating a file every $MinimalGap minutes.
$WorkTime = $WorkStart
while ($WorkTime -lt $WorkStop) {
    CreateDatedFile $WorkTime
    $WorkTime = $WorkTime + $MinimalGap
}

# Always create a file for when the gap stops too.
# (Using an -lte in the while loop above won't always insure this file is created.)
CreateDatedFile $WorkStop

# Due to the design of the MindTheGaps script, if there's not another file after the $WorkStop file then the final
# file in our date range won't get used by MindTheGaps.  It should probably be redesigned and fixed, but in
# practice this almost never occurs since TimeSnapper creates so many files.
# As a workaround, we'll just create one more file dated 1 second later to make sure it's not an issue.
CreateDatedFile ($WorkStop + $FinalGap)

Write-Host ("Filled {0} files from {1} to {2} on {3}." `
        -f $global:FileIndex, $WorkStart.ToString("h:mmtt").ToLower(), $WorkStop.ToString("h:mmtt").ToLower(), $WorkStart.ToString("M/d/yyyy"))
