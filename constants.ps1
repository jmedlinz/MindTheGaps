# Constant that indicates how many minutes of inactivity to ignore.
# If we're inactive for more than this many minutes then treat it as a break, and a gap begins.
#$BreakLimit = 10;
Set-Variable BreakLimit -option Constant -value 15

# If we're not active for at least this many minutes, don't count it as "work".
#$WorkLimit = 10;
Set-Variable WorkLimit -option Constant -value 8

# The sub-folder to process.  Defaults to the current date.
$ThisDay = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")

# The base folder to the snapshot folders.
#$BasePath = "J:\Snapshots"
#Set-Variable BasePath -option Constant -value "c:\temp\gaps\$ThisDay"
Set-Variable BasePath -option Constant -value "J:\Snapshots\$ThisDay"

#The file extension that the files are saved in: png, jpg, gif, etc.
#$FileExt = "jpg"
Set-Variable FileExt -option Constant -value "jpg"
