import subprocess
from typing import List, Tuple
from pathlib import Path
import argparse
import sys
import shutil
import threading
import os
import pty
import select

# ANSI Escape codes for terminal colors
PURPLE = '\033[95m'
RED = '\033[91m'
CYAN = '\033[96m'
DIM = '\033[2m'
RESET = '\033[0m'

DEVICE = "GW2A-LV18PG256C8/I7"
FAMILY = "GW2A-18"
SYNTH_FAMILY = "gw2a"
SYNTH_JSON_NAME = "synth.json"
TOP_MODULE = "top"
BOARD = "tangprimer20k"
VERBOSE = False

def printPhase(title: str) -> None:
    print(f"{PURPLE}==> {title}{RESET}", flush=True)

def printCommand(cmd: List[str]) -> None:
    if VERBOSE:
        print(f"{DIM}$ {' '.join(cmd)}{RESET}", flush=True)

def printInfo(message: str) -> None:
    if VERBOSE:
        print(message, flush=True)

def printLiveOutput(message: str) -> None:
    print(message, end="", flush=True)

def printError(message: str) -> None:
    print(f"{RED}{message}{RESET}", file=sys.stderr, flush=True)

def printStatus(message: str) -> None:
    print(f"{CYAN}{message}{RESET}", flush=True)

