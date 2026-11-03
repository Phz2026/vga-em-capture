# Board acquisition

The external VGA image remains unchanged during each acquisition. The scripts do not control the display. Probe position, LNA power, VGA timing and ADC connection should stay fixed between runs.

1. In Vivado Hardware Manager Tcl Console, source `../src/project/formal_capture/init_once.tcl` once after board power-up. This programs `full_v24.bit`, loads `full_v24.ltx`, runs XSDB PS/PL clock initialization, attaches JTAG AXI, checks design version `0x00020700`, and waits for `RFDC_TILE_READY`.
2. Full-screen an image on the VGA display at 1024 x 768 @ 60 Hz. Source `../src/project/formal_capture/capture_current.tcl` for each image. Wait for `FORMAL_CAPTURE_DONE` before changing the display. The same command may be reused; it creates a new timestamped folder under `D:/capture` and launches MATLAB.
3. For a known 64 pixel black/white bar pattern, `capture_bars64.tcl` provides a one-dimensional diagnostic; its measured image is `bars_measured_profile.png`. It does not validate blind pixel recovery.

Expected data: `D:/capture/formal_generic_*/frame_01/metadata.txt` and segment CSVs, plus `analysis_current/rf_response.png`, `metrics.txt` and `result.mat`. The full capture is 1344 samples x 900 lines. If JTAG reconnects, the capture script checks the design version and does not program the FPGA. If the board loses power, rerun initialization.

The one-command capture script has been checked by reading and offline MATLAB re-analysis. A fresh end-to-end board run is still required before claiming that exact entry point as hardware verified.
