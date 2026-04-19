# DigitalSystemsDesignVerification

## Repository Organization

This repository is organized into three main areas:

- `PROJECT/`: main FPGA project workspace, including docs, research, RTL, simulation, and board integration.
- `TASKS/`: implementation and simulation tasks (source, testbench, build artifacts, and reports).
- `VERIFICATION/`: modular verification exercises and supporting material.

To preserve older links and workflows, the repository root also keeps compatibility folders such as `4bitmult/`, `16bitsqrt/`, `door-window/`, and `gcd-euclidean/`. These folders act as lightweight bridge READMEs that point to the canonical content under `TASKS/`.

Current top-level layout:

```text
.
|-- README.md
|-- PROJECT/
|   |-- README.md
|   |-- docs/
|   |-- research/
|   `-- sim/
|-- 4bitmult/
|-- 16bitsqrt/
|-- door-window/
|-- gcd-euclidean/
|-- TASKS/
|   |-- builder-tasks.sh
|   |-- 16bitsqrt/
|   |   |-- src/
|   |   |-- tb/
|   |   |-- build/
|   |   `-- report/
|   |-- 4bitmult/
|   |   |-- src/
|   |   |-- tb/
|   |   `-- build/
|   |-- door-window/
|   |   |-- src/
|   |   |-- tb/
|   |   |-- build/
|   |   `-- report/
|   `-- gcd-euclidean/
|       |-- src/
|       |-- tb/
|       `-- build/
`-- VERIFICATION/
	|-- EXPLAIN.md
	`-- gcd-modular/
		|-- src/
		`-- tb/
```

## Compatibility Folders

The root-level task folders are kept for compatibility with older paths and documentation:

- `4bitmult/`
- `16bitsqrt/`
- `door-window/`
- `gcd-euclidean/`

Each one contains a short README that redirects to the corresponding task under `TASKS/`.

## TASKS Project Layout

Each task under `TASKS/` follows this structure:

- `src/`: Verilog design sources (`.v`).
- `tb/`: testbench files (`.v`).
- `build/`: generated simulation binaries (`.vvp`) and waveforms (`.vcd`).
- `report/` (optional): report sources (for example `.tex`).

## Build and Simulation

The task automation script is `TASKS/builder-tasks.sh`.

From repository root:

- `./TASKS/builder-tasks.sh -r <task-folder>`: compile testbenches.
- `./TASKS/builder-tasks.sh -r <task-folder> -x`: compile and run simulations.
- `./TASKS/builder-tasks.sh -r <task-folder> -x -w`: compile, run, and open GTKWave.

Examples:

- `./TASKS/builder-tasks.sh -r 4bitmult -x`
- `./TASKS/builder-tasks.sh -r door-window -x -w`

## Requirements

- `iverilog`
- `vvp`
- `gtkwave` (optional, only when using `-w`)