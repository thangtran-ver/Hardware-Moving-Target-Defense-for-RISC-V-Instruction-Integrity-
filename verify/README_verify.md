# Verify Ascon-128a (v1.2): kết quả

Ngày chạy: 2026-10-06. Mô phỏng bằng Icarus Verilog 12, lint bằng Verilator 5.020, synth generic bằng Yosys 0.33.
RTL được verify: 16 file `ascon_*.v` ở thư mục gốc tại thời điểm chạy (nay chuyển vào `ascon/`), không sửa file nào.

## Kết luận

RTL tính tag **đúng chuẩn Ascon-128a v1.2** (chế độ chỉ có AD, plaintext rỗng). Mọi test đều PASS, kể cả khi chạy qua `ascon_controller`.

| Test | Phạm vi | Kết quả |
|---|---|---|
| `tb/tb_mac.v` (bản gốc) | 9 vector, TB tự điều khiển datapath | 9/9 PASS |
| `tb_unit.v` | S-box: 32 input × 64 lane bit; linear layer: 504; round (đủ 12 hằng số): 504; p8: 1004; p12: 1004 | 0 lỗi. Latency p8 = 9 clk, p12 = 13 clk |
| `tb_ascon_mac_top.v` | controller + datapath: 33 vector KAT chính thức + 9 vector `vec.txt` + 3000 vector ngẫu nhiên (AD 0–256 B, key/nonce ngẫu nhiên) | 3042/3042 PASS, FSM transition coverage 20/20 |
| Mutation test | cố ý cài 10 lỗi vào RTL: bỏ domain separation, bỏ PAD_ONLY, sai byte padding, sai 1 round constant, sai tag, bỏ XOR key sau init, bỏ qua `ad_empty`, sai 1 entry S-box, sai 1 góc quay, key không được chốt | TB bắt được 10/10 lỗi |
| Lint Verilator `-Wall` | top = `ascon_mac_top` | chỉ có cảnh báo cosmetic (mục 7) |
| Yosys `synth` | top = `ascon_mac_top` | 0 latch, 1495 FF, ~14.8k cell generic |

Những gì `tb_ascon_mac_top.v` có kiểm tra: tag; số beat AD được nhận; latency; X ở output; tag không đổi ngoài chu kỳ DONE; `ad_valid` bị stall ngẫu nhiên; dữ liệu rác trên bus khi rảnh và trên các byte lane không dùng; đổi key/nonce ngay sau `start`; 64 lần reset giữa chừng; gửi AD có độ dài bội 16 dưới dạng các beat đầy + 1 beat terminator 0 byte (226 vector); có watchdog để báo FAIL nếu FSM bị treo.

**Latency** (tính từ cạnh clock lấy mẫu `start` đến chu kỳ DONE): `33 + 12·ceil(L/16)`, cộng thêm 11 nếu L > 0 và L chia hết cho 16 (lúc đó phải có thêm 1 block padding).
Ví dụ: L = 0 → 33; L = 1–15 → 45; L = 16 → 56; L = 17–31 → 57; L = 32 → 68 chu kỳ.

## Golden reference (độc lập với RTL)

- Dùng file KAT chính thức `LWC_AEAD_KAT_128_128.txt` lấy từ github.com/ascon/ascon-c, tag v1.2.8, thư mục `crypto_aead/ascon128av12`.
- `ascon_ref.py` là model tự viết lại từ spec. S-box viết theo công thức bitsliced, không tra bảng như RTL. Model khớp 1089/1089 vector KAT.
- `tb/ascon_v12.py` (bản đang dùng) cũng khớp 1089/1089 vector KAT. 9 vector trong `vec.txt` đều đúng.

## Các vấn đề phát hiện (không có lỗi nào ở phần mật mã)

