# riscvtoolkit

[![release](https://github.com/saursin/riscvtoolkit/actions/workflows/release.yml/badge.svg)](https://github.com/saursin/riscvtoolkit/actions/workflows/release.yml)

Prebuilt RISC-V tools for x86-64 Linux, built from pinned sources ([versions.env](versions.env)):

| Tool | Notes |
| :--- | :--- |
| GCC, binutils, GDB (`riscv64-unknown-elf-*`) | rv32 and rv64 multilib (see `MULTILIBS`); host programs stripped |
| newlib, newlib-nano | the default C library; nano with `--specs=nano.specs` |
| picolibc | same multilibs; `--specs=picolibc.specs` |
| Spike | reference ISA simulator; `--isa=rv32...` for 32-bit |
| pk | proxy kernel for newlib programs: `spike pk prog` (rv64); rv32: `spike --isa=rv32<..>c_zicsr_zifencei $RISCVTOOLKIT/riscv32-unknown-elf/bin/pk prog` (needs C in `--isa`) |
| Verilator | |
| dtc | device-tree compiler (Spike runs it) |
| OpenOCD | RISC-V fork; FTDI, J-Link, ST-Link, CMSIS-DAP, USB-Blaster and other probes; Spike via `--rbb-port` |

## Install

Download a release, unpack it anywhere, and source its env file (adds `bin/` to `PATH`, sets
`RISCVTOOLKIT`):

```bash
tar -xJf riscvtoolkit-<ver>-linux-x86_64.tar.xz -C ~/opt
source ~/opt/riscvtoolkit/env.sh        # bash, zsh;  tcsh: source ~/opt/riscvtoolkit/env.csh
```

Runs on glibc 2.35 (Ubuntu 22.04) or newer. Host needs: `g++` and `make` (Verilator), `libusb-1.0`, `hidapi` and `libftdi1`
(OpenOCD). For OpenOCD to open USB probes without root, install its udev rules once:

```bash
sudo cp $RISCVTOOLKIT/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```
Verilator needs `VERILATOR_ROOT=~/opt/riscvtoolkit/share/verilator` once the tree is moved
from where it was built.

## Build

```bash
./build.sh                       # all tools into ./install (PREFIX=... to change)
./build.sh spike pk finish       # some tools (finish: strip, add env files)
```

Smoke test: `./test.sh <dir>`. Build dependencies: see the apt list in [.github/workflows/release.yml](.github/workflows/release.yml).

## Release

Bump refs and `TOOLKIT_VERSION` in `versions.env`, push, then run the `release` workflow
(Actions tab). The `build` job builds on Ubuntu 22.04 and uploads the tarball as an artifact; the
`test` job tests it unpacked elsewhere and, with "publish" checked, publishes
`riscvtoolkit-<ver>-linux-x86_64.tar.xz` with its SHA-256. A failed `test` job can be re-run alone
("Re-run failed jobs"), and the tarball can be downloaded from the run page.
