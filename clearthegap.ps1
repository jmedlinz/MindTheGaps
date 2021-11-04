<#
.SYNOPSIS
    Powershell script that clears files from a folder of time-based screenshots (for example, TimeSnapper) to account for a period of time that you do not want to use (for example, personal time).
.DESCRIPTION
	This script was designed to work with folders like those created by the [TimeSnapper](http://www.timesnapper.com/) software application.  Timesnapper creates a new folder each day, and as you work it stores screenshots of your work every few seconds.  This is useful for tracking what you worked on, and when, throughout your work day.

    Sometimes you may use some personal time, for example at lunch, to do some browsing or other activities that you don't want to use for TimeTracker or MindTheGaps.  ClearTheGaps will "clear" a block of time so it's not recognized by either application anymore.

.NOTES
	File Name  : ClearTheGap.ps1
	Author     : James Medlin - james@themedlins.com
.LINK
	https://github.com/jmedlinz/MindTheGaps
.EXAMPLE
	.\clearthegap.ps1 9:30am 10:00am

	Output will be the files renamed for those times:
        J:\Snapshots\2019-12-27\cleared-09.30.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-09.35.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-09.40.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-09.45.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-09.50.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-09.55.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-10.00.00.0000.jpg
        J:\Snapshots\2019-12-27\cleared-10.00.01.0000.jpg

.EXAMPLE
	.\clearthegap.ps1 9:30pm 10:00pm -1

    Will rename the subset of files in yesterday's folder.  The value can be specified as either a positive or negative 1, but it will target a previous folder either way.

    If this example is run on Dec 27, 2019, the output would be:
        J:\Snapshots\2019-12-26\cleared-21.30.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-21.35.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-21.40.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-21.45.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-21.50.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-21.55.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-22.00.00.0000.jpg
        J:\Snapshots\2019-12-26\cleared-22.00.01.0000.jpg

.PARAMETER StartTime
    The time to start the file rename, ie the start of the gap.  The format is hh:mmtt.
    Valid values:
        10:30am
        9:00pm
    Invalid values:
        10:30 am
        9pm
.PARAMETER StopTime
    The time to stop the file rename, ie the end of the gap .  The format is hh:mmtt.
    Valid values:
        10:30am
        9:00pm
    Invalid values:
        10:30 am
        9pm
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
    [Parameter(Position = 2, HelpMessage="The number of days back to clear the files from.  Default is 0.  Yesterday would be -1.")]
    [int]$DaysBack = 0
 )

# Lets the script work with files in previous days/folders.
$DaysBack = [math]::Abs($DaysBack)

 # Load the common constants.
. ".\constants.ps1"

# The sub-folder to process.  Defaults to the current date.
$ThisDay = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")

# The base folder to the snapshot folders.
Set-Variable BasePath    -option Constant -value (Join-Path -Path $SnapshotFolder -ChildPath $ThisDay)
Set-Variable ArchivePath -option Constant -value ($BasePath + $ArchivePostfix)

$FileIndex = 0;

#######################################################################

# Test the params by converting the date strings to datetime-type variables.
try {
    $WorkStart = ([datetime]::parseexact($StartTime, 'h:mmtt', $null)).AddDays(-$DaysBack)
    $WorkStop  = ([datetime]::parseexact($StopTime,  'h:mmtt', $null)).AddDays(-$DaysBack)
}
catch {
    Write-Host ""
    Write-Host "Invalid values were supplied for the StartTime and/or StopTime parameters."
    Write-Host ""
    Write-Host "Valid values must be supplied for the StartTime and StopTime parameters."
    Write-Host "For example:"
    Write-Host "   clearthegap 9:30am 10:00am"
    Write-Host "This command would clear any files dated between 9:30 and 10am."
    Write-Host ""
    Exit
}

# No problems found with the params so rename the files (clear the gaps).

# Get a list of all the files in the target folders, sorted by the UTC CreationTime.
$BaseFiles    = Get-ChildItem "$BasePath"    -ErrorAction SilentlyContinue
$ArchiveFiles = Get-ChildItem "$ArchivePath" -ErrorAction SilentlyContinue
$AllFiles = $BaseFiles + $ArchiveFiles |
    Where-Object {$_.extension -in ".png",".jpg",".gif",".wmf",".tiff",".bmp",".emf"} |
    Where-Object { -not $_.PsIsContainer } |
    Where-Object {($_.Name -notlike "$ClearFilePrefix*")} |
    Where-Object {($_.LastWriteTime -le $WorkStop) -and ($_.LastWriteTime -ge $WorkStart)} |
    Sort-Object -Property @{Expression = "CreationTimeUtc"}, @{Expression = "Name"}

# "Clear" each of the files by renaming it.
Foreach ($ThisFile in $AllFiles) {

    $FileIndex += 1

    # If the archive folder isn't already created then create it now.
    if (-not (Test-Path $ArchivePath)) {
        New-Item -ItemType Directory -Path $ArchivePath -ErrorAction SilentlyContinue | Out-Null
    }

    # Move the file to the archive folder, renaming it with a "cleared-" prefix.
    $Old = $ThisFile.FullName
    $New = Join-Path -Path $ArchivePath -ChildPath $ClearFilePrefix$ThisFile
    Move-Item -Force -Path $Old -Destination $New

    # Write a status message for every 10th file.
    if (!($FileIndex%10)) {
        Write-Host "Clearing" -NoNewline -ForegroundColor Black -BackgroundColor Red
        Write-Host " $Old ..." -ForegroundColor Gray
    }
}

Write-Host ("Cleared {0} files from {1} to {2} on {3}." `
        -f $FileIndex, $WorkStart.ToString("h:mmtt").ToLower(), $WorkStop.ToString("h:mmtt").ToLower(), $WorkStart.ToString("M/d/yyyy"))
