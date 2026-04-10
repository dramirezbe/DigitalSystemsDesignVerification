# DigitalSystemsDesignVerification

## Repository Summary

This repository contains small digital design verification projects in Verilog.
Each project follows a consistent structure to keep design files, testbenches,
and generated artifacts clearly separated.

### Projects

- `4bitmult`: Sequential 4x4 multiplier design and testbench.
- `door-window`: Alarm logic and sensor threshold logic with separate testbenches.
- `mcd-euclidean`: Project scaffold ready for source and testbench files.

### Standard Project Layout

Each project directory should use:

- `src/`: design source files (`.v`)
- `tb/`: testbench files (`.v`)
- `build/`: generated simulation binaries (`.vvp`) and waveforms (`.vcd`)

## Build and Simulation

Use the root script:

- `./builder.sh -r <project-folder>` (compile only)
- `./builder.sh -r <project-folder> -x` (compile and run testbenches)
- `./builder.sh -r <project-folder> -x -w` (compile, run, and open GTKWave)

Examples:

- `./builder.sh -r 4bitmult`
- `./builder.sh -r door-window`

What the script does:

1. Compiles each testbench in `tb/` against all sources in `src/` using `iverilog`.
2. Optionally runs simulation with `vvp` when `-x` is provided.
3. Stores outputs in `build/`.
4. Optionally opens generated waveforms in GTKWave when `-w` is provided together with `-x`.

## Requirements

- `iverilog`
- `vvp`
- `gtkwave` (optional, only when using `-w`)