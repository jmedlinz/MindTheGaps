<#
.SYNOPSIS
    The ConvertFrom-TimeString function parses time strings in both full and shorthand formats for consistent time parsing across MindTheGaps scripts.
.PARAMETER TimeString
    The time string to parse. Supports multiple formats:
    - Full format: h:mmtt (like "8:00pm")
    - Short format: htt (like "8pm")
    - Abbreviated PM format: h:mmp (like "8:01p")
    - Abbreviated AM format: h:mma (like "8:01a")
    - Ultra-short PM format: hp (like "8p")
    - Ultra-short AM format: ha (like "8a")
.EXAMPLE
    ConvertFrom-TimeString "8:00pm"
    Returns a DateTime object representing 8:00 PM
.EXAMPLE
    ConvertFrom-TimeString "8pm"
    Returns a DateTime object representing 8:00 PM (shorthand format)
.EXAMPLE
    ConvertFrom-TimeString "5:55p"
    Returns a DateTime object representing 5:55 PM (abbreviated PM format)
.EXAMPLE
    ConvertFrom-TimeString "8a"
    Returns a DateTime object representing 8:00 AM (ultra-short AM format)
.NOTES
    This function tries multiple formats in order of specificity.
    Throws an exception if no format can be parsed.
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
            # Try abbreviated format with uppercase (h:mmt like "4:15P")
            try {
                return [datetime]::parseexact($TimeString.ToUpper(), 'h:mmt', $null)
            }
            catch {
                # Try ultra-short format with uppercase (ht like "5P")
                try {
                    return [datetime]::parseexact($TimeString.ToUpper(), 'ht', $null)
                }
                catch {
                    throw "Invalid time format: $TimeString. Valid formats are 'h:mmtt' (like '8:00pm'), 'htt' (like '8pm'), 'h:mmt' (like '8:01p'), or 'ht' (like '8p')"
                }
            }
        }
    }
}
