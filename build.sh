#!/usr/bin/env bash
# Builds the toolkit into $PREFIX from the sources pinned in versions.env.
#   ./build.sh                 # all tools, in order, then finish (strip, env files)
#   ./build.sh spike finish    # only these
# Env: PREFIX (default ./install), WORK (sources and build trees, default ./work), JOBS.
set -euo pipefail
cd "$(dirname "$0")"
source versions.env

PREFIX=$(realpath -m "${PREFIX:-install}")
WORK=$(realpath -m "${WORK:-work}")
JOBS=${JOBS:-$(nproc)}
export PATH="$PREFIX/bin:$PATH"

# fetch <name> <url> <ref>: shallow checkout of a tag or commit into $WORK/src/<name>
fetch() {
    local dir=$WORK/src/$1
    if [ ! -d "$dir" ]; then
        git init -q "$dir"
        git -C "$dir" fetch -q --depth 1 "$2" "$3"
        git -C "$dir" checkout -q FETCH_HEAD
    fi
    SRC=$dir
    BLD=$WORK/build/$1
    mkdir -p "$BLD"
}

# GCC, binutils, GDB and newlib (+ newlib-nano) for every multilib, as riscv64-unknown-elf-*
build_gcc() {
    fetch riscv-gnu-toolchain https://github.com/riscv-collab/riscv-gnu-toolchain.git "$GNU_TOOLCHAIN_REF"
    cd "$BLD"
    "$SRC/configure" --prefix="$PREFIX" --with-multilib-generator="$MULTILIBS"
    # no Python in GDB: it would tie the binary to the build machine's libpython
    make -j"$JOBS" newlib GDB_TARGET_FLAGS_EXTRA=--with-python=no
}

# picolibc for the same multilibs, beside newlib: select it with --specs=picolibc.specs.
# sysroot-install makes the specs paths relative to the compiler, so the tree can be moved.
build_picolibc() {
    fetch picolibc https://github.com/picolibc/picolibc.git "$PICOLIBC_REF"
    meson setup --reconfigure "$BLD" "$SRC" \
        --cross-file "$SRC/scripts/cross-riscv64-unknown-elf.txt" \
        --prefix="$PREFIX" -Dsysroot-install=true \
        -Dincludedir=picolibc/riscv64-unknown-elf/include \
        -Dlibdir=picolibc/riscv64-unknown-elf/lib \
        -Dtests=false
    ninja -C "$BLD" install
}

# Device-tree compiler: Spike runs it at start-up to build its device tree
build_dtc() {
    fetch dtc https://github.com/dgibson/dtc.git "$DTC_REF"
    make -C "$SRC" -j"$JOBS" PREFIX="$PREFIX" NO_PYTHON=1 NO_YAML=1 install-bin
}

# Spike, the reference ISA simulator
build_spike() {
    fetch spike https://github.com/riscv-software-src/riscv-isa-sim.git "$SPIKE_REF"
    git -C "$SRC" submodule update -q --init --depth 1     # softfloat
    cd "$BLD"
    "$SRC/configure" --prefix="$PREFIX" --without-boost --without-boost-asio --without-boost-regex
    make -j"$JOBS"
    make install
}

# The proxy kernel, rv64 (riscv64-unknown-elf/bin/pk) and rv32 (riscv32-unknown-elf/bin/pk).
# rv32 is built with C: a pk without it refuses programs that use compressed instructions.
build_pk() {
    fetch pk https://github.com/riscv-software-src/riscv-pk.git "$PK_REF"
    local xlen
    for xlen in 64 32; do
        mkdir -p "$BLD/rv$xlen" && cd "$BLD/rv$xlen"
        if [ $xlen = 32 ]; then
            "$SRC/configure" --prefix="$PREFIX" --host=riscv64-unknown-elf \
                --with-arch=rv32ic_zicsr_zifencei --with-abi=ilp32
        else
            "$SRC/configure" --prefix="$PREFIX" --host=riscv64-unknown-elf
        fi
        make -j"$JOBS"
        make install
    done
}

# no tcmalloc: users would need libtcmalloc installed, and builds would differ by machine
build_verilator() {
    fetch verilator https://github.com/verilator/verilator.git "$VERILATOR_REF"
    cd "$SRC"
    autoconf
    ./configure --prefix="$PREFIX" --disable-tcmalloc
    make -j"$JOBS"
    make install
}

# OpenOCD (RISC-V fork): JTAG debug of boards, and of Spike through --rbb-port, with GDB.
# configure silently drops an adapter whose library is missing, so the adapters that matter are
# enabled explicitly (configure fails instead), one per library: libusb (ftdi, stlink, cmsis-dap
# v2, usb-blaster 2, ...), hidapi (cmsis-dap v1), libftdi (usb-blaster). jimtcl and libjaylink
# (J-Link) are built in; capstone is off (its library version differs between distros).
build_openocd() {
    fetch openocd https://github.com/riscv-collab/riscv-openocd.git "$OPENOCD_REF"
    cd "$SRC"
    ./bootstrap with-submodules
    cd "$BLD"
    "$SRC/configure" --prefix="$PREFIX" --disable-werror --without-capstone \
        --enable-internal-jimtcl --enable-internal-libjaylink \
        --enable-ftdi --enable-stlink --enable-cmsis-dap-v2 --enable-usb-blaster-2 \
        --enable-cmsis-dap --enable-usb-blaster --enable-jlink \
        --enable-remote-bitbang --enable-jtag_vpi --enable-jtag_dpi
    make -j"$JOBS"
    make install
}

# Last step: host programs lose their debug symbols (GCC's alone shrink by ~2 GB; RISC-V
# libraries are untouched), and the env files and versions go into the install.
build_finish() {
    local d f
    for d in "$PREFIX/bin" "$PREFIX/libexec"; do
        [ -d "$d" ] || continue
        find "$d" -type f -perm -u+x | while read -r f; do
            if [ "$(head -c4 "$f")" = $'\x7fELF' ]; then strip "$f"; fi
        done
    done
    cp env.sh env.csh versions.env "$PREFIX/"
}

TOOLS=(gcc picolibc dtc spike pk verilator openocd finish)
for tool in "${@:-${TOOLS[@]}}"; do
    echo "=== $tool"
    (build_"$tool")
done
echo "=== done: $PREFIX"