def setupParser() -> argparse.ArgumentParser:
    """
    Defines and configures the CLI arguments.
    """
    examples = """
               examples:
               python script.py -r project_folder/                     (defaults to 'all' mode)
               python script.py -r project_folder/ -m synth            (run only synthesis)
               python script.py -r project_folder/ -m flash -b out_dir (build and flash using 'out_dir')
               python script.py -r project_folder/ -m clean            (clean the build directory)
               python script.py -r project_folder/ -m all              (run all steps: synth, pnr, bitstream, flash)
               """
    parser = argparse.ArgumentParser(
        description="FPGA build automation script for Gowin tooling.",
        epilog=examples,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument("-r", dest="folder_path", required=True, type=Path, help="Target folder path containing .v files")
    parser.add_argument("-m", dest="mode", choices=["synth", "pnr", "bitstream", "flash", "clean", "all"], default="all", help="Execution mode")
    parser.add_argument("-b", dest="build_dir", default="build", type=Path, help="Optional build directory (default: build)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose tool output")
    
    return parser

def initParser() -> argparse.Namespace:
    """
    Handles argument parsing, path resolution, and initial directory setup.
    """
    parser = setupParser()
    
    # Check if no arguments were passed, print help and exit
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(1)
        
    args = parser.parse_args()
    global VERBOSE
    VERBOSE = args.verbose
    
    # Normalize and resolve paths to absolute paths
    args.folder_path = args.folder_path.resolve()
    if args.build_dir.is_absolute():
        args.build_dir = args.build_dir.resolve()
    else:
        args.build_dir = (args.folder_path / args.build_dir).resolve()
    
    # Automatically create the build directory (and any parent directories if needed)
    # exist_ok=True prevents errors if the directory already exists
    if args.mode != "clean":
        args.build_dir.mkdir(parents=True, exist_ok=True)
    
    return args

def executeCommand(cmd: List[str]) -> Tuple[int, str, str]:
    """
    Executes a shell command using subprocess with unbuffered I/O and logs the output.
    stdout is logged in purple, and stderr is logged in red.
    
    Args:
        cmd (List[str]): An array representing the command and its arguments.
        
    Returns:
        Tuple[int, str, str]: A tuple containing the return code, stdout, and stderr.
    """
    try:
        stdout_chunks: List[str] = []
        stderr_chunks: List[str] = []
        use_pty = cmd[0] == "openFPGALoader"

        # Ask common Unix tools to line-buffer when possible. This helps a lot
        # for verbose commands, although some tools may still buffer internally.
        run_cmd = cmd
        if shutil.which("stdbuf") and not use_pty:
            run_cmd = ["stdbuf", "-oL", "-eL", *cmd]

        printCommand(cmd)
        stream_live = VERBOSE or use_pty

        if use_pty:
            master_fd, slave_fd = pty.openpty()
            try:
                with subprocess.Popen(
                    cmd,
                    stdin=slave_fd,
                    stdout=slave_fd,
                    stderr=slave_fd,
                    text=False,
                ) as process:
                    os.close(slave_fd)

                    while True:
                        ready, _, _ = select.select([master_fd], [], [], 0.1)
                        if master_fd in ready:
                            try:
                                data = os.read(master_fd, 4096)
                            except OSError:
                                data = b""
                            if data:
                                text = data.decode("utf-8", errors="replace")
                                stdout_chunks.append(text)
                                printLiveOutput(text)
                        if process.poll() is not None:
                            break

                    while True:
                        try:
                            data = os.read(master_fd, 4096)
                        except OSError:
                            break
                        if not data:
                            break
                        text = data.decode("utf-8", errors="replace")
                        stdout_chunks.append(text)
                        printLiveOutput(text)

                    return_code = process.wait()
                    combined_output = ''.join(stdout_chunks).strip()
                    stderr_output = combined_output if return_code != 0 else ""
                    return return_code, combined_output, stderr_output
            finally:
                try:
                    os.close(master_fd)
                except OSError:
                    pass

        with subprocess.Popen(
            run_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        ) as process:

            def consume_stream(stream, chunks: List[str], prefix: str, log_method) -> None:
                for line in iter(stream.readline, ''):
                    chunks.append(line)
                    if stream_live:
                        log_method(f"{prefix}{line.rstrip()}")
                stream.close()

            stdout_thread = threading.Thread(
                target=consume_stream,
                args=(process.stdout, stdout_chunks, "", printInfo),
                daemon=True,
            )
            stderr_thread = threading.Thread(
                target=consume_stream,
                args=(process.stderr, stderr_chunks, "", printInfo if stream_live else (lambda _line: None)),
                daemon=True,
            )

            stdout_thread.start()
            stderr_thread.start()

            process.wait()
            stdout_thread.join()
            stderr_thread.join()

            stdout_str = ''.join(stdout_chunks).strip()
            stderr_str = ''.join(stderr_chunks).strip()

            if stderr_str:
                if process.returncode == 0:
                    if not stream_live and cmd[0] == "openFPGALoader":
                        print(f"{DIM}{stderr_str}{RESET}", file=sys.stderr, flush=True)
                else:
                    printError(stderr_str)

            return process.returncode, stdout_str, stderr_str
            
    except FileNotFoundError as e:
        error_msg = f"Command execution failed: {e}"
        printError(error_msg)
        return -1, "", error_msg
        
    except Exception as e:
        error_msg = f"An unexpected error occurred: {e}"
        printError(error_msg)
        return -1, "", error_msg

def requireCommandSuccess(cmd: List[str]) -> None:
    """
    Executes a command and aborts immediately if it fails.
    """
    return_code, _, stderr = executeCommand(cmd)
    if return_code != 0:
        raise RuntimeError(f"Command failed ({return_code}): {' '.join(cmd)}\n{stderr}")

def generateBuildCSTFile(in_path: Path, out_path: Path) -> None:
    """
    Searches for *.cst files in in_path and concatenates them into final.cst within out_path.
    """
    # Define the exact path for the final output file
    final_file = out_path / "final.cst"
    cst_files = sorted(in_path.glob('*.cst'))

    if not in_path.exists():
        raise FileNotFoundError(f"Constraints folder not found: {in_path}")
    if not in_path.is_dir():
        raise NotADirectoryError(f"Constraints path is not a directory: {in_path}")
    if not cst_files:
        raise FileNotFoundError(f"No .cst files found in: {in_path}")
    
    # Create the output directory if it doesn't exist
    out_path.mkdir(parents=True, exist_ok=True)

    printPhase("Generating Constraints Bundle")
    
    # Open the output file in write mode ('w')
    with open(final_file, 'w', encoding='utf-8') as outfile:
        
        # Iterate over all files ending in .cst in the input directory
        for cst_file in cst_files:
            
            # Avoid concatenating the output file with itself if in_path == out_path
            if cst_file == final_file:
                continue
                
            # Open each found file in read mode ('r')
            with open(cst_file, 'r', encoding='utf-8') as infile:
                # Write the content to the final file
                outfile.write(infile.read())
                
                # Optional: Add a newline character between files 
                # to prevent the last line of one file from merging with the first line of the next
                outfile.write("\n")
    printStatus("Constraints ready")

def synth(src_folder: Path, synth_json_path: Path) -> None:
    if not src_folder.exists():
        raise FileNotFoundError(f"Source folder not found: {src_folder}")
    if not src_folder.is_dir():
        raise NotADirectoryError(f"Source path is not a directory: {src_folder}")

    verilog_files = sorted(src_folder.glob("*.v"))
    if not verilog_files:
        raise FileNotFoundError(f"No .v files found in: {src_folder}")

    printPhase("Synthesis")

    read_sources = " ".join(str(file_path) for file_path in verilog_files)
    script = (
        f"read_verilog -sv {read_sources}; "
        f"synth_gowin -top {TOP_MODULE} -family {SYNTH_FAMILY} -json {synth_json_path}"
    )
    requireCommandSuccess(["yosys", "-p", script])
    printStatus("Synthesis completed")

def pnr(build_folder: Path, synth_json_path: Path) -> None:
    pnr_json_path = build_folder / "pnr.json"
    cst_path = build_folder / "final.cst"

    if not synth_json_path.exists():
        raise FileNotFoundError(f"Synthesis output not found: {synth_json_path}")
    if not cst_path.exists():
        raise FileNotFoundError(f"Constraint file not found: {cst_path}")

    printPhase("Place And Route")
    
    cmd = [
        "nextpnr-gowin",
        "--json", str(synth_json_path),
        "--write", str(pnr_json_path),
        "--device", DEVICE,
        "--cst", str(cst_path)
    ]
    
    requireCommandSuccess(cmd)
    printStatus("Place and route completed")

def bitstream(build_folder: Path) -> None:
    pnr_json_path = build_folder / "pnr.json"
    pack_fs_path = build_folder / "pack.fs"

    if not pnr_json_path.exists():
        raise FileNotFoundError(f"Place-and-route output not found: {pnr_json_path}")

    printPhase("Bitstream Packing")
    
    cmd = [
        "gowin_pack",
        "-d", FAMILY,
        "-o", str(pack_fs_path),
        str(pnr_json_path)
    ]
    requireCommandSuccess(cmd)
    printStatus("Bitstream generated")

def flash(build_folder: Path) -> None:
    pack_fs_path = build_folder / "pack.fs"

    if not pack_fs_path.exists():
        raise FileNotFoundError(f"Bitstream file not found: {pack_fs_path}")

    printPhase("Flashing")
    
    cmd = [
        "openFPGALoader",
        "-b", BOARD,
        str(pack_fs_path)
    ]
    requireCommandSuccess(cmd)
    printStatus("Flash completed")

def main():
    # Setup configuration, parse arguments, and prepare directories
    args = initParser()
    
    # Define folder structures
    cst_folder = args.folder_path / "core"
    v_folder = args.folder_path / "src"
    synth_json_path = args.build_dir / SYNTH_JSON_NAME
    
    # Print configuration info
    if VERBOSE:
        print(f"{CYAN}Project:{RESET} {args.folder_path}")
        print(f"{CYAN}Constraints:{RESET} {cst_folder}")
        print(f"{CYAN}Sources:{RESET} {v_folder}")
        print(f"{CYAN}Mode:{RESET} {args.mode}")
        print(f"{CYAN}Build Dir:{RESET} {args.build_dir}")
    else:
        printStatus(f"Mode: {args.mode}")

    try:
        match args.mode:
            case "synth":
                synth(v_folder, synth_json_path)
                
            case "pnr":
                synth(v_folder, synth_json_path)
                generateBuildCSTFile(cst_folder, args.build_dir)
                pnr(args.build_dir, synth_json_path)
                
            case "bitstream":
                synth(v_folder, synth_json_path)
                generateBuildCSTFile(cst_folder, args.build_dir)
                pnr(args.build_dir, synth_json_path)
                bitstream(args.build_dir)
                
            case "flash" | "all":
                synth(v_folder, synth_json_path)
                generateBuildCSTFile(cst_folder, args.build_dir)
                pnr(args.build_dir, synth_json_path)
                bitstream(args.build_dir)
                flash(args.build_dir)
                
            case "clean":
                printPhase("Clean")
                if args.build_dir.exists():
                    shutil.rmtree(args.build_dir)
                    print(f"Cleaned {args.build_dir}")
                else:
                    print(f"Build directory does not exist: {args.build_dir}")
    except (FileNotFoundError, NotADirectoryError, RuntimeError) as error:
        printError(str(error))
        sys.exit(1)
    
if __name__ == "__main__":
    main()
