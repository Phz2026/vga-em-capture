param(
    [Parameter(Mandatory=$true)][string]$CsvFile,
    [string]$OutSvg,
    [double]$SampleRateMHz = 65.0,
    [double]$RfCenterMHz = 200.0,
    [double]$IgnoreDcMHz = 0.10
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CsvFile)) { throw "CSV file not found: $CsvFile" }
if ([string]::IsNullOrWhiteSpace($OutSvg)) {
    $OutSvg = [IO.Path]::ChangeExtension((Resolve-Path -LiteralPath $CsvFile).Path, '.svg')
}

function Convert-IlaHex([object]$Value) {
    $s = ([string]$Value).Trim().Replace('_','')
    if ($s.StartsWith('0x',[StringComparison]::OrdinalIgnoreCase)) { $s=$s.Substring(2) }
    if ($s.EndsWith('h',[StringComparison]::OrdinalIgnoreCase)) { $s=$s.Substring(0,$s.Length-1) }
    if ($s -notmatch '^[0-9A-Fa-f]+$') { throw "Unsupported ILA value '$Value'" }
    return [Convert]::ToUInt64($s,16)
}

$rows = @(Import-Csv -LiteralPath $CsvFile)
if ($rows.Count -eq 0) { throw 'ILA CSV is empty.' }
$names = @($rows[0].PSObject.Properties.Name)
$dataName  = $names | Where-Object {
    $n=$_.ToLowerInvariant(); $n.Contains('replay_data') -or $n.Contains('probe0')
} | Select-Object -First 1
$addrName  = $names | Where-Object {
    $n=$_.ToLowerInvariant(); $n.Contains('replay_addr') -or $n.Contains('probe1')
} | Select-Object -First 1
$validName = $names | Where-Object {
    $n=$_.ToLowerInvariant(); $n.Contains('replay_valid') -or $n.Contains('probe2')
} | Select-Object -First 1
if (-not $dataName -or -not $addrName -or -not $validName) {
    throw "Expected replay_data/address/valid (or probe0/1/2). Columns: $($names -join ', ')"
}

$n = 65536
$data = [int[]]::new($n)
$seen = [bool[]]::new($n)
foreach ($row in $rows) {
    # Vivado writes a second metadata row such as "Radix - UNSIGNED,...,HEX".
    # It is not an ILA sample and must not be parsed as a hexadecimal value.
    if (([string]$row.$validName).Trim() -notmatch '^(?:0x)?[0-9A-Fa-f_]+h?$') { continue }
    if ((Convert-IlaHex $row.$validName) -eq 0) { continue }
    $a = [int](Convert-IlaHex $row.$addrName)
    if ($a -lt 0 -or $a -ge $n) { continue }
    if ($seen[$a]) { throw "Duplicate spectrum address: $a" }
    $data[$a] = [int](Convert-IlaHex $row.$dataName)
    $seen[$a] = $true
}
$missing = 0
for ($i=0; $i -lt $n; $i++) { if (-not $seen[$i]) { $missing++ } }
if ($missing -ne 0) { throw "Spectrum capture is incomplete: $missing of $n bins are missing." }

# Equivalent to MATLAB fftshift: centered index 0 represents -Fs/2.
$shifted = [int[]]::new($n)
$globalMax = [int]::MinValue
for ($i=0; $i -lt $n; $i++) {
    $v = $data[($i + $n/2) % $n]
    $shifted[$i] = $v
    if ($v -gt $globalMax) { $globalMax=$v }
}
$binMHz = $SampleRateMHz/$n
$strongestIndex = -1
$strongestValue = [int]::MinValue
for ($i=0; $i -lt $n; $i++) {
    $f = -$SampleRateMHz/2 + $i*$binMHz
    if ([Math]::Abs($f) -le $IgnoreDcMHz) { continue }
    if ($shifted[$i] -gt $strongestValue) {
        $strongestValue = $shifted[$i]
        $strongestIndex = $i
    }
}
$strongestBaseband = -$SampleRateMHz/2 + $strongestIndex*$binMHz
$strongestRf = $RfCenterMHz + $strongestBaseband
$strongestMirrorRf = $RfCenterMHz - $strongestBaseband
$peakIndex = -1
$peakScore = [long]::MinValue
$scoreRadius = 16
for ($i=0; $i -lt $n; $i++) {
    $f = -$SampleRateMHz/2 + $i*$binMHz
    if ([Math]::Abs($f) -le $IgnoreDcMHz) { continue }
    # Choose the peak by energy in a small neighbourhood, rather than by one
    # bin. Strong non-coherent tones can clip several bins at the same PL code;
    # a one-bin maximum may then select a weaker image on the opposite side.
    [long]$score=0
    for ($k=-$scoreRadius; $k -le $scoreRadius; $k++) {
        $j=$i+$k
        if ($j -ge 0 -and $j -lt $n) { $score += $shifted[$j] }
    }
    if ($score -gt $peakScore) { $peakScore=$score; $peakIndex=$i }
}
# Report the strongest actual bin inside the winning energy window.  The
# window centre itself is only used for robust image rejection and need not be
# the maximum-amplitude FFT bin.
$windowCenter=$peakIndex
$peakValue=[int]::MinValue
for ($k=-$scoreRadius; $k -le $scoreRadius; $k++) {
    $j=$windowCenter+$k
    if ($j -lt 0 -or $j -ge $n) { continue }
    if (($shifted[$j] -gt $peakValue) -or
        (($shifted[$j] -eq $peakValue) -and
         ([Math]::Abs($j-$windowCenter) -lt [Math]::Abs($peakIndex-$windowCenter)))) {
        $peakValue=$shifted[$j]
        $peakIndex=$j
    }
}
$peakBaseband = -$SampleRateMHz/2 + $peakIndex*$binMHz
$peakRf = $RfCenterMHz + $peakBaseband
$mirrorRf = $RfCenterMHz - $peakBaseband
$peakRelative = $peakValue-$globalMax

