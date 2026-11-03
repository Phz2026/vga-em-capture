param(
  [Parameter(Mandatory=$true)][string]$ReferenceCsv,
  [Parameter(Mandatory=$true)][string]$TestCsv,
  [double]$SampleRateMHz=65.0,
  [double]$CarrierBasebandMHz=-5.0,
  [double]$PixelPatternMHz=2.03125
)
$ErrorActionPreference='Stop'
function Hex([string]$s){[Convert]::ToInt32($s.Trim(),16)}
function Load-Spectrum([string]$p){
  $a=[int[]]::new(65536)
  $rows=Import-Csv -LiteralPath $p
  $names=@($rows[0].PSObject.Properties.Name)
  $dn=$names|Where-Object{$_.ToLower().Contains('replay_data')}|Select-Object -First 1
  $an=$names|Where-Object{$_.ToLower().Contains('replay_addr')}|Select-Object -First 1
  $vn=$names|Where-Object{$_.ToLower().Contains('replay_valid')}|Select-Object -First 1
  foreach($r in $rows){
    if(([string]$r.$vn)-notmatch '^[0-9A-Fa-f]+$'){continue}
    if((Hex $r.$vn)-eq0){continue}
    $a[(Hex $r.$an)]=Hex $r.$dn
  }
  return ,$a
}
function Value-At([int[]]$a,[double]$f,[int]$radius=20){
  $n=$a.Count;$si=[int][Math]::Round(($f+$SampleRateMHz/2)/$SampleRateMHz*$n)
  $best=-1;$bestF=0.0
  for($d=-$radius;$d-le$radius;$d++){
    $s=($si+$d+$n)%$n;$raw=($s+$n/2)%$n;$v=$a[$raw]
    if($v-gt$best){$best=$v;$bestF=-$SampleRateMHz/2+$s*$SampleRateMHz/$n}
  }
  [pscustomobject]@{TargetMHz=$f;PeakMHz=$bestF;Code=$best}
}
$ref=Load-Spectrum $ReferenceCsv;$test=Load-Spectrum $TestCsv
$targets=@($CarrierBasebandMHz, ($CarrierBasebandMHz - $PixelPatternMHz), ($CarrierBasebandMHz + $PixelPatternMHz))
'SPECTRUM_COMPARISON'
foreach($f in $targets){
  $r=Value-At $ref $f;$t=Value-At $test $f
  [pscustomobject]@{TargetMHz=$f;ReferencePeakMHz=$r.PeakMHz;ReferenceCode=$r.Code;TestPeakMHz=$t.PeakMHz;TestCode=$t.Code;TestMinusReference=($t.Code - $r.Code)}
}
