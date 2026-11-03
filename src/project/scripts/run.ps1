param([ValidateSet('check','create','build','implement','verify')][string]$Action='create',
 [string]$VivadoRoot='D:\AMDDesignTools\2026.1\Vivado')
$ErrorActionPreference='Stop'
$ProjectRoot=Split-Path -Parent $PSScriptRoot
$TaskScript=@{check='check_rtl.tcl';create='create_project.tcl';build='build_bitstream.tcl';implement='implement_inprocess.tcl';verify='post_build_verify.tcl'}[$Action]
New-Item -ItemType Directory -Force (Join-Path $ProjectRoot 'output/logs') | Out-Null
$env:XILINX_TCLSTORE_USERAREA=Join-Path $ProjectRoot 'build/tclstore'
$env:XILINX_LOCAL_USER_DATA='no'
$env:RDI_PROG='vivado'
$env:XILINX_VIVADO=$VivadoRoot
Push-Location $ProjectRoot
try {
  # The block design consumes packaged copies under build/local_ip.  Recreate the
  # project before every release build so RTL edits cannot silently leave stale
  # packaged IP in the generated bitstream.
  if($Action -eq 'build') {
    & (Join-Path $VivadoRoot 'bin/loader.bat') -exec vivado -mode batch -source (Join-Path $PSScriptRoot 'create_project.tcl') -log 'output/logs/build_prepare.log' -journal 'output/logs/build_prepare.jou'
    if($LASTEXITCODE -ne 0){throw "Vivado build preparation failed: $LASTEXITCODE. See output/logs/build_prepare.log"}
  }
  & (Join-Path $VivadoRoot 'bin/loader.bat') -exec vivado -mode batch -source (Join-Path $PSScriptRoot $TaskScript) -log "output/logs/$Action.log" -journal "output/logs/$Action.jou"
  if($LASTEXITCODE -ne 0){throw "Vivado $Action failed: $LASTEXITCODE. See output/logs/$Action.log"}
  if($Action -in @('build','implement')) {
    $bit=Join-Path $ProjectRoot 'output/bitstream/full_v24.bit'
    $ltx=Join-Path $ProjectRoot 'output/bitstream/full_v24.ltx'
    if(-not (Test-Path -LiteralPath $bit) -or -not (Test-Path -LiteralPath $ltx)) {throw 'Build did not produce BIT and LTX'}
    @("BIT=$((Get-FileHash -Algorithm SHA256 -LiteralPath $bit).Hash)",
      "LTX=$((Get-FileHash -Algorithm SHA256 -LiteralPath $ltx).Hash)") |
      Set-Content -LiteralPath (Join-Path $ProjectRoot 'output/bitstream/sha256.txt') -Encoding ascii
  }
} finally {Pop-Location}
