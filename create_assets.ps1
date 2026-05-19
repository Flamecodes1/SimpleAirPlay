# Create placeholder Store assets for MSIX
Add-Type -AssemblyName System.Drawing

$assetsDir = "c:\Users\fritz\airplay\UxPlay\SimpleAirPlayApp\Assets"
New-Item -ItemType Directory -Force $assetsDir | Out-Null

$sizes = @{
    "StoreLogo.png" = @(50, 50)
    "Square150x150Logo.png" = @(150, 150)
    "Square44x44Logo.png" = @(44, 44)
    "Wide310x150Logo.png" = @(310, 150)
    "SmallTile.png" = @(71, 71)
    "LargeTile.png" = @(310, 310)
    "SplashScreen.png" = @(620, 300)
}

foreach ($name in $sizes.Keys) {
    $path = Join-Path $assetsDir $name
    $s = $sizes[$name]
    $bmp = New-Object System.Drawing.Bitmap($s[0], $s[1])
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30))

    # Draw simple AirPlay icon placeholder
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 212, 255))
    $font = New-Object System.Drawing.Font("Segoe UI", [Math]::Max(8, $s[1] / 6), [System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF(0, 0, $s[0], $s[1])
    $g.DrawString("SA", $font, $brush, $rect, $sf)

    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created $name ($($s[0])x$($s[1]))"
}
Write-Host "Done!"
