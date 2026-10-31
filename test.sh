#!/usr/bin/env bash
# Smoke-tests an installed (possibly moved) toolkit: ./test.sh <dir>
set -euo pipefail
source "$1/env.sh"
TK=$RISCVTOOLKIT
cd "$(mktemp -d)"

cat > hello.c <<'C'
#include <stdio.h>
int main(void) { printf("hello\n"); return 0; }
C

# every C library links for rv32 and rv64 variants (medany: picolibc links at 0x80000000)
for target in rv32i_zicsr:ilp32 rv32imc_zicsr:ilp32 rv32e:ilp32e rv32imafc:ilp32f rv64gc:lp64d; do
    # picolibc leaves stdout to the program or an OS layer: link its semihosting one
    for specs in "" "--specs=nano.specs" "--specs=picolibc.specs --oslib=semihost"; do
        riscv64-unknown-elf-gcc -march="${target%:*}" -mabi="${target#*:}" -mcmodel=medany $specs hello.c -o hello
        echo "ok: link $target ${specs:-newlib}"
    done
done

# spike + pk run newlib programs (spike runs the toolkit's dtc)
[ "$(command -v dtc)" = "$TK/bin/dtc" ] && echo "ok: dtc from the toolkit"
riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64d hello.c -o hello64
spike pk hello64 | grep -q hello && echo "ok: spike pk rv64"
riscv64-unknown-elf-gcc -march=rv32imac -mabi=ilp32 hello.c -o hello32
spike --isa=rv32imac_zicsr_zifencei "$TK/riscv32-unknown-elf/bin/pk" hello32 | grep -q hello && echo "ok: spike pk rv32"

# verilator builds and runs a model
cat > top.v <<'V'
module top; initial begin $display("hello"); $finish; end endmodule
V
verilator --binary -j 0 top.v >/dev/null
obj_dir/Vtop | grep -q hello && echo "ok: verilator"

openocd --version 2>&1 | grep -q "Open On-Chip Debugger" && echo "ok: openocd"
