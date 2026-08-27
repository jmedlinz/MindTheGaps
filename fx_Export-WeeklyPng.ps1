<#
.SYNOPSIS
    Collects weekly report rows and exports them as a PNG image.
#>

#######################################################################

$script:WeeklyPngRows = @()

function Add-WeeklyPngRow {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Segments,

        [Parameter(Mandatory = $false)]
        [switch]$Underline
    )

    $script:WeeklyPngRows += [pscustomobject]@{
        Segments  = $Segments
        Underline = [bool]$Underline
    }
}

function Get-WeeklyPngRows {
    return $script:WeeklyPngRows
}

function ConvertTo-DrawColor {
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConsoleColorName = "Black"
    )

    switch ($ConsoleColorName) {
        "Black"      { return [System.Drawing.Color]::FromArgb(0, 0, 0) }
        "White"      { return [System.Drawing.Color]::FromArgb(255, 255, 255) }
        "DarkGreen"  { return [System.Drawing.Color]::FromArgb(0, 100, 0) }
        "DarkRed"    { return [System.Drawing.Color]::FromArgb(165, 55, 55) }
        "DarkMagenta"{ return [System.Drawing.Color]::FromArgb(140, 55, 140) }
        "DarkGray"   { return [System.Drawing.Color]::FromArgb(105, 105, 105) }
        "DarkCyan"   { return [System.Drawing.Color]::FromArgb(0, 139, 139) }
        "DarkYellow" { return [System.Drawing.Color]::FromArgb(184, 134, 11) }
        "Green"      { return [System.Drawing.Color]::FromArgb(0, 128, 0) }
        "Magenta"    { return [System.Drawing.Color]::FromArgb(140, 55, 140) }
        "Red"        { return [System.Drawing.Color]::FromArgb(165, 55, 55) }
        default        { return [System.Drawing.Color]::FromArgb(0, 0, 0) }
    }
}

function Get-ReportFont {
    param (
        [Parameter(Mandatory = $false)]
        [float]$Size = 14
    )

    foreach ($fontName in @("Consolas", "Courier New", "Lucida Console")) {
        try {
            return New-Object System.Drawing.Font($fontName, $Size, [System.Drawing.FontStyle]::Regular)
        } catch {
            # Try the next fallback font.
        }
    }

    return New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace, $Size, [System.Drawing.FontStyle]::Regular)
}

function Measure-ReportLayout {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Rows,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Graphics]$Graphics,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Font]$Font
    )

    $stringFormat = [System.Drawing.StringFormat]::GenericTypographic
    $stringFormat.FormatFlags = $stringFormat.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

    $charSize = $Graphics.MeasureString("M", $Font, 5000, $stringFormat)
    $lineSize = $Graphics.MeasureString("Mg", $Font, 5000, $stringFormat)
    $charWidth = [double][math]::Ceiling($charSize.Width)
    $lineHeight = [double][math]::Ceiling($lineSize.Height)

    if ($charWidth -lt 1) {
        $charWidth = 1
    }

    if ($lineHeight -lt 1) {
        $lineHeight = 1
    }

    $maxWidth = 0.0
    $lineHeights = @()
    $segmentWidthsByRow = @()

    foreach ($row in $Rows) {
        $rowWidth = 0.0
        $rowLineHeight = $lineHeight
        $segmentWidths = @()

        foreach ($segment in $row.Segments) {
            $text = [string]$segment.Text
            if ($null -eq $text) {
                $text = ""
            }

            $segmentWidth = [double]($text.Length * $charWidth)
            $segmentWidths += $segmentWidth
            $rowWidth += $segmentWidth
        }

        if ($rowWidth -gt $maxWidth) {
            $maxWidth = $rowWidth
        }

        $lineHeights += $rowLineHeight
        $segmentWidthsByRow += ,$segmentWidths
    }

    return [pscustomobject]@{
        MaxWidth          = $maxWidth
        LineHeights       = $lineHeights
        SegmentWidthsByRow = $segmentWidthsByRow
    }
}

