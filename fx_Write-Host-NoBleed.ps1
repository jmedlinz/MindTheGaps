<#
.SYNOPSIS
    The Write-Host-NoBleed function provides color-safe console output by preventing background color bleeding in PowerShell console windows.
.PARAMETER Message
    The text string to be written to the console.
.PARAMETER ForegroundColor
    The color to use for the text. Defaults to White if not specified.
    Accepts any valid System.ConsoleColor value.
.PARAMETER BackgroundColor
    The background color to use behind the text. Defaults to Black if not specified.
    Accepts any valid System.ConsoleColor value.
.PARAMETER NoNewline
    If specified, suppresses the newline after writing the message.
    When used, automatically handles console color bleeding by writing an empty black line.
#>

#######################################################################


#  This function handles the color bleeding issue when using Write-Host.
#  It writes the message with the specified foreground and background colors.
#  If the NoNewline switch is specified, it writes an empty line with black background to fix color bleeding.
function Write-Host-NoBleed {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [System.ConsoleColor]$ForegroundColor = 'White',

        [Parameter(Mandatory=$false)]
        [System.ConsoleColor]$BackgroundColor = 'Black',

        [Parameter(Mandatory=$false)]
        [switch]$NoNewline
    )

    Write-Host $Message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -NoNewline:$NoNewline

    # If NoNewline was specified, write an empty line with black background to fix color bleeding
    if ($NoNewline) {
        Write-Host "" -BackgroundColor Black
    }
}
