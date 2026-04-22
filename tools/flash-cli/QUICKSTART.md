# QUICKSTART

This guide explains how to use `flash-CLI.py` to build and flash a Gowin FPGA project.

## What `flash-CLI.py` Does

`flash-CLI.py` automates the standard open-source Gowin flow:

1. `yosys` for synthesis
2. `nextpnr-gowin` for place and route
3. `gowin_pack` for bitstream generation
4. `openFPGALoader` for flashing

## Required Project Structure

Each FPGA project must follow this layout:

```text
project-folder/
├── core/
│   └── *.cst
└── src/
    └── *.v
```

Example:

```text
my-fpga-project/
├── core/
│   └── board.cst
└── src/
    └── top.v
```

## Basic Usage

Run:

```bash
python3 flash-CLI.py -r <project-folder>
```

If you do not pass `-m`, the script uses `all`.

## Flags

### `-r`

Project root folder.

Example:

```bash
python3 flash-CLI.py -r my-fpga-project
```

### `-m`

Execution mode.

Available values:

- `synth`: run synthesis only
- `pnr`: run synthesis, generate merged constraints, and run place-and-route
- `bitstream`: run synthesis, constraints merge, place-and-route, and bitstream packing
- `flash`: run the full flow and flash the board
- `clean`: delete the build directory
- `all`: same as `flash`

### `-b`

Custom build directory name or path.

Default:

```text
build
```

Example:

```bash
python3 flash-CLI.py -r my-fpga-project -m synth -b out
```

### `-v`, `--verbose`

Enable verbose tool output.

Without `-v`, the script shows a cleaner build-style output.
With `-v`, it streams the full backend tool logs.

## Output Modes

### Default Output

Without `-v`, `flash-CLI.py` behaves like a compact build tool:

- phase headers are printed in color
- successful phase completion is reported briefly
- synthesis, place-and-route, and bitstream tool logs stay hidden
- flashing still shows the real `openFPGALoader` output live

Typical flow:

```text
Mode: all
==> Synthesis
Synthesis completed
==> Generating Constraints Bundle
Constraints ready
==> Place And Route
Place and route completed
==> Bitstream Packing
Bitstream generated
==> Flashing
... openFPGALoader live output ...
Flash completed
```

### Verbose Output

With `-v`, the script prints:

- build context
- the exact command being executed
- full backend output from the underlying tools

## Common Commands

### Clean

```bash
python3 flash-CLI.py -r my-fpga-project -m clean
```

### Synthesis Only

```bash
python3 flash-CLI.py -r my-fpga-project -m synth
```

### Place And Route

```bash
python3 flash-CLI.py -r my-fpga-project -m pnr
```

### Generate Bitstream

```bash
python3 flash-CLI.py -r my-fpga-project -m bitstream
```

### Flash The Board

```bash
python3 flash-CLI.py -r my-fpga-project -m flash
```

### Full Flow

```bash
python3 flash-CLI.py -r my-fpga-project -m all
```

### Full Flow With Verbose Logs

```bash
python3 flash-CLI.py -r my-fpga-project -m all -v
```

## Generated Files

By default, generated files go into:

```text
<project-folder>/build/
```

Typical outputs:

- `final.cst`: merged constraints file
- `synth.json`: synthesis output
- `pnr.json`: place-and-route output
- `pack.fs`: final bitstream

## Assumptions

- the top module is named `top`
- Verilog sources are collected from `src/*.v`
- constraint files are collected from `core/*.cst`
- `flash` requires a working board connection and a working `openFPGALoader` setup
