# Simulation and validation

RTL testbenches are in `src/project/sim/`: feature extraction, event detection, halfband decimation, leakage demodulation and spectrum replay. Their PowerShell launchers are in `src/project/scripts/`, named `run_*_sim.ps1`. Run from `src/project` with Vivado 2026.1 available.

The checked-in `src/project/output/reports/` directory contains real synthesis and implementation reports. MATLAB's `src/project/matlab/selftest_v24.m` performs a synthetic parser regression, which checks software behavior but is not evidence of RF image recovery. Real acquisition examples and limitations are in `data/README.md`.
