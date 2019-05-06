# Constant that indicates how many minutes of inactivity to ignore.  
# If we're inactive for more than this many minutes then treat it as a break, and a gap begins.
$BreakLimit = 10;

# If we're not active for at least this many minutes, don't count it as "work".
$WorkLimit = 10;

$FileIndex = 0;
$TotalWorkTimeDiff = 0;

#######################################################################

$Files = Get-ChildItem "J:\Snapshots\2019-05-05" -Filter *.jpg | 
Where-Object { -not $_.PsIsContainer } | 
Sort-Object -Property @{Expression = "CreationTimeUtc"}, @{Expression = "Name"}

$LastFile = ($Files | Measure-Object).Count

$Files | 
Foreach-Object {

    $FileIndex += 1
    $SnapshotFile = $_

    # If this is the first file we're examining, set up the tracking variables.
    if ($FileIndex -eq 1) {

        Write-Host "Processing $LastFile files"

        # This is when we first start working.
        $BeginFile = $SnapshotFile

        $LastSnapshotFile = $SnapshotFile

    } else {

        # Use UTC so we don't have to worry about accounting for Daylight Saving times.
        $FileTimeDiff = $SnapshotFile.CreationTimeUtc - $LastSnapshotFile.CreationTimeUtc

        # If the time difference between the last two files is greater than the BreakLimit then treat it as a break.
        if ($FileTimeDiff.TotalMinutes -ge $BreakLimit -or $FileIndex -eq $LastFile) {

            $WorkTimeDiff = $LastSnapshotFile.CreationTimeUtc - $BeginFile.CreationTimeUtc

            if ($WorkTimeDiff.TotalMinutes -ge $WorkLimit) {

                $TotalWorkTimeDiff += $WorkTimeDiff.TotalMinutes

                $WorkTimeStringHours   = [math]::Round($WorkTimeDiff.TotalHours, 1)
                $WorkTimeStringMinutes = [math]::Round($WorkTimeDiff.TotalMinutes)
                $StartString    = $BeginFile.CreationTime.ToShortTimeString().ToLower()
                $FinishString   = $LastSnapshotFile.CreationTime.ToShortTimeString().ToLower()

                Write-Host "$StartString - $FinishString : $WorkTimeStringHours hours ($WorkTimeStringMinutes minutes)"

            }

            $BeginFile = $SnapshotFile

        }

        $LastSnapshotFile = $SnapshotFile

    }

}

$TotalWorkTimeStringHours   = [math]::Round($TotalWorkTimeDiff/60, 1)
$TotalWorkTimeStringMinutes = [math]::Round($TotalWorkTimeDiff)
Write-Host "Total worked: $TotalWorkTimeStringHours hours ($TotalWorkTimeStringMinutes minutes)"
