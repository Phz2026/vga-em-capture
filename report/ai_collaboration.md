# AI collaboration and correction record

This is a bounded record of verifiable work represented in this repository. It is not a complete transcript of all model prompts and responses.

| Task | Initial approach | Observation and correction | Evidence |
| --- | --- | --- | --- |
| One-command acquisition | A Tcl entry point programmed the BIT, initialized PS/PL clocks, exported one frame and launched MATLAB | Split into `init_once.tcl` and reusable `capture_current.tcl` so changing the external image does not require reprogramming | `src/project/formal_capture/` |
| 64 pixel bar interpretation | A periodic grayscale profile can visually resemble bars | A real unchanged-screen capture peaked at period 159, not the known 128, with negative split-half correlation. The report labels this run inconclusive | `data/capture_bars64/`, `data/bars64_capture_metrics.txt` |
| Arbitrary image claims | A generic filter can render an RF response for any static display | The measured output is labeled RF magnitude response because there is no independent HSYNC/VSYNC reference or RGB decoding | `src/project/formal_capture/analyze_current_image.m`, `data/capture_single/` |

The workflow used source inspection, real CSV re-analysis and implementation-report checks. There is no evidence here for a general color-image reconstruction algorithm or a fresh board validation of the new top-level scripts. Future public claims should point to a capture directory and a reproducible analyzer command.
