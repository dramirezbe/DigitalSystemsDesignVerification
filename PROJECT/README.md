# PROJECT

This area is the home for the main FPGA project. The goal is to keep research, documentation, RTL, simulation, and board integration separated so the project can grow without becoming tangled.

## Proposed Layout

```text
PROJECT/
|-- README.md
|-- docs/
|   |-- hw-context.md
|   |-- rfft-context.md
|   `-- architecture.md
|-- research/
|   |-- mic-fft/
|   |   `-- qt_fft_mic.py
|   `-- rfft/
|       `-- rfft_from_scratch.py
|-- rtl/
|   |-- rfft_top.v
|   |-- sample_buffer.v
|   |-- pack_real_to_complex.v
|   |-- bit_reverse.v
|   |-- twiddle_rom.v
|   |-- butterfly_radix2.v
|   |-- fft_stage_controller.v
|   |-- complex_fft_core.v
|   `-- rfft_recombine.v
|-- sim/
|   |-- src/
|   |   `-- rfft.v
|   `-- tb/
|       |-- tb_sample_buffer.v
|       |-- tb_butterfly_radix2.v
|       |-- tb_complex_fft_core.v
|       `-- tb_rfft_recombine.v
|-- constraints/
|   `-- tang_primer_20k/
|       `-- top.cst
|-- board/
|   `-- tang_primer_20k/
|       `-- top_wrapper.v
|-- tools/
|   |-- build.sh
|   `-- simulate.sh
|-- build/
`-- verification/
	`-- formal/
```

## What Goes Where

- `docs/`: project-level hardware notes, decisions, and architecture documents.
- `research/`: exploratory code, math experiments, and proof-of-concept scripts.
- `rtl/`: synthesizable Verilog modules only.
- `sim/`: top-level simulation files and testbench collection.
- `constraints/`: board pinouts, clocks, timing constraints, and device-specific files.
- `board/`: wrapper modules that adapt the core RTL to a specific FPGA board.
- `tools/`: helper scripts for build, simulation, and flow automation.
- `build/`: generated artifacts only.
- `verification/`: assertions, formal checks, and reusable verification assets.

## Current Content Mapping

- [PROJECT/HW-CONTEXT.md](HW-CONTEXT.md) -> `docs/hw-context.md`
- [PROJECT/docs/RFFT-CONTEXT.md](docs/RFFT-CONTEXT.md) -> `docs/rfft-context.md`
- [PROJECT/research/mic-fft/qt_fft_mic.py](research/mic-fft/qt_fft_mic.py) -> `research/mic-fft/qt_fft_mic.py`
- [PROJECT/sim/rfft.v](sim/rfft.v) -> `rtl/rfft_top.v` or `sim/testbenches/tb_rfft_top.v` depending on its final role

## Suggested Development Order

1. Keep research code in `research/` as the reference model.
2. Move design decisions into `docs/`.
3. Implement each Verilog block in `rtl/`.
4. Add one testbench per module in `sim/testbenches/`.
5. Connect the modules into `rfft_top.v`.
6. Add board-specific wrappers and constraints only after the RTL is stable.

## Target Scope

For now, keep the project scoped to a 16-bit, 2048-point real FFT with a 1024-point internal complex FFT core.
