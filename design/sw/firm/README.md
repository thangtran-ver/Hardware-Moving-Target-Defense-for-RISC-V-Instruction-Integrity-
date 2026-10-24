# Firmware (tangnano20k_top)

Firmware RV32I cho SoC xac thuc lenh (`auth_soc_top`) tren Tang Nano 20K.
Build bang toolchain xPack RISC-V GCC, ky bang `auth_signer.py` (nam ngay trong thu muc nay).

## File nguon

| File | Vai tro |
| --- | --- |
| `start.S` | Ma khoi dong |
| `main.c` | Chuong trinh chinh. Co 2 co bien dich tan cong: `ATTACK_WCODE`, `ATTACK_JUMP` |
| `link.ld` | Linker script: CODE `0x00000000` (8 KB), DATA `0x00020100` (3.75 KB) |
| `auth_signer.py` | Ky firmware: tinh tag cho tung block lenh, sinh `code/tag/data.hex` |

File sinh ra (`*.elf`, `active/`) KHONG commit.

## Yeu cau

- Toolchain xPack RISC-V GCC (xem [`../toolchain/README.md`](../toolchain/README.md)), version trong `../toolchain/VERSION`.
- Python 3.

## Build tu toolchain (PowerShell)

Chay trong thu muc `design/sw/firm`.

### 1. Dat toolchain vao PATH

```powershell
# Neu da cai bang setup.ps1 trong ..\toolchain:
. ..\toolchain\env.ps1

# Hoac tro thang toi thu muc bin da giai nen:
$env:PATH = "D:\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin;$env:PATH"

riscv-none-elf-gcc --version
```

### 2. Bien dich firmware

```powershell
$CFLAGS = "-march=rv32i","-mabi=ilp32","-mno-relax","-Os","-ffreestanding","-nostdlib","-nostartfiles","-fno-builtin","-Wall","-T","link.ld"

riscv-none-elf-gcc @CFLAGS -o fw.elf start.S main.c
riscv-none-elf-size fw.elf
```

Hai ban dung de tao kich ban tan cong (tuy chon):

```powershell
riscv-none-elf-gcc @CFLAGS -DATTACK_WCODE -o fw_wcode.elf start.S main.c   # sw vao vung CODE
riscv-none-elf-gcc @CFLAGS -DATTACK_JUMP  -o fw_jump.elf  start.S main.c   # nhay vao data RAM
```

### 3. Ky firmware

```powershell
New-Item -ItemType Directory -Force active | Out-Null

python auth_signer.py sign --elf fw.elf `
  --out-code active\code.hex --out-tag active\tag.hex --out-data active\data.hex `
  --g 4 --t 128 --key 000102030405060708090A0B0C0D0E0F `
  --program-id 1 --image-id 1
```

Tham so ky (`g`, `t`, `key`, `program-id`, `image-id`) phai trung voi `tangnano20k_top.v` / `auth_soc_top.v`.

Dinh dang cho Gowin `$readmemh`: bo cac dong comment `//` cua signer va dem du kich thuoc
(code/tag 2048 word, data 1024 word, moi dong 1 word 32 bit hex).

### 4. Kich ban test

Kich ban (code bi lat bit, tag sai, doi block, sai key, image cu, ...) tu tao bang cach sua hoac ky lai
file hex, roi dat 3 file `code.hex`, `tag.hex`, `data.hex` vao `active\`.
`tangnano20k_top.v` luon nap 3 file nay tu `design/sw/firm/active/` (duong dan tuong doi `../../sw/firm/active/`
tinh tu `design/hw/rtl/`).

### 5. Nap len FPGA (Gowin)

Process -> **Clean**, roi Synthesize -> Place & Route -> Program.
Phai Clean sau moi lan doi hex de `$readmemh` doc lai file moi.

## Tai lap ket qua

Moi lan chay regression, ghi kem: commit hash cua repo, noi dung `../toolchain/VERSION`
va tham so ky (`g`, `t`, `key`, `program-id`, `image-id`).
