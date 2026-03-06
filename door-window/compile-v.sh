#!/bin/bash
verilator -Wno-WIDTHEXPAND --binary --trace tb_$1.v $1.v