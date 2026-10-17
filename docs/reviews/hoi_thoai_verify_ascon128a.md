# Hội thoại: Verify thiết kế Ascon-128a (D:\JOURNAL MTD)

Ngày: 2026-10-06 (giờ Bangkok, UTC+7)

---

## 1. Người dùng (13:35)

> "D:\JOURNAL MTD" kiem tra trong folder nay verify lai thiet ke ascon 128a

## 2. Claude: các bước đã làm

**Trả lời mở đầu:** Mình sẽ mở folder `D:\JOURNAL MTD`, tìm thiết kế Ascon-128a và chạy mô phỏng đối chiếu với KAT chuẩn.

### 2.1 Truy cập folder và đọc file
- Xin quyền truy cập `D:\JOURNAL MTD`, đã được cấp.
- Trong folder có 16 file RTL: `ascon_ad_absorb`, `ascon_ad_buffer_padding`, `ascon_add_constant`, `ascon_controller`, `ascon_final_pre`, `ascon_initial_state`, `ascon_key_nonce_reg`, `ascon_p8`, `ascon_p12`, `ascon_post_init`, `ascon_round`, `ascon_sbox`, `ascon_state_mux`, `ascon_state_reg`, `ascon_tag_output`, `ascon_xor_diffusion` (.v). Ngoài ra còn các file `.bak`, thư mục `tb/` (`tb_mac.v`, `gen.py`, `ascon_v12.py`, `vec.txt`) và các paper PDF.
- Rà theo spec v1.2:
  - IV `0x80800C0800000000`
  - Bảng S-box: 32/32 entry đúng
  - Round constant của p12 (`F0…4B`) và p8 (`B4…4B`)
  - Góc quay của linear layer (19/28, 61/39, 1/6, 10/17, 7/41)
  - XOR key sau init vào S3/S4; trước finalization vào S2/S3
  - Domain separation S4 ^= 1
  - Padding 0x80, có block padding riêng khi L chia hết cho 16
  - Tag = {S3^K0, S4^K1}

  Tất cả đều khớp.

### 2.2 Golden reference độc lập
- Lấy KAT chính thức `LWC_AEAD_KAT_128_128.txt` từ github.com/ascon/ascon-c, tag v1.2.8, thư mục `crypto_aead/ascon128av12`.
- Viết model độc lập `ascon_ref.py` (S-box dạng bitsliced, không tra bảng). Kết quả khớp **1089/1089** vector KAT.
- `tb/ascon_v12.py` của bạn khớp 1089/1089 KAT. 9 vector trong `vec.txt` đều đúng.

### 2.3 Chạy lại `tb_mac.v` gốc (Icarus Verilog 12)
- 9/9 PASS (L = 0, 1, 5, 15, 16, 17, 20, 32, 40).
- Lưu ý: TB này **không instantiate `ascon_controller` và `ascon_tag_output`**. TB tự điều khiển datapath và tự tính tag.

### 2.4 Unit test (`tb_unit.v`)
| Khối | Vector | Kết quả |
|---|---|---|
| S-box | 32 input × 64 lane bit | 0 lỗi |
| Linear layer | 504 | 0 lỗi |
| Round (đủ 12 hằng số) | 504 | 0 lỗi |
| p8 | 1004 (có start giả khi đang busy) | 0 lỗi, latency 9 clk |
| p12 | 1004 | 0 lỗi, latency 13 clk |

### 2.5 Test tích hợp controller + datapath
- Folder chưa có module top. Mình viết `ascon_mac_top.v`, nối dây giống `tb_mac.v`, có thêm controller và tag_output.
- `tb_ascon_mac_top.v` chạy 33 vector KAT chính thức (PT rỗng, AD 0–32 B), 9 vector `vec.txt` và 3000 vector ngẫu nhiên (AD 0–256 B, key/nonce ngẫu nhiên).
  - Kích thích: `ad_valid` stall ngẫu nhiên; dữ liệu rác trên bus và trên các byte lane không dùng; đổi key/nonce ngay sau `start`; 64 lần reset giữa chừng; 226 vector gửi terminator 0 byte; có watchdog.
  - Kiểm tra: tag, số beat AD được nhận, latency, X ở output, tag không đổi ngoài chu kỳ DONE.
- Kết quả: **3042/3042 PASS**, latency đúng 42/42, FSM transition coverage **20/20**.
- Latency: `33 + 12·ceil(L/16)`, cộng thêm 11 nếu L > 0 và L chia hết cho 16. Ví dụ L = 0 → 33, L = 1–15 → 45, L = 16 → 56, L = 32 → 68.
- Probe giao tiếp:
  - Xung `start` 1 chu kỳ trùng DONE bị **DROPPED**.
  - AD rỗng gửi bằng beat 0 byte cho tag = `6c06810b…`, trong khi tag chuẩn là `6c89186e…`.

### 2.6 Mutation test
Cài 10 lỗi cố ý: bỏ domain separation, bỏ PAD_ONLY, sai byte padding, sai 1 round constant, đảo key trong tag, bỏ XOR key sau init, bỏ qua `ad_empty`, sai 1 entry S-box, sai 1 góc quay, key không được chốt. TB bắt được **10/10**.

