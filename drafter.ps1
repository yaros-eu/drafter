#!/usr/bin/env pwsh
param([string]$TargetPath, [Alias("r")][switch]$Recursive, [Alias("h")][switch]$Help)

Add-Type -AssemblyName System.Drawing

$EXECUTABLE_NAME = 'drafter'
$VERSION = "0.1 Beta"
$AUTHOR = 'Yaros'
$EXTENSIONS = @('.png', '.jpg', '.jpeg')
$OVERLAY_TEXT = 'DRAFT'
$OVERLAY_FONT = 'Arial'
$COLOR_A = 255
$COLOR_R = 255
$COLOR_G = 0
$COLOR_B = 0
$FONT_SIZE_STEP = 4
$OVERLAY_WIDTH_PERCENTAGE = 0.9
$HELP_DIR = 'C:\Images'
$HELP_IMG = 'logo.png'

if ($Help -or (-not $TargetPath)) {
    Write-Host "$EXECUTABLE_NAME  $VERSION  by $AUTHOR" -ForegroundColor Cyan
    Write-Host ""
    Write-Host @"
Usage: $EXECUTABLE_NAME [TargetPath] [options]

Applies a '$OVERLAY_TEXT' overlay to images ($($EXTENSIONS -join ', ')).

Options:
  -r, -recursive   Process images in all subfolders as well
  -h, -help        Show this help message and exit

Examples:
  $EXECUTABLE_NAME .`t`t`t`trun in current directory
  $EXECUTABLE_NAME $HELP_DIR `t`t`trun in specified directory
  $EXECUTABLE_NAME $HELP_DIR\$HELP_IMG `t`trun single file
  $EXECUTABLE_NAME $HELP_DIR -r `t`t`trun in specified directory and all subdirectories
  $EXECUTABLE_NAME $HELP_DIR --recursive `trun in specified directory and all subdirectories
"@
    Write-Host ""
    exit 0
}

$fullPath = Resolve-Path $TargetPath -ErrorAction SilentlyContinue
if (-not $fullPath) {
    Write-Error "Path not found: '$TargetPath'"
    exit 1
}

if (Test-Path $fullPath -PathType Leaf) {
    $images = if ($EXTENSIONS -contains ([System.IO.Path]::GetExtension($fullPath).ToLower())) {
        ,(Get-Item $fullPath)
    }
} elseif (Test-Path $fullPath -PathType Container) {
    $images = Get-ChildItem -Path $fullPath -File -Recurse:$Recursive | Where-Object {
        $EXTENSIONS -contains $_.Extension.ToLower()
    }
} else {
    Write-Error "Invalid path: '$TargetPath'"
    exit 1
}

if (-not $images) {
    Write-Host "No images found: '$fullPath'"
    exit 0
}

Write-Host "Processing $($images.Count) images"

foreach ($image in $images) {
    $imagePath = $image.FullName
    try {
        $bytes = [System.IO.File]::ReadAllBytes($imagePath)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $bmp = [System.Drawing.Image]::FromStream($ms)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.SmoothingMode  = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $fontSize = $FONT_SIZE_STEP
        $font = New-Object System.Drawing.Font($OVERLAY_FONT, $fontSize, [System.Drawing.FontStyle]::Bold)
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($COLOR_A, $COLOR_R, $COLOR_G, $COLOR_B))

        do {
            $textSize = $graphics.MeasureString($OVERLAY_TEXT, $font)
            if ($textSize.Width -lt ($bmp.Width * $OVERLAY_WIDTH_PERCENTAGE)) {
                $fontSize += $FONT_SIZE_STEP
                $font.Dispose()
                $font = New-Object System.Drawing.Font($OVERLAY_FONT, $fontSize, [System.Drawing.FontStyle]::Bold)
            } else {
                break
            }
        } while ($true)

        $x = ($bmp.Width - $textSize.Width) / 2
        $y = ($bmp.Height - $textSize.Height) / 2

        $graphics.DrawString($OVERLAY_TEXT, $font, $brush, $x, $y)

        $graphics.Dispose()
        $font.Dispose()
        $brush.Dispose()
        $ms.Close()
        $ms.Dispose()

        $bmp.Save($imagePath, $bmp.RawFormat)

        Write-Host "Processed: '$imagePath'" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed: '$imagePath'. Error: $_" -ForegroundColor Yellow
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($font) { $font.Dispose() }
        if ($brush) { $brush.Dispose() }
        if ($bmp) { $bmp.Dispose() }
        if ($ms) { $ms.Dispose() }
    }
}
