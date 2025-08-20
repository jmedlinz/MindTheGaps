<#
.SYNOPSIS
    The ConvertFrom-TimeString function parses time strings in both full and shorthand formats for consistent time parsing across MindTheGaps scripts.
.PARAMETER TimeString
    The time string to parse. Supports both full format (h:mmtt like "8:00pm") and shorthand format (htt like "8pm").
.EXAMPLE
    ConvertFrom-TimeString "8:00pm"
    Returns a DateTime object representing 8:00 PM
.EXAMPLE
    ConvertFrom-TimeString "8pm"
    Returns a DateTime object representing 8:00 PM (shorthand format)
.EXAMPLE
    ConvertFrom-TimeString "10:30am"
    Returns a DateTime object representing 10:30 AM
.NOTES
    This function tries the full format (h:mmtt) first, then falls back to shorthand format (htt).
    Throws an exception if neither format can be parsed.
#>

#######################################################################

# Function to parse time in both full and shorthand formats
function ConvertFrom-TimeString {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TimeString
    )

    # Try full format first (h:mmtt like "8:00pm")
    try {
        return [datetime]::parseexact($TimeString, 'h:mmtt', $null)
    }
    catch {
        # Try shorthand format (htt like "8pm")
        try {
            return [datetime]::parseexact($TimeString, 'htt', $null)
        }
        catch {
            throw "Invalid time format: $TimeString. Valid formats are 'h:mmtt' (like '8:00pm') or 'htt' (like '8pm')"
        }
    }
}