### 2.7 Lint / synth
- Verilator `-Wall`: chỉ có cảnh báo cosmetic.
- Yosys: 0 latch, 1495 FF, ~14.8k cell generic.
  - Mỗi `ascon_round` ~3461 cell.
  - p8 4414 cell, p12 4387 cell (chiếm khoảng 59% tổng cell).
  - Controller 156 cell.

### 2.8 So với NIST SP 800-232
KAT Ascon-AEAD128 (main branch của ascon-c) với key 00..0F, nonce 10..1F, AD và PT rỗng ra `4F9C2782…`. Model v1.2 ra `6DB880CA…`. Hai bản không tương thích bit (khác IV, byte order little-endian, padding 0x01, bit DSEP).

### 2.9 Giao file
16 file được ghi vào `D:\JOURNAL MTD\verify\` (không sửa file gốc):
- `README_verify.md`, `ascon_mac_top.v`, `tb_unit.v`, `tb_ascon_mac_top.v`, `files.f`
- `ascon_ref.py`, `gen_vectors.py`, `LWC_AEAD_KAT_128_128.txt`
- Các file vector `*_vec.txt`
- Log `sim_icarus_unit.log` và `sim_icarus_top.log`

## 3. Claude: câu trả lời cuối

**Kết luận: thiết kế Ascon-128a tính tag đúng chuẩn v1.2. Mọi test đều PASS, phần mật mã không có lỗi nào.** Mình không sửa file gốc nào; mô phỏng chạy bằng Icarus, chưa chạy lại trên ModelSim.

- **So với chuẩn:** đối chiếu với bộ KAT chính thức (1089 vector) và một model Python mình viết riêng. File `tb/ascon_v12.py` của bạn cũng khớp đủ 1089/1089.
- **`tb_mac.v` gốc:** 9/9 PASS.
- **Test từng khối:** S-box thử hết 32 đầu vào trên cả 64 vị trí bit; linear layer, round, p8 và p12 thử với state ngẫu nhiên. Không sai vector nào.
- **Ghép controller với datapath:** 3042/3042 PASS. FSM đi qua đủ 20/20 chuyển trạng thái.
- **Kiểm tra testbench:** cố ý cài 10 lỗi vào RTL, testbench bắt được cả 10.
- **Lint/synth:** không có latch, tổng 1495 FF.
- **Latency:** 33 + 12·⌈L/16⌉ chu kỳ, cộng thêm 11 nếu L chia hết cho 16.

**Cần lưu ý:**
1. `tb_mac.v` không instantiate `ascon_controller` và `ascon_tag_output`, nên controller trước giờ chưa được verify. Folder cũng chưa có top. Đã thêm `ascon_mac_top.v`, dùng làm top Quartus được.
2. AD rỗng bắt buộc phải báo bằng `ad_empty=1`. Gửi 1 beat 0 byte thay vào đó thì tag ra sai chuẩn.
3. Xung `start` dài 1 chu kỳ trùng đúng chu kỳ `done` sẽ bị mất: ở DONE `busy=0` nhưng `start` không được nhận. Cách sửa: cho DONE nhận `start`, hoặc giữ `busy=1` trong DONE.
4. Khi `nbytes>16`, hoặc beat chưa đủ 16 byte mà `last=0`, tag ra sai mà không có tín hiệu báo lỗi.
5. Đây là Ascon-128a v1.2, **không tương thích bit** với NIST SP 800-232 (Ascon-AEAD128). Trong journal nên ghi rõ "Ascon-128a v1.2".
6. Về diện tích: p8 và p12 mỗi khối có round function và 320 FF riêng, nên thừa 640 FF (43%) và khoảng 30% cell. Có thể gộp thành một khối vì p8 chính là p12 bắt đầu từ round 4.
7. Cosmetic:
   - `ascon_p12.v`: `round_index <= 3'b000` gán cho thanh ghi 4 bit; comment "round thu 8" là copy từ p8.
   - `ascon_initial_state.v`: có `reg IV` khai báo mà không dùng.
   - Một số file thiếu newline ở cuối.
   - Còn sót các file `.bak`.

**Chạy lại trong ModelSim** (mở cmd tại `D:\JOURNAL MTD\verify`):
```
vlib work
vlog -f files.f
vsim -c -do "run -all; quit -f" tb_unit
vsim -c -do "run -all; quit -f" tb_ascon_mac_top
```
Kết quả mong đợi: `UNIT errors = 0`, `FSM transition coverage: 20/20`, `RESULT: PASS`.

Sources:
- [ascon/ascon-c tag v1.2.8: KAT chính thức Ascon-128a v1.2](https://github.com/ascon/ascon-c/tree/v1.2.8/crypto_aead/ascon128av12)
- [ascon/ascon-c main: Ascon-AEAD128 (SP 800-232)](https://github.com/ascon/ascon-c/tree/main/crypto_aead/asconaead128)

---

## 4. Người dùng (14:18)

> xuat file md toan bo cuoc tro chuyen nay

## 5. Claude

Xuất file này: `hoi_thoai_verify_ascon128a.md`.
