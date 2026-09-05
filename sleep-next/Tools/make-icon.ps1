Add-Type -AssemblyName System.Drawing
$assetDir = Join-Path $PSScriptRoot '../Resources/Assets.xcassets/AppIcon.appiconset'
New-Item -ItemType Directory -Force $assetDir | Out-Null
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = 'AntiAlias'
$graphics.Clear([System.Drawing.Color]::FromArgb(25,45,54))
$sun = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(234,179,118))
$graphics.FillEllipse($sun,322,246,380,380)
$water = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(25,45,54))
$graphics.FillRectangle($water,190,510,644,270)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(234,179,118)),22
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'
$graphics.DrawLine($pen,300,540,724,540)
$graphics.DrawLine($pen,370,610,654,610)
$graphics.DrawLine($pen,437,680,587,680)
$bitmap.Save((Join-Path $assetDir 'icon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $bitmap.Dispose(); $sun.Dispose(); $water.Dispose(); $pen.Dispose()
'{"images":[{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}' | Set-Content (Join-Path $assetDir 'Contents.json')
