# VGA electromagnetic response capture on XCZU27DR

An FPGA and MATLAB research prototype that captures a 195 MHz RF magnitude response while a VGA display holds a 1024 x 768 @ 60 Hz image. The operator changes the displayed image manually. One Vivado Tcl command programs the released bitstream and initializes clocks; later captures reuse the programmed FPGA and open a measured grayscale response in MATLAB.

The current output is **not a decoded VGA RGB image**. Pixel accurate recovery of arbitrary color images has not been demonstrated. See [the measured results](data/README.md) and [design report](report/design_report.md).

## Repository map

| Directory | Contents |
| --- | --- |
| `src/project/` | Complete relocatable source layout, Vivado project sources, RTL, constraints, MATLAB code, BIT/LTX and PS clock initialization |
| `sim/` | Simulation entry points and validation evidence |
| `build/` | Rebuild instructions and implementation metrics |
| `board/` | On-board run sequence and acquisition entry points |
| `data/` | One real offline re-analysis, 64 pixel bars diagnostic and input pattern |
| `skill/` | Reusable release checks, failure lessons and scope |
| `report/` | Design report and editable technical document |

## Quick start on the acquisition PC

Requirements: XCZU27DR board, Vivado 2026.1 with XSDB, MATLAB R2025b, JTAG, the validated probe/LNA/ADC connection, and a VGA image source at 1024 x 768 @ 60 Hz. Default tool locations are specified in `src/project/formal_capture/*.tcl`; override with `VGA_XSDB_EXE`, `VGA_MATLAB_EXE` and `VGA_CAPTURE_ROOT` before starting Vivado.

In Vivado Hardware Manager Tcl Console, after opening the project, run once after board power-up:

```tcl
source {<repo>/src/project/formal_capture/init_once.tcl}
```

Wait for `FORMAL_READY_REUSE_BIT_AND_CLOCKS`. Keep the desired image full screen and unchanged, then run once per image:

```tcl
source {<repo>/src/project/formal_capture/capture_current.tcl}
```

Wait for `FORMAL_CAPTURE_DONE`. Repeat the **same** capture command after manually changing the image. It does not reprogram the FPGA or switch the display. The MATLAB figure shows one measured RF response. For a known 64 pixel bars diagnostic, use `capture_bars64.tcl`; its 128 sample period is supplied as prior knowledge and is not blind recovery.

Hardware testing of these new top-level entry points remains outstanding. Their MATLAB analyzers were rerun against existing real CSV captures; see `data/`. For full wiring, run details and limitations, see [board/README.md](board/README.md).

## Build

From `src/project`, run `powershell -ExecutionPolicy Bypass -File ./scripts/run.ps1 -Action create`, then `-Action build` and `-Action verify`. The checked-in XPR may contain build-machine absolute paths; the create script is the portable starting point. See [build/README.md](build/README.md).

No license has been selected yet. Do not assume permission to reuse third-party vendor IP beyond its own terms.
