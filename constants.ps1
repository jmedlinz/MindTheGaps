# Constant that indicates how many minutes of inactivity to ignore.
# If we're inactive for more than this many minutes then treat it as a break, and a gap begins.
Set-Variable BreakLimit -option Constant -value 15

# If we're not active for at least this many minutes, don't count it as "work".
Set-Variable WorkLimit -option Constant -value 3

#The file extension that the Filled files are saved in: png, jpg, gif, etc.
Set-Variable FileExt_Fill -option Constant -value "jpg"

# The prefix of all the renamed files.
Set-Variable ClearFilePrefix -option Constant -value "cleared-"

# The prefix of all the new files.
Set-Variable FillFilePrefix -option Constant -value "filled-"

# The folder containing the TimeSnapper app's Snapshot files.
Set-Variable SnapshotFolder -option Constant -value "D:\SnapShots\"

# The postfix for the corresponding folder of MindTheGap files.
Set-Variable ArchivePostfix -option Constant -value ".archive"

# The number of days worth of data to keep.
# !NOTE: Take care that this value matches the Timesnapper settings:
#        Timesnapper > Options > Archive tab > "Remove images old than: "
Set-Variable KeepFilesDays -option Constant -value 45
