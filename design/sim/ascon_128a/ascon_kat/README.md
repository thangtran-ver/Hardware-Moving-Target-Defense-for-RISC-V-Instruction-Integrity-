# KAT test Ascon-128a cho ascon_top

- `LWC_AEAD_KAT_128_128_ascon128a.txt` : KAT goc (NIST LWC, ascon-c, ascon128av12), 1089 vector.
- `gen_vectors.py` : loc cac vector PT rong (33 vector, AD 0..32 byte) -> `kat_vectors.txt`.
  Loi RTL chi xac thuc AD (khong ma hoa PT) nen CT cua vector PT rong chinh la tag 16 byte.
- `tb_ascon_kat.v` : testbench, nap Key/Nonce/AD, cho `done`, so `tag_out` voi tag trong KAT.
- `run_modelsim.bat` / `run_modelsim.do` : tu dong sinh vector -> bien dich -> mo phong -> in PASS/FAIL.
  `run_modelsim.bat gui` mo GUI voi waveform.
- RTL duoc lay tu `design/hw/rtl/ascon` cua repo nay. `run_verilator.sh` co the doi duong dan qua `RTL_DIR`.

Ket qua mong doi: 33 vector KAT dung, 0 loi va `KET QUA CHUNG  : PASS`.
