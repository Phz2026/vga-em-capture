param([string]$VivadoRoot='D:\AMDDesignTools\2026.1\Vivado')
$ErrorActionPreference='Stop'
$ProjectRoot=Split-Path -Parent $PSScriptRoot
$env:XILINX_LOCAL_USER_DATA='no'
$env:XILINX_VIVADO=$VivadoRoot
$loader=Join-Path $VivadoRoot 'bin/loader.bat'
$simDir=Join-Path $ProjectRoot 'build/event_sim'
New-Item -ItemType Directory -Force $simDir | Out-Null
Push-Location $simDir
try {
  & $loader -exec xvlog --sv (Join-Path $ProjectRoot 'rtl/frame_event_detector.sv') (Join-Path $ProjectRoot 'sim/tb_frame_event_detector.sv')
  if($LASTEXITCODE -ne 0){throw "xvlog failed: $LASTEXITCODE"}
  & $loader -exec xelab tb_frame_event_detector -s frame_event_detector_sim -mt off
  if($LASTEXITCODE -ne 0){throw "xelab failed: $LASTEXITCODE"}
  & $loader -exec xsim frame_event_detector_sim -runall
  if($LASTEXITCODE -ne 0){throw "xsim failed: $LASTEXITCODE"}
} finally {Pop-Location}
