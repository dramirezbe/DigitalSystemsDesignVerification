#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: ./builder.sh -r <project-folder> [-x] [-w]"
	echo "  -r <folder>   Project folder to compile/simulate from repository root"
	echo "  -x            Execute testbenches after compilation"
	echo "  -w            Open GTKWave for generated .vcd files (requires -x)"
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Error: '$1' was not found in PATH." >&2
		exit 1
	fi
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME=""
RUN_TESTBENCH=0
OPEN_WAVE=0

while getopts ":r:xwh" opt; do
	case "$opt" in
		r)
			PROJECT_NAME="$OPTARG"
			;;
		x)
			RUN_TESTBENCH=1
			;;
		w)
			OPEN_WAVE=1
			;;
		h)
			usage
			exit 0
			;;
		:)
			echo "Error: missing value for -$OPTARG" >&2
			usage
			exit 1
			;;
		?)
			echo "Error: invalid option -$OPTARG" >&2
			usage
			exit 1
			;;
	esac
done

if [[ -z "$PROJECT_NAME" ]]; then
	usage
	exit 1
fi

if [[ "$OPEN_WAVE" -eq 1 && "$RUN_TESTBENCH" -eq 0 ]]; then
	echo "Error: -w requires -x." >&2
	usage
	exit 1
fi

PROJECT_DIR="$ROOT_DIR/$PROJECT_NAME"
SRC_DIR="$PROJECT_DIR/src"
TB_DIR="$PROJECT_DIR/tb"
BUILD_DIR="$PROJECT_DIR/build"

if [[ ! -d "$PROJECT_DIR" ]]; then
	echo "Error: project '$PROJECT_NAME' does not exist." >&2
	exit 1
fi

if [[ ! -d "$SRC_DIR" || ! -d "$TB_DIR" ]]; then
	echo "Error: '$PROJECT_NAME' must contain 'src' and 'tb' directories." >&2
	exit 1
fi

require_cmd iverilog
require_cmd vvp
if [[ "$OPEN_WAVE" -eq 1 ]]; then
	require_cmd gtkwave
fi

mkdir -p "$BUILD_DIR"

mapfile -t SRC_FILES < <(find "$SRC_DIR" -maxdepth 1 -type f -name '*.v' | sort)
mapfile -t TB_FILES < <(find "$TB_DIR" -maxdepth 1 -type f -name '*.v' | sort)

if [[ "${#SRC_FILES[@]}" -eq 0 ]]; then
	echo "Error: no source .v files found in '$SRC_DIR'." >&2
	exit 1
fi

if [[ "${#TB_FILES[@]}" -eq 0 ]]; then
	echo "Error: no testbench .v files found in '$TB_DIR'." >&2
	exit 1
fi

for tb_file in "${TB_FILES[@]}"; do
	tb_base="$(basename "$tb_file" .v)"
	out_vvp="$BUILD_DIR/${tb_base}.vvp"

	echo "[1/2] Compiling $tb_base"
	iverilog -o "$out_vvp" "${SRC_FILES[@]}" "$tb_file"

	if [[ "$RUN_TESTBENCH" -eq 1 ]]; then
		echo "[2/2] Running simulation $tb_base"
		(
			cd "$PROJECT_DIR"
			vvp "build/${tb_base}.vvp"
		)
	fi
done

if [[ "$RUN_TESTBENCH" -eq 0 ]]; then
	echo "Compilation completed. Use -x to run the generated testbenches."
	exit 0
fi

# If any testbench writes VCDs to project root, move them into build.
mapfile -t ROOT_VCDS < <(find "$PROJECT_DIR" -maxdepth 1 -type f -name '*.vcd' | sort)
for vcd in "${ROOT_VCDS[@]}"; do
	mv -f "$vcd" "$BUILD_DIR/$(basename "$vcd")"
done

mapfile -t VCD_FILES < <(find "$BUILD_DIR" -maxdepth 1 -type f -name '*.vcd' | sort)

if [[ "${#VCD_FILES[@]}" -eq 0 ]]; then
	echo "No .vcd files were detected in '$BUILD_DIR'. Check your testbench dumpfile path."
	exit 0
fi

echo "Generated waveforms:"
for vcd in "${VCD_FILES[@]}"; do
	echo " - ${vcd#$ROOT_DIR/}"
done

if [[ "$OPEN_WAVE" -eq 1 ]]; then
	for vcd in "${VCD_FILES[@]}"; do
		gtkwave "$vcd" >/dev/null 2>&1 &
	done
	echo "GTKWave launched in background."
else
	echo "To open manually: gtkwave $PROJECT_NAME/build/<file>.vcd &"
fi