function Export-WeeklyPng {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Rows,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if ($Rows.Count -eq 0) {
        return
    }

    Add-Type -AssemblyName System.Drawing

    $renderScale = 0.8
    $font = Get-ReportFont -Size (14 * $renderScale)
    $paddingX = 0
    $paddingY = 0
    $rowSpacing = 0
    $borderThickness = 1
    $backgroundColor = [System.Drawing.Color]::FromArgb(20, 20, 20)

    $measureBitmap = New-Object System.Drawing.Bitmap(1, 1)
    $measureGraphics = [System.Drawing.Graphics]::FromImage($measureBitmap)

    try {
        $layout = Measure-ReportLayout -Rows $Rows -Graphics $measureGraphics -Font $font
    } finally {
        $measureGraphics.Dispose()
        $measureBitmap.Dispose()
    }

    $contentHeight = 0
    foreach ($lineHeight in $layout.LineHeights) {
        $contentHeight += [math]::Ceiling($lineHeight)
    }

    $contentHeight += [math]::Max(0, ($Rows.Count - 1) * $rowSpacing)

    $maxWidth = [double]($layout.MaxWidth | Select-Object -First 1)
    $width = [int][math]::Ceiling($maxWidth + ($paddingX * 2) + ($borderThickness * 2))
    $height = [int][math]::Ceiling(([double]$contentHeight) + ($paddingY * 2) + ($borderThickness * 2))

    if ($width -lt 320) {
        $width = 320
    }

    if ($height -lt 120) {
        $height = 120
    }

    $parent = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $canvasWidth = [int]($width | Select-Object -First 1)
    $canvasHeight = [int]($height | Select-Object -First 1)

    $bitmap = New-Object System.Drawing.Bitmap($canvasWidth, $canvasHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        $graphics.Clear($backgroundColor)

        $innerX = [int]$borderThickness
        $innerY = [int]$borderThickness
        $innerWidth = [int]($canvasWidth - ($borderThickness * 2))
        $innerHeight = [int]($canvasHeight - ($borderThickness * 2))
        $innerBrush = New-Object System.Drawing.SolidBrush($backgroundColor)
        $graphics.FillRectangle($innerBrush, $innerX, $innerY, $innerWidth, $innerHeight)
        $innerBrush.Dispose()

        $y = $borderThickness + $paddingY

        for ($i = 0; $i -lt $Rows.Count; $i++) {
            $row = $Rows[$i]
            $lineHeight = [int][math]::Ceiling($layout.LineHeights[$i])
            $rowStartX = $borderThickness + $paddingX
            $x = $rowStartX

            for ($j = 0; $j -lt $row.Segments.Count; $j++) {
                $segment = $row.Segments[$j]
                $segmentWidth = [int][math]::Ceiling($layout.SegmentWidthsByRow[$i][$j])
                if ($segmentWidth -le 0) {
                    continue
                }

                $fgColor = ConvertTo-DrawColor -ConsoleColorName ([string]$segment.ForegroundColor)
                $bgColor = ConvertTo-DrawColor -ConsoleColorName ([string]$segment.BackgroundColor)
                if ([string]$segment.BackgroundColor -eq "Black") {
                    $bgColor = $backgroundColor
                }

                $bgBrush = New-Object System.Drawing.SolidBrush($bgColor)
                $graphics.FillRectangle($bgBrush, $x, $y, $segmentWidth, $lineHeight)
                $bgBrush.Dispose()

                $fgBrush = New-Object System.Drawing.SolidBrush($fgColor)
                $graphics.DrawString(([string]$segment.Text), $font, $fgBrush, $x, $y)
                $fgBrush.Dispose()

                $x += $segmentWidth
            }

            if ($row.Underline -and $x -gt $rowStartX) {
                $underlineY = $y + $lineHeight - 1
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1)
                $graphics.DrawLine($pen, $rowStartX, $underlineY, $x - 1, $underlineY)
                $pen.Dispose()
            }

            $y += $lineHeight + $rowSpacing
        }

        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, $borderThickness)
        $graphics.DrawLine($borderPen, 0, 0, $canvasWidth - 1, 0)
        $graphics.DrawLine($borderPen, 0, 0, 0, $canvasHeight - 1)
        $graphics.DrawLine($borderPen, 0, $canvasHeight - 1, $canvasWidth - 1, $canvasHeight - 1)
        $borderPen.Dispose()

        $trimmedWidth = $canvasWidth
        while ($trimmedWidth -gt 1) {
            $x = $trimmedWidth - 1
            $hasNonBlackPixel = $false

            for ($scanY = 0; $scanY -lt $canvasHeight; $scanY++) {
                $scanColor = $bitmap.GetPixel($x, $scanY)
                if ($scanColor.R -ne $backgroundColor.R -or $scanColor.G -ne $backgroundColor.G -or $scanColor.B -ne $backgroundColor.B) {
                    $hasNonBlackPixel = $true
                    break
                }
            }

            if ($hasNonBlackPixel) {
                break
            }

            $trimmedWidth--
        }

        if ($trimmedWidth -lt $canvasWidth) {
            # Keep one trailing column for the right-side border.
            $trimmedWidth = [math]::Min($canvasWidth, $trimmedWidth + $borderThickness)

            $croppedBitmap = New-Object System.Drawing.Bitmap($trimmedWidth, $canvasHeight)
            $croppedGraphics = [System.Drawing.Graphics]::FromImage($croppedBitmap)
            try {
                $sourceRect = New-Object System.Drawing.Rectangle(0, 0, $trimmedWidth, $canvasHeight)
                $croppedGraphics.DrawImage($bitmap, $sourceRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)

                $finalBorderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, $borderThickness)
                $rightX = $trimmedWidth - 1
                $croppedGraphics.DrawLine($finalBorderPen, $rightX, 0, $rightX, $canvasHeight - 1)
                $finalBorderPen.Dispose()

                $croppedBitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $croppedGraphics.Dispose()
                $croppedBitmap.Dispose()
            }
        } else {
            $finalBorderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, $borderThickness)
            $rightX = $canvasWidth - 1
            $graphics.DrawLine($finalBorderPen, $rightX, 0, $rightX, $canvasHeight - 1)
            $finalBorderPen.Dispose()

            $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $font.Dispose()
    }
}