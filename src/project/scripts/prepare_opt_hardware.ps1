param(
  [string]$VivadoRoot = 'D:\AMDDesignTools\2026.1\Vivado'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Xsdb = Join-Path $VivadoRoot 'bin\xsdb.bat'
$InitScript = Join-Path $PSScriptRoot 'hardware\init_ps_for_jtag.tcl'
$Bit = Join-Path $ProjectRoot 'output\bitstream\full_v24.bit'
$Ltx = Join-Path $ProjectRoot 'output\bitstream\full_v24.ltx'

foreach ($Path in @($Xsdb, $InitScript, $Bit, $Ltx)) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Required file not found: $Path"
  }
}

Write-Host 'The optimized BIT must already be programmed.'
Write-Host 'Vivado Hardware Manager must be disconnected from hw_server.'
Write-Host 'Initializing PS PLLs, PL0 clock, PL power and PS-to-PL reset...'

$XsdbOutput = & $Xsdb $InitScript 2>&1
$XsdbOutput | ForEach-Object { Write-Host $_ }
$XsdbText = $XsdbOutput -join "`n"
if ($LASTEXITCODE -ne 0 -or
    $XsdbText -notmatch '(?m)^PS_INIT_FOR_JTAG_PASS\s*$' -or
    $XsdbText -notmatch 'IOPLL_LOCK=1 PL0_CLOCK_ACTIVE=1') {
  throw "PS/PL initialization did not confirm a locked PLL and active PL0 clock (XSDB exit code $LASTEXITCODE). Close Hardware Manager target/server and run this script again."
}

Write-Host ''
Write-Host 'OPT_HARDWARE_CLOCK_READY'
Write-Host 'Return to Vivado Hardware Manager, Open Target -> Auto Connect.'
Write-Host 'Do not program the FPGA again. Run these Tcl commands:'
Write-Host "source $($PSScriptRoot.Replace('\','/'))/hardware/session.tcl"
Write-Host 'vga_attach'
Write-Host 'vga_check'
Write-Host 'vga_rfdc_start'
