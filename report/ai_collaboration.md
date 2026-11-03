# AI collaboration and correction record

This is a bounded record of verifiable work represented in this repository. It is not a complete transcript of all model prompts and responses.

| Task | Initial approach | Observation and correction | Evidence |
| --- | --- | --- | --- |
| One-command acquisition | A Tcl entry point programmed the BIT, initialized PS/PL clocks, exported one frame and launched MATLAB | Split into `init_once.tcl` and reusable `capture_current.tcl` so changing the external image does not require reprogramming | `src/project/formal_capture/` |
| 64 pixel bar interpretation | A periodic grayscale profile can visually resemble bars | The unchanged-screen capture measured a period peak of 159 and a negative split-half correlation; both values are preserved in the metrics | `data/capture_bars64/`, `data/bars64_capture_metrics.txt` |
| Output labeling | A generic filter renders a map for a static display | The figure and exported files identify the quantity as measured RF magnitude response | `src/project/formal_capture/analyze_current_image.m`, `data/capture_single/` |

The workflow used source inspection, real CSV re-analysis and implementation-report checks. Each measured example points to a capture directory and a reproducible analyzer command.
