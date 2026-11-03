param([string]$ProjectRoot = (Join-Path $PSScriptRoot '..\src\project'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$required = @(
    'output/bitstream/full_v24.bit',
    'output/bitstream/full_v24.ltx',
    'build/vivado_full_v1/full_v24.gen/sources_1/bd/vga_em_bd/ip/vga_em_bd_ps_0/psu_init.tcl',
    'formal_capture/init_once.tcl',
    'formal_capture/capture_current.tcl',
    'formal_capture/analyze_current_image.m',
    'output/reports/build_status.txt',
    'output/reports/utilization.rpt',
    'output/reports/timing.rpt'
)
foreach ($rel in $required) {
    $path = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "MISSING: $rel" }
}
$status = Get-Content -LiteralPath (Join-Path $root 'output/reports/build_status.txt') -Raw
foreach ($entry in @('bitstream_built=true', 'timing_met=true', 'drc_errors=0')) {
    if (-not $status.Contains($entry)) { throw "BUILD_STATUS_MISMATCH: $entry" }
}
Write-Output 'RELEASE_FILES_PASS'
Get-Content -LiteralPath (Join-Path $root 'output/reports/build_status.txt')
Write-Output 'NOTE: build report status does not verify the new top-level capture entry point on hardware.'
