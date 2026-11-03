# Design report: XCZU27DR VGA RF response capture

## 1. Background and contribution

This project studies RF emissions that vary with content shown on a VGA display. The practical goal is to acquire reproducible measurements and assess how much displayed-image structure survives the probe/LNA/ADC chain. The implemented contribution is an XCZU27DR FPGA acquisition chain with programmable digital downconversion, frame storage, JTAG export and host-side MATLAB analysis. The present evidence supports RF response visualization and selected known-pattern diagnostics. It does not establish arbitrary RGB image recovery.

## 2. Architecture and interfaces

`VGA display -> near-field probe -> powered LNA -> XCZU27DR RFDC ADC Tile 1 ADC01 -> FPGA digital processing -> frame memory -> JTAG AXI / ILA export -> MATLAB`.

The screen is 1024 x 768 @ 60 Hz. RFDC ADC sampling is configured at 1.04 GS/s with decimation by 8, yielding 130 MS/s complex samples. A PL halfband stage gives 65 MS/s image processing rate. A 200 MHz nominal PL clock controls the processing pipeline and JTAG-accessible registers. A 32-bit programmable DDC selects the current 195 MHz observation channel. The FPGA stores a 1344 x 900 magnitude frame for segmented export; `capture_frame.tcl` writes CSV segments and metadata. MATLAB assembles that measured stream, filters it with fixed parameters and displays one grayscale RF-response map. The PS clock setup is performed by XSDB; no Linux runtime is required.

Key source interfaces: `src/project/scripts/hardware/session.tcl` for JTAG register access and RFDC setup, `capture_frame.tcl` for frame export, and `formal_capture/` for one-time initialization and repeated single-screen acquisition. Each capture begins with a version and register readback check (`0x00020700`).

## 3. Reproduction

Use Vivado 2026.1 and the released BIT/LTX in `src/project/output/bitstream`. Rebuild instructions and caveats are in `build/README.md`. Keep a VGA test image full screen and static while running the commands in the root README. `init_once.tcl` programs and starts the hardware; each later `capture_current.tcl` call reuses the programmed board and starts MATLAB. The displayed image is changed by the operator between calls.

## 4. Verification and implementation

RTL simulation sources are in `src/project/sim` and are described in `sim/README.md`. Implementation reports show setup WNS 0.013 ns, hold WHS 0.010 ns and zero DRC errors. Resource use after implementation is 23,205 LUTs (5.46%), 26,611 registers (3.13%), 710 BRAM tiles (65.74%), 74 URAMs (92.50%) and 52 DSP48E2s (1.22%). These are values from the checked-in Vivado reports, not estimates.

An offline MATLAB rerun on a real unchanged-screen capture produced `data/single_capture_rf_response.png` and `data/single_capture_metrics.txt`. The measured channel is 195 MHz at 0.125x feature gain, with no saturated samples. The corresponding real 64 pixel bars capture yielded a dominant period of 159 instead of the expected 128 and split-half correlation -0.13096. Thus the unchanged-screen run does not verify the earlier clear bar result. This boundary matters more than the visual appearance of a processed plot.

Synthesis and implementation resource comparison from the same build:

| Resource | Synthesized | Implemented | Change |
| --- | ---: | ---: | ---: |
| CLB LUT | 23,316 | 23,205 | -111 |
| CLB registers | 26,117 | 26,611 | +494 |
| Block RAM tiles | 710 | 710 | 0 |
| URAM | 74 | 74 | 0 |
| DSP48E2 | 52 | 52 | 0 |

This table compares tool stages; it is not a before/after claim about a design optimization. No comparable predecessor build report is included, so an optimization improvement percentage is not claimed.

## 5. Remaining work and reproducibility limits

The acquisition chain currently lacks an independent HSYNC/VSYNC reference and RGB channel separation. Absolute line/pixel registration and color recovery remain open. A fresh board run of the newly packaged `init_once.tcl` and `capture_current.tcl` workflow is still needed; the release report's `hardware_verified=false` must be retained. Future experiments should preserve raw CSVs, probe position and display timing, and compare target runs with controls before claiming image restoration.

An editable technical document is included as `technical_document.docx`. No automated model collaboration record is claimed because no complete auditable prompt/response history is included in this release.
