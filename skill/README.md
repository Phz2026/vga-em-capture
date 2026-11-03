# Reusable skill: evidence-first FPGA release audit

## Applicable scope

Use this checklist for a Vivado FPGA project that submits a released BIT/LTX, implementation reports, a board capture script and host analysis. It checks whether files exist, whether implementation metrics are explicitly reported, and whether claims are supported by the available measurements. It does not replace board testing.

## Procedure

1. Run `check_release.ps1 -ProjectRoot ../src/project`. It checks BIT/LTX, PS init, capture entry points, build status, utilization and timing reports, and prints the reported implementation state.
2. Run the supplied simulation launchers for RTL behavior and MATLAB `selftest_v24` for parser behavior. Keep these results separate from real acquisition evidence.
3. For each board run, record display timing, frequency/gain, capture folder, source image, probe placement, and whether a black control was measured. Preserve raw CSVs and `metadata.txt` before comparing outputs.
4. Compare the target pattern with a black control or repeated run when claiming visual recovery. If no control exists, label a periodic profile as a diagnostic. If the expected period or split-half agreement fails, report it as inconclusive.
5. Report the limits of the measurement chain. A one-channel RF magnitude map with no HSYNC/VSYNC reference does not establish absolute pixel coordinates or RGB color.

## Origin and observed failure

This workflow came from XCZU27DR/VGA measurements. One unchanged-screen 64 pixel bar capture produced a peak period of 159 instead of 128 and split-half correlation -0.13096, despite a bar-like display being possible after filtering. The check prevents a visually plausible graph from being reported as a verified pixel reconstruction. The release check was compared against the included Vivado build reports; the new board entry point still needs a fresh hardware run.
