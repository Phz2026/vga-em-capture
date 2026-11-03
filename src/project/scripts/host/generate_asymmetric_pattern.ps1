$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'test_patterns\asymmetric_blind_1024x768.png'
$bmp=[Drawing.Bitmap]::new(1024,768,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g=[Drawing.Graphics]::FromImage($bmp)
try {
  $g.Clear([Drawing.Color]::Black)
  $white=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,255,255))
  $gray=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(176,176,176))
  $dark=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(88,88,88))
  try {
    $g.FillRectangle($white,70,60,300,190)
    $g.FillRectangle($gray,735,95,185,555)
    $g.FillRectangle($white,95,425,105,270)
    $g.FillRectangle($white,95,590,430,105)
    $g.FillRectangle($dark,470,285,150,125)
    $g.FillRectangle($gray,555,505,105,85)
    $g.FillRectangle($white,625,185,55,190)
  } finally {
    $white.Dispose();$gray.Dispose();$dark.Dispose()
  }
  $bmp.Save($out,[Drawing.Imaging.ImageFormat]::Png)
} finally {
  $g.Dispose();$bmp.Dispose()
}
$check=[Drawing.Bitmap]::FromFile($out)
try {
  if($check.Width-ne1024-or$check.Height-ne768){throw "Unexpected output size $($check.Width)x$($check.Height)"}
} finally {$check.Dispose()}
Write-Host "PATTERN_CREATED=$out"
Write-Host 'SIZE=1024x768'
Write-Host "SHA256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $out).Hash)"
