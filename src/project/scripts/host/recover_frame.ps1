param(
    [Parameter(Mandatory=$true)][string]$CaptureDir,
    [string]$OutPng,
    [int]$LineSamples = 1344,
    [int]$FrameLines = 806,
    [int]$ActiveWidth = 1024,
    [int]$ActiveHeight = 768
)

$ErrorActionPreference='Stop'
$CaptureDir=(Resolve-Path -LiteralPath $CaptureDir).Path
if([string]::IsNullOrWhiteSpace($OutPng)){$OutPng=Join-Path $CaptureDir 'recovered.png'}
$outDir=Split-Path -Parent $OutPng
if([string]::IsNullOrWhiteSpace($outDir)){$outDir=(Get-Location).Path}
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$total=$LineSamples*$FrameLines
$pixels=[byte[]]::new($total)
$seen=[bool[]]::new($total)
$files=@(Get-ChildItem -LiteralPath $CaptureDir -Filter 'segment_*.csv'|Sort-Object Name)
if($files.Count -eq 0){throw "No segment CSV files in $CaptureDir"}

foreach($file in $files){
    $sr=[IO.StreamReader]::new($file.FullName)
    try {
        $header=$sr.ReadLine().Split(',')
        [void]$sr.ReadLine() # Vivado radix metadata row
        $dataCol=-1;$addrCol=-1;$validCol=-1
        for($i=0;$i-lt$header.Length;$i++){
            $n=$header[$i].ToLowerInvariant()
            if($n.Contains('image_data')){$dataCol=$i}
            elseif($n.Contains('image_addr')){$addrCol=$i}
            elseif($n.Contains('image_valid')){$validCol=$i}
        }
        if($dataCol-lt0-or$addrCol-lt0-or$validCol-lt0){throw "Missing image data/address/valid columns in $($file.Name)"}
        while(($line=$sr.ReadLine()) -ne $null){
            $c=$line.Split(',')
            if($c.Count-le[math]::Max($validCol,[math]::Max($dataCol,$addrCol))){continue}
            if([Convert]::ToInt32($c[$validCol],16)-eq0){continue}
            $a=[Convert]::ToInt32($c[$addrCol],16)
            if($a-ge0-and$a-lt$total){
                if($seen[$a]){throw "Duplicate frame address $a in $($file.Name)"}
                $pixels[$a]=[Convert]::ToByte($c[$dataCol],16)
                $seen[$a]=$true
            }
        }
    } finally {$sr.Dispose()}
}

$missing=0;foreach($v in $seen){if(!$v){$missing++}}
if($missing-ne0){throw "Frame capture incomplete: $missing of $total addresses are missing"}

$rawMin=255;$rawMax=0;$nonzero=0
foreach($v in $pixels){
    if($v-lt$rawMin){$rawMin=$v}
    if($v-gt$rawMax){$rawMax=$v}
    if($v-ne0){$nonzero++}
}
if($rawMin-eq$rawMax){
    throw "Frame samples are constant ($rawMin): export succeeded, but no image information was captured"
}

# Robust 1st/99th-percentile contrast stretch.
$hist=[int[]]::new(256);foreach($v in $pixels){$hist[$v]++}
function Get-PercentileBin([double]$fraction){
    $target=[math]::Ceiling($total*$fraction);$sum=0
    for($i=0;$i-lt256;$i++){$sum+=$hist[$i];if($sum-ge$target){return $i}}
    return 255
}
$lo=Get-PercentileBin 0.01;$hi=Get-PercentileBin 0.99
if($hi-le$lo){$lo=0;$hi=255}
$norm=[byte[]]::new($total)
for($i=0;$i-lt$total;$i++){
    $v=[math]::Round(255.0*($pixels[$i]-$lo)/($hi-$lo))
    if($v-lt0){$v=0}elseif($v-gt255){$v=255}
    $norm[$i]=[byte]$v
}

# Find cyclic horizontal/vertical active windows from gradient energy.
$gx=[double[]]::new($LineSamples);$gy=[double[]]::new($FrameLines)
for($y=0;$y-lt$FrameLines;$y++){
    $row=$y*$LineSamples;$next=(($y+1)%$FrameLines)*$LineSamples
    for($x=0;$x-lt$LineSamples;$x++){
        $xn=($x+1)%$LineSamples
        $gx[$x]+=[math]::Abs([int]$norm[$row+$xn]-[int]$norm[$row+$x])
        $gy[$y]+=[math]::Abs([int]$norm[$next+$x]-[int]$norm[$row+$x])
    }
}
function Best-CyclicWindow([double[]]$v,[int]$width){
    $n=$v.Count;$sum=0.0
    for($i=0;$i-lt$width;$i++){$sum+=$v[$i%$n]}
    $best=$sum;$start=0
    for($s=1;$s-lt$n;$s++){
        $sum-=$v[($s-1)%$n];$sum+=$v[($s+$width-1)%$n]
        if($sum-gt$best){$best=$sum;$start=$s}
    }
    return $start
}
$x0=Best-CyclicWindow $gx $ActiveWidth
$y0=Best-CyclicWindow $gy $ActiveHeight

Add-Type -AssemblyName System.Drawing
function Save-Gray24([byte[]]$src,[int]$srcW,[int]$srcH,[int]$xStart,[int]$yStart,[int]$w,[int]$h,[string]$path){
    $bmp=[Drawing.Bitmap]::new($w,$h,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $rect=[Drawing.Rectangle]::new(0,0,$w,$h)
    $bd=$bmp.LockBits($rect,[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $buf=[byte[]]::new($bd.Stride*$h)
        for($y=0;$y-lt$h;$y++){
            $sy=($yStart+$y)%$srcH
            for($x=0;$x-lt$w;$x++){
                $sx=($xStart+$x)%$srcW;$v=$src[$sy*$srcW+$sx];$p=$y*$bd.Stride+3*$x
                $buf[$p]=$v;$buf[$p+1]=$v;$buf[$p+2]=$v
            }
        }
        [Runtime.InteropServices.Marshal]::Copy($buf,0,$bd.Scan0,$buf.Length)
    } finally {$bmp.UnlockBits($bd)}
    try {$bmp.Save($path,[Drawing.Imaging.ImageFormat]::Png)} finally {$bmp.Dispose()}
}

$rawPng=Join-Path $outDir 'raw_1344x806.png'
Save-Gray24 $norm $LineSamples $FrameLines 0 0 $LineSamples $FrameLines $rawPng
Save-Gray24 $norm $LineSamples $FrameLines $x0 $y0 $ActiveWidth $ActiveHeight $OutPng

Write-Host 'FRAME_CHECK_PASS'
Write-Host "Segments: $($files.Count)"
Write-Host "Pixels: $total"
Write-Host "Sample min/max: $rawMin / $rawMax; nonzero: $nonzero"
Write-Host "Raw range: $lo .. $hi (1st/99th percentile)"
Write-Host "Cyclic crop offset: x=$x0 y=$y0"
Write-Host "Raw image: $rawPng"
Write-Host "Recovered image: $OutPng"
