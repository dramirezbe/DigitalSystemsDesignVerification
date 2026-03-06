#!/bin/bash
verilator -Wno-WIDTHEXPAND --timing --binary --trace tb_$1.v $1.v
./obj_dir/Vtb_$1