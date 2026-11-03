param([string]$VivadoRoot='D:\AMDDesignTools\2026.1\Vivado')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$loader=Join-Path $VivadoRoot 'bin\loader.bat'
$xsdb=Join-Path $VivadoRoot 'bin\xsdb.bat'
$bit=Join-Path $root 'output\bitstream\full_v24.bit'
$ltx=Join-Path $root 'output\bitstream\full_v24.ltx'
$hashFile=Join-Path $root 'output\bitstream\sha256.txt'
foreach($p in @($loader,$xsdb,$bit,$ltx,$hashFile)){if(-not(Test-Path -LiteralPath $p)){throw "Missing $p"}}
$expected=Get-Content -LiteralPath $hashFile -Raw | ConvertFrom-StringData
if((Get-FileHash -Algorithm SHA256 -LiteralPath $bit).Hash -ne $expected.BIT){throw 'BIT hash mismatch'}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $ltx).Hash -ne $expected.LTX){throw 'LTX hash mismatch'}

$env:XILINX_LOCAL_USER_DATA='no'
$env:RDI_PROG='vivado'
$env:XILINX_VIVADO=$VivadoRoot
$env:XILINX_TCLSTORE_USERAREA=Join-Path $root 'build\tclstore'
Push-Location $root
try {
  & $loader -exec vivado -mode batch -source '.\scripts\hardware\program_v24.tcl' -log '.\output\logs\hardware_program.log' -journal '.\output\logs\hardware_program.jou'
  if($LASTEXITCODE -ne 0){throw 'V2.4 FPGA programming failed'}
  & $xsdb '.\scripts\hardware\init_ps_for_jtag.tcl'
  if($LASTEXITCODE -ne 0){throw 'PS/PL clock initialization failed'}
  & $loader -exec vivado -mode batch -source '.\scripts\hardware\smoke_v24.tcl' -log '.\output\logs\hardware_smoke.log' -journal '.\output\logs\hardware_smoke.jou'
  if($LASTEXITCODE -ne 0){throw 'V2.4 hardware smoke test failed'}
  'V24_FULL_HARDWARE_SMOKE_PASS'
} finally {Pop-Location}