1. **Testbench cũ chưa cover controller.** `tb/tb_mac.v` không instantiate `ascon_controller` và `ascon_tag_output`: TB tự điều khiển datapath và tự tính tag. Folder cũng chưa có module top. Vì vậy mình thêm `verify/ascon_mac_top.v`, nối dây giống `tb_mac.v`. File này dùng làm top cho Quartus được luôn.
2. **AD rỗng bắt buộc phải báo bằng `ad_empty=1`.** Nếu gửi 1 beat 0 byte (`last=1`) với `ad_empty=0`, tag ra sai chuẩn: `6c06810b…` thay vì `6c89186e…` (key = nonce = 0). Beat 0 byte chỉ hợp lệ khi làm terminator sau ít nhất 1 beat đầy 16 byte.
3. **Xung `start` 1 chu kỳ trùng với `done` sẽ bị mất.** Ở trạng thái DONE, `busy=0` nhưng `start` chỉ được lấy mẫu ở IDLE. Master đồng bộ (start được đăng ký sau khi thấy done) thì không bị ảnh hưởng. Cách sửa: cho DONE nhận `start` (giống IDLE, và chốt cả `ad_empty_q`), hoặc giữ `busy=1` trong DONE.
4. **Không kiểm tra input sai.** Nếu `nbytes > 16`, hoặc beat < 16 byte mà `last=0`, tag ra sai mà không có tín hiệu báo lỗi. Cần ghi rõ ràng buộc này trong spec giao tiếp, hoặc thêm cờ báo lỗi.
5. **Chuẩn.** Thiết kế là Ascon-128a **v1.2**. Ascon-AEAD128 trong NIST SP 800-232 **không tương thích bit** với v1.2: khác IV, dùng thứ tự byte little-endian, khác byte padding (0x01) và vị trí bit domain separation. Ví dụ với key 00..0F, nonce 10..1F, AD và PT rỗng: v1.2 cho `6DB880CA…`, KAT SP 800-232 là `4F9C2782…`. Trong journal nên ghi rõ "Ascon-128a v1.2", đừng ghi "chuẩn NIST SP 800-232".
6. **Diện tích (đáng chú ý nếu journal báo cáo area).** `ascon_p8` và `ascon_p12` mỗi khối có 1 `ascon_round` riêng và 320 FF state riêng, ngoài ra còn `STAGE` 320 FF. Tổng cộng thừa 640 FF (43% số FF) và thừa 1 round function (mỗi round ~3.5k cell, p8 + p12 chiếm khoảng 59% cell). Có thể gộp thành 1 khối permutation: p^8 chính là p^12 bắt đầu từ round 4. Khối này dùng luôn thanh ghi state chung, tiết kiệm khoảng 640 FF và khoảng 30% cell (số Yosys generic, chỉ để so sánh tương đối).
7. **Cosmetic.**
   - `ascon_p12.v`: `round_index <= 3'b000` gán cho thanh ghi 4 bit; comment "round thu 8" là copy từ p8.
   - `ascon_initial_state.v`: có `reg IV` khai báo mà không dùng.
   - Một số file thiếu newline ở cuối.
   - Các file `.bak` nay được lưu riêng trong `archive/backups/`.

## Chạy lại trong ModelSim

Mở terminal tại thư mục `verify/` của project rồi gõ:

```
vlib work
vlog -f files.f
vsim -c -do "run -all; quit -f" tb_unit
vsim -c -do "run -all; quit -f" tb_ascon_mac_top
```

Kết quả mong đợi: `UNIT errors = 0`, `FSM transition coverage: 20/20`, `RESULT: PASS`.
Các file vector đã có sẵn. Nếu muốn sinh lại: `python gen_vectors.py` (cần Python 3.9 trở lên).

## Các file trong folder

| File | Nội dung |
|---|---|
| `ascon_mac_top.v` | top nối controller với datapath |
| `tb_unit.v` | unit test cho S-box, linear layer, round, p8, p12 |
| `tb_ascon_mac_top.v` | test toàn hệ thống |
| `files.f` | danh sách file để `vlog -f` |
| `ascon_ref.py` | golden model độc lập |
| `gen_vectors.py` | sinh lại toàn bộ file vector |
| `LWC_AEAD_KAT_128_128.txt` | KAT chính thức của Ascon-128a v1.2 |
| `top_vec.txt`, `sbox_vec.txt`, `lin_vec.txt`, `round_vec.txt`, `p8_vec.txt`, `p12_vec.txt` | các file vector |
| `sim_icarus_unit.log`, `sim_icarus_top.log` | log lịch sử đã chuyển vào `archive/logs/verify/` |