$width=1400; $height=800; $left=90; $right=30; $top=45; $bottom=75
$plotW=$width-$left-$right; $plotH=$height-$top-$bottom
$floor=-100.0
$sb=[Text.StringBuilder]::new()
[void]$sb.AppendLine("<svg xmlns='http://www.w3.org/2000/svg' width='$width' height='$height' viewBox='0 0 $width $height'>")
[void]$sb.AppendLine("<rect width='100%' height='100%' fill='white'/><rect x='$left' y='$top' width='$plotW' height='$plotH' fill='#080b0d'/>")
for($t=-30;$t -le 30;$t+=5){
    $x=$left+($t+$SampleRateMHz/2)/$SampleRateMHz*$plotW
    [void]$sb.AppendLine("<line x1='$x' y1='$top' x2='$x' y2='$($top+$plotH)' stroke='#283238'/><text x='$x' y='$($top+$plotH+24)' text-anchor='middle' font-family='Arial' font-size='15'>$t</text>")
}
for($t=0;$t -ge -100;$t-=10){
    $y=$top+(0-$t)/(0-$floor)*$plotH
    [void]$sb.AppendLine("<line x1='$left' y1='$y' x2='$($left+$plotW)' y2='$y' stroke='#283238'/><text x='$($left-12)' y='$($y+5)' text-anchor='end' font-family='Arial' font-size='15'>$t</text>")
}
$points=[Text.StringBuilder]::new()
for($px=0;$px -lt $plotW;$px++){
    $start=[int][Math]::Floor($px*$n/$plotW)
    $end=[int][Math]::Floor(($px+1)*$n/$plotW)-1
    if($end -lt $start){$end=$start}
    $v=[int]::MinValue
    for($j=$start;$j -le $end;$j++){if($shifted[$j] -gt $v){$v=$shifted[$j]}}
    $rel=[Math]::Max($floor,[double]($v-$globalMax))
    $x=$left+$px; $y=$top+(0-$rel)/(0-$floor)*$plotH
    [void]$points.AppendFormat([Globalization.CultureInfo]::InvariantCulture,'{0:F1},{1:F1} ',$x,$y)
}
[void]$sb.AppendLine("<polyline fill='none' stroke='#45d7ff' stroke-width='1.3' points='$points'/>")
$peakX=$left+($peakBaseband+$SampleRateMHz/2)/$SampleRateMHz*$plotW
$peakY=$top+(0-[Math]::Max($floor,[double]$peakRelative))/(0-$floor)*$plotH
[void]$sb.AppendLine("<circle cx='$peakX' cy='$peakY' r='5' fill='#ff4b4b'/>")
[void]$sb.AppendLine("<text x='$($width/2)' y='27' text-anchor='middle' font-family='Arial' font-size='20'>PL spectrum: Fs=$SampleRateMHz MHz, center=$RfCenterMHz MHz</text>")
[void]$sb.AppendLine("<text x='$($width/2)' y='$($height-20)' text-anchor='middle' font-family='Arial' font-size='18'>Baseband frequency (MHz)</text>")
[void]$sb.AppendLine("<text transform='translate(24,$($height/2)) rotate(-90)' text-anchor='middle' font-family='Arial' font-size='18'>Relative PL level (dB-like)</text>")
[void]$sb.AppendLine("<text x='$($left+12)' y='$($top+25)' fill='white' font-family='Arial' font-size='16'>Peak outside DC: $($peakBaseband.ToString('F6')) MHz; estimated RF: $($peakRf.ToString('F6')) MHz</text>")
[void]$sb.AppendLine('</svg>')
[IO.File]::WriteAllText($OutSvg,$sb.ToString(),[Text.UTF8Encoding]::new($false))

Write-Host 'SPECTRUM_CHECK_PASS'
Write-Host "Bins: $n"
Write-Host ("Resolution: {0:F6} kHz" -f ($binMHz*1000))
Write-Host ("Strongest bin baseband: {0:F6} MHz" -f $strongestBaseband)
Write-Host ("Strongest bin RF candidate: {0:F6} MHz" -f $strongestRf)
Write-Host ("Strongest bin opposite-side candidate: {0:F6} MHz" -f $strongestMirrorRf)
Write-Host "Strongest bin PL code: $strongestValue"
Write-Host ("Peak baseband: {0:F6} MHz" -f $peakBaseband)
Write-Host ("Estimated RF: {0:F6} MHz" -f $peakRf)
Write-Host ("Opposite-side image candidate: {0:F6} MHz" -f $mirrorRf)
Write-Host "Peak PL code: $peakValue"
Write-Host "Peak relative to global maximum: $peakRelative dB-like"
Write-Host "Plot: $OutSvg"
