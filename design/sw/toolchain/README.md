# Toolchain: xPack RISC-V GCC

Cross-compiler dung de build firmware (`design/sw/firm/`) cho core RISC-V (PicoRV32) trong du an.

| Muc | Gia tri |
| --- | --- |
| Toolchain | xPack GNU RISC-V Embedded GCC (`riscv-none-elf-gcc`) |
| Version (khoa baseline) | **15.2.0-1** (xem file [`VERSION`](VERSION)) |
| Nen tang | Windows x64 (`win32-x64`) |
| Nguon | https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases |

> Binary toolchain **khong** duoc commit len repo (nang, da co ban phat hanh chinh thuc).
> Repo chi luu version va script cai dat de ai cung dung dung mot ban.

## Cai dat nhanh

```powershell
cd design\sw\toolchain
powershell -ExecutionPolicy Bypass -File setup.ps1
. .\env.ps1          # them vao PATH cua phien hien tai
riscv-none-elf-gcc --version
```

`setup.ps1` tai file `xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64.zip`, kiem tra SHA-256
(neu co), giai nen vao thu muc nay, roi in version de xac nhan.

## Cai thu cong

1. Tai `xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64.zip` tu trang Releases o tren.
2. Giai nen vao `design/sw/toolchain/` (ra thu muc `xpack-riscv-none-elf-gcc-15.2.0-1/`).
3. Them `...\xpack-riscv-none-elf-gcc-15.2.0-1\bin` vao `PATH`.

Neu da giai nen san o noi khac (vd `D:\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64`),
chi can them thu muc `bin` cua no vao `PATH`, khong can chep vao repo.

## Kiem tra

```powershell
riscv-none-elf-gcc --version   # ky vong: ... 15.2.0 ...
```

## Doi version

1. Sua `VERSION` (vd `xpack-riscv-none-elf-gcc 15.3.0-1`).
2. Chay lai `setup.ps1 -Force`.
3. Chay lai regression va ghi version moi vao ket qua / bao cao.

## Luu y ve tai lap (reproducibility)

- Moi ket qua build/regression can ghi kem: commit hash cua repo + noi dung `VERSION`.
- Khong tron lan nhieu version toolchain khi so sanh baseline static va lazy dynamic.
- Neu sau nay dung Docker de khoa moi truong, giu `VERSION` o day lam nguon su that duy nhat.

## Cau truc thu muc

```
toolchain/
├── README.md     # tai lieu nay
├── VERSION       # version khoa baseline
├── setup.ps1     # tai + giai nen + kiem tra
├── env.ps1       # them toolchain vao PATH
├── .gitignore    # bo qua binary xpack-*/ va *.zip
└── xpack-*/      # (sinh ra sau khi cai, KHONG commit)
```
