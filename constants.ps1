# Constant that indicates how many minutes of inactivity to ignore.
# If we're inactive for more than this many minutes then treat it as a break, and a gap begins.
#$BreakLimit = 10;
Set-Variable BreakLimit -option Constant -value 12

# If we're not active for at least this many minutes, don't count it as "work".
#$WorkLimit = 10;
Set-Variable WorkLimit -option Constant -value 4

#The file extension that the files are saved in: png, jpg, gif, etc.
#$FileExt = "jpg"
Set-Variable FileExt -option Constant -value "jpg"

# The prefix of all the renamed files.
Set-Variable ClearFilePrefix -option Constant -value "cleared-"

# The prefix of all the new files.
Set-Variable FillFilePrefix -option Constant -value "filled-"
