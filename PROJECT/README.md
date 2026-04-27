# PROJECT

This project is the working area for a real FFT FPGA design and its supporting
research. The current repository is still in an early stage: it contains design
notes, Python reference/research scripts, and placeholder Verilog simulation
files.

## Current Layout

```text
PROJECT/
|-- README.md
|-- docs/
|   |-- HW-CONTEXT.md
|   `-- RFFT-CONTEXT.md
|-- research/
|   |-- mic-fft/
|   |   |-- qt_fft_mic.py
|   |   `-- requirements.txt
|   `-- rfft/
|       `-- rfft_from_scratch.py
`-- sim/
    |-- src/
    |   `-- rfft.v
    `-- tb/
        `-- tb_rfft.v
```

## Directory Guide

- `docs/`: project notes and implementation guidance.
- `research/`: Python experiments and reference models.
- `research/rfft/rfft_from_scratch.py`: scratch Q15-style RFFT reference model.
- `research/mic-fft/qt_fft_mic.py`: PyQtGraph microphone spectrum demo using the
  scratch RFFT function.
- `research/mic-fft/requirements.txt`: Python dependencies for the microphone
  demo.
- `sim/src/rfft.v`: current Verilog source placeholder for the RFFT module.
- `sim/tb/tb_rfft.v`: current Verilog testbench placeholder.

## Documentation

- [docs/HW-CONTEXT.md](docs/HW-CONTEXT.md): target board notes for the Sipeed
  Tang Primer 20K and related tooling.
- [docs/RFFT-CONTEXT.md](docs/RFFT-CONTEXT.md): RFFT architecture notes,
  recommended RTL module split, and testbench-first development order.

## Research Code

The Python RFFT model in `research/rfft/rfft_from_scratch.py` implements the
main algorithm pieces that should later be matched in RTL:

1. Q15 coefficient generation.
2. Real-sample packing into an internal complex FFT input.
3. Bit-reversed address ordering.
4. Radix-2 butterfly stages.
5. Real FFT recombination.

The microphone demo in `research/mic-fft/qt_fft_mic.py` reads `int16` audio
samples, calls the scratch RFFT model, and displays the magnitude spectrum with
PyQtGraph.

To set up the demo dependencies from the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r research/mic-fft/requirements.txt
```

When running the microphone demo, make sure Python can import the `research/rfft`
module path. One simple option from the repository root is:

```sh
PYTHONPATH=research python3 research/mic-fft/qt_fft_mic.py
```

## Simulation Status

The Verilog files currently exist as placeholders:

- `sim/src/rfft.v`
- `sim/tb/tb_rfft.v`

The next practical step is to replace these placeholders with a minimal
simulation target and testbench, then compare the simulated output against the
Python reference model.

## Target Scope

The design notes currently target:

- 16-bit signed real input samples,
- a 2048-point real FFT,
- a 1024-point internal complex FFT,
- Q15-like fixed-point arithmetic,
- FPGA implementation on the Sipeed Tang Primer 20K.

Keep future RTL, constraints, board wrappers, generated build output, and formal
verification files in separate directories as they are added.
