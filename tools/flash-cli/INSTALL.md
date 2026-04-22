# INSTALL

This guide explains how to install the toolchain required by `flash-CLI.py`.

## Expected Toolchain

`flash-CLI.py` expects these tools to be available in your shell:

- `yosys`
- `nextpnr-gowin`
- `gowin_pack`
- `openFPGALoader`

For the `gowin_pack` step, this guide uses Apycula installed with `pipx`.

## 1. Install The Base Toolchain

On Debian 13:

```bash
sudo apt update
sudo apt install yosys nextpnr-gowin openfpgaloader pipx
pipx install "apycula==0.11.1" --force
pipx ensurepath
```

After this, restart your terminal session.

## 2. Verify The Installed Commands

Check that the required tools are visible in your shell:

```bash
which yosys
which nextpnr-gowin
which gowin_pack
which openFPGALoader
```

Expected result:

- all four commands should resolve successfully
- `gowin_pack` will usually come from the `pipx` Apycula installation

## 3. Configure USB Access For Your Board

If your board uses an FTDI-based interface, a `udev` rule may be required for non-root access.

Example for vendor `0403`:

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666"' | sudo tee /etc/udev/rules.d/99-fpga.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Then unplug and reconnect the board.

## 4. Verify Board Detection

Run:

```bash
openFPGALoader --detect
```

If your setup is correct, the board should be detected and a compatible device should be listed.

## 5. Verify `flash-CLI.py`

Assuming your project is located in `my-fpga-project/`:

```bash
python3 flash-CLI.py -r my-fpga-project -m clean
python3 flash-CLI.py -r my-fpga-project -m synth
python3 flash-CLI.py -r my-fpga-project -m pnr
python3 flash-CLI.py -r my-fpga-project -m bitstream
python3 flash-CLI.py -r my-fpga-project -m flash
```

Or run the full flow:

```bash
python3 flash-CLI.py -r my-fpga-project -m all
```

Verbose mode:

```bash
python3 flash-CLI.py -r my-fpga-project -m all -v
```

## 6. What `flash-CLI.py` Expects

Each project must have this structure:

```text
project-folder/
├── core/
│   └── *.cst
└── src/
    └── *.v
```

Important assumptions:

- top module name: `top`
- Verilog files are read from `src/*.v`
- constraint files are merged from `core/*.cst`
- generated files are written to `build/` by default

## Troubleshooting

### `gowin_pack: command not found`

`apycula` may not be installed correctly through `pipx`, or your shell session may not yet include the `pipx` path.

Try:

```bash
pipx ensurepath
```

Then restart the terminal.

### `open_device: failed to initialize ftdi`

This usually means a board access problem, not a `flash-CLI.py` bug.

Check:

- the board is connected
- the `udev` rule was installed
- the board was replugged after reloading rules
- your current shell is a fresh session

### `openFPGALoader --detect` works, but flashing from another environment fails

That can happen if the command is being run inside a sandboxed or restricted environment without direct USB device access.
If it works in your normal terminal, your local machine setup is likely fine.
