@echo off
REM Build firmware C mau va ky bang auth_signer.py (chay trong auth_sim/fw_c cua project)
REM Toolchain: xPack riscv-none-elf-gcc (PicoRV32: rv32i, khong nen RVC)
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -T link.ld start.S main.c -o fw.elf || exit /b 1
python ..\auth_signer.py sign --elf fw.elf --out-code code.hex --out-tag tag.hex --out-data data.hex || exit /b 1
python ..\auth_signer.py check --code code.hex --tag tag.hex
