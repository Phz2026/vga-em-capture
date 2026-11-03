param([string]$VivadoRoot='D:\AMDDesignTools\2026.1\Vivado')
$ErrorActionPreference='Stop'
$ProjectRoot=Split-Path -Parent $PSScriptRoot
$env:XILINX_TCLSTORE_USERAREA=Join-Path $ProjectRoot 'build/tclstore'
$env:XILINX_LOCAL_USER_DATA='no'
$env:XILINX_VIVADO=$VivadoRoot
$loader=Join-Path $VivadoRoot 'bin/loader.bat'
$simDir=Join-Path $ProjectRoot 'build/feature_sim'
New-Item -ItemType Directory -Force $simDir|Out-Null
Push-Location $simDir
try {
  & $loader -exec xvlog --sv (Join-Path $ProjectRoot 'rtl/feature_extract.sv') (Join-Path $ProjectRoot 'sim/tb_feature_extract.sv')
  if($LASTEXITCODE-ne0){throw "xvlog failed: $LASTEXITCODE"}
  & $loader -exec xelab tb_feature_extract -s feature_extract_sim
  if($LASTEXITCODE-ne0){throw "xelab failed: $LASTEXITCODE"}
  & $loader -exec xsim feature_extract_sim -runall
  if($LASTEXITCODE-ne0){throw "xsim failed: $LASTEXITCODE"}
} finally {Pop-Location}
