# Rebuild and implementation evidence

Toolchain: Vivado 2026.1, target `xczu27dr-ffve1156-2-i`. From `src/project`:

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/run.ps1 -Action check
powershell -ExecutionPolicy Bypass -File ./scripts/run.ps1 -Action create
powershell -ExecutionPolicy Bypass -File ./scripts/run.ps1 -Action build
powershell -ExecutionPolicy Bypass -File ./scripts/run.ps1 -Action verify
```

`scripts/create_project.tcl` constructs the block design and local IP. `build/vivado_full_v1/full_v24.srcs` holds the checked-in Vivado project sources; generated caches and DCPs are intentionally excluded. The released BIT/LTX, generated `psu_init.tcl`, utilization, timing and DRC reports are in `src/project`. The XPR can refer to the original build location, so use `create_project.tcl` when rebuilding on a different PC.

From the checked-in implemented report:

| Metric | Implemented | Available | Utilization |
| --- | ---: | ---: | ---: |
| CLB LUT | 23,205 | 425,280 | 5.46% |
| CLB registers | 26,611 | 850,560 | 3.13% |
| Block RAM tiles | 710 | 1,080 | 65.74% |
| URAM | 74 | 80 | 92.50% |
| DSP48E2 | 52 | 4,272 | 1.22% |

Implementation status: setup WNS 0.013 ns, hold WHS 0.010 ns, DRC errors 0. Source: `src/project/output/reports/build_status.txt`, `timing.rpt`, and `utilization.rpt`. `hardware_verified=false` in the build status applies to the released build record and must not be silently reclassified.
