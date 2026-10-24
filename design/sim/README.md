# Mô phỏng kiểm thử `ascon_top` (Ascon-128a, tag trên AD)

Folder chứa testbench cho lõi Ascon trong `../rtl/ascon`:

| File | Mục đích |
|---|---|
| `tb_ascon_kat.v` | Tính tag và so với file KAT chính thức `LWC_AEAD_KAT_128_128.txt` |
| `tb_ascon_functional.v` | Kiểm tra hoạt động: reset, handshake AD, start, done/busy/tag_out (TC13–TC24) |
| `ascon_sim.f` | Danh sách file RTL (đường dẫn tương đối, chạy từ thư mục `sim/`) |
| `LWC_AEAD_KAT_128_128.txt` | KAT gốc, bản `v1.2.8`: <https://raw.githubusercontent.com/ascon/ascon-c/v1.2.8/crypto_aead/ascon128av12/LWC_AEAD_KAT_128_128.txt> |


ModelSim/Questa (thay `tb_ascon_kat` bằng `tb_ascon_functional` cho testbench còn lại; 
```
vlog ../rtl/ascon/*.v tb_ascon_kat.v
vsim -c work.tb_ascon_kat -do "run -all; quit"
```

Tuỳ chọn: `+DUMP` (xuất file VCD), `+KAT_FILE=<đường dẫn>` (chỉ `tb_ascon_kat`), `+SEED=<n>` (chỉ `tb_ascon_functional`, đổi dữ liệu ngẫu nhiên).

Mỗi testbench kết thúc bằng một dòng `>>> ... PASSED <<<` hoặc `>>> ... FAILED <<<`.

## Giao diện và quy ước

- Clock 100 MHz. Testbench lái tín hiệu và lấy mẫu ở cạnh xuống, DUT chốt ở cạnh lên.
- Byte đầu tiên của AD nằm ở `ad_data[127:120]`. Mỗi block có tối đa 16 byte, `ad_nbytes` là số byte hợp lệ và `ad_last=1` ở block cuối.
- `ad_empty=1` nghĩa là không có AD, lõi bỏ qua pha hấp thụ AD.
- Handshake AD xảy ra ở cạnh clock có đồng thời `ad_valid=1` và `ad_ready=1`.
- `ascon_top` chỉ tính tag cho plaintext rỗng, nên tag chính là CT 16 byte của vector KAT có `PT = ` rỗng.

---

## 1. So sánh với file KAT (`tb_ascon_kat.v`)

Testbench đọc trực tiếp file `.txt` gốc, không qua bước chuyển đổi. Với mỗi vector nó nạp `Key`, `Nonce`, `AD` vào DUT, chờ `done`, rồi so `tag_out` với `CT`.

**Phạm vi:** file có 1089 vector (PT dài 0–32 byte × AD dài 0–32 byte). RTL hiện tại không xử lý plaintext, nên chỉ các vector có `PT` rỗng (Count 1–33, AD dài 0–32 byte) được chạy. 1056 vector còn lại có PT khác rỗng bị bỏ qua và được đếm riêng trong báo cáo.

**Kết quả:** 33 vector chạy, 33 PASS, 0 FAIL. Toàn bộ Key và Nonce của các vector này là `000102030405060708090A0B0C0D0E0F`, AD là chuỗi byte `00 01 02 ...`.

| Count | AD (byte) | Số block AD | Tag kỳ vọng (CT trong file KAT) | Tag RTL | Kết quả |
|---:|---:|---:|---|---|:---:|
| 1 | 0 | 0 | `7A834E6F09210957067B10FD831F0078` | `7A834E6F09210957067B10FD831F0078` | PASS |
| 2 | 1 | 1 | `AF3031B07B129EC84153373DDCABA528` | `AF3031B07B129EC84153373DDCABA528` | PASS |
| 3 | 2 | 1 | `B486742EB408CEFFF2F1290C6C8B1F1F` | `B486742EB408CEFFF2F1290C6C8B1F1F` | PASS |
| 4 | 3 | 1 | `8C8978E9940FC7A3D8F51219FDA22405` | `8C8978E9940FC7A3D8F51219FDA22405` | PASS |
| 5 | 4 | 1 | `3A82BC770598764AC1C6F025CD3FEE57` | `3A82BC770598764AC1C6F025CD3FEE57` | PASS |
| 6 | 5 | 1 | `4F860D44CAF4F716D6D12D56C0B1AB9E` | `4F860D44CAF4F716D6D12D56C0B1AB9E` | PASS |
| 7 | 6 | 1 | `2E400ACF9F57C035269C2535F74DD13D` | `2E400ACF9F57C035269C2535F74DD13D` | PASS |
| 8 | 7 | 1 | `C341229D53B2F0759C55EE80DA4A77C2` | `C341229D53B2F0759C55EE80DA4A77C2` | PASS |
| 9 | 8 | 1 | `D60E199FFD3F9B694713DABC6D89F46F` | `D60E199FFD3F9B694713DABC6D89F46F` | PASS |
| 10 | 9 | 1 | `8273DDD267B984A4D0ECFD98C548F63A` | `8273DDD267B984A4D0ECFD98C548F63A` | PASS |
| 11 | 10 | 1 | `16BA49274C773EA15ADB1A5A3BB4EBD6` | `16BA49274C773EA15ADB1A5A3BB4EBD6` | PASS |
| 12 | 11 | 1 | `794BC2A55833A753795EB56755F17C87` | `794BC2A55833A753795EB56755F17C87` | PASS |
| 13 | 12 | 1 | `A5339E4280878EC1916A32375B8599B1` | `A5339E4280878EC1916A32375B8599B1` | PASS |
| 14 | 13 | 1 | `CC13A2922A77F0461652BBADDBA24E11` | `CC13A2922A77F0461652BBADDBA24E11` | PASS |
| 15 | 14 | 1 | `5DB649C3330864D2EF77E13D0F6F2356` | `5DB649C3330864D2EF77E13D0F6F2356` | PASS |
| 16 | 15 | 1 | `E536428B9B7B4035AE9794B3F69BEAAE` | `E536428B9B7B4035AE9794B3F69BEAAE` | PASS |
| 17 | 16 | 1 | `56C15EB024DE91CA0165362A49B31EBD` | `56C15EB024DE91CA0165362A49B31EBD` | PASS |
| 18 | 17 | 2 | `917D530F34157158CF8CA49D01AF44F0` | `917D530F34157158CF8CA49D01AF44F0` | PASS |
| 19 | 18 | 2 | `7FFB39D30F8783FE3F85D9A98014AA48` | `7FFB39D30F8783FE3F85D9A98014AA48` | PASS |
| 20 | 19 | 2 | `0BF96195398A3EA8B670184FE2424EF7` | `0BF96195398A3EA8B670184FE2424EF7` | PASS |
| 21 | 20 | 2 | `4C2685CF770369E8A601E7D884BFB681` | `4C2685CF770369E8A601E7D884BFB681` | PASS |
| 22 | 21 | 2 | `B399034306E26E73E8B9C160FF5281B3` | `B399034306E26E73E8B9C160FF5281B3` | PASS |
| 23 | 22 | 2 | `3813A2CB0F563707EDCB8896C05703F0` | `3813A2CB0F563707EDCB8896C05703F0` | PASS |
| 24 | 23 | 2 | `251BB9E44F8FF1C07F226A878D5FBE87` | `251BB9E44F8FF1C07F226A878D5FBE87` | PASS |
| 25 | 24 | 2 | `786E304275C5633D3AFF3F2BB560458C` | `786E304275C5633D3AFF3F2BB560458C` | PASS |
| 26 | 25 | 2 | `5D32E8D94D4322B7C93DEF811E223FBA` | `5D32E8D94D4322B7C93DEF811E223FBA` | PASS |
| 27 | 26 | 2 | `6AE7517692D249910555956DA9F062B3` | `6AE7517692D249910555956DA9F062B3` | PASS |
| 28 | 27 | 2 | `F10D5B4E1B34667BE8675CB2BE6E55E1` | `F10D5B4E1B34667BE8675CB2BE6E55E1` | PASS |
| 29 | 28 | 2 | `60C2EF5D2E49D77F9FFAF073C370720B` | `60C2EF5D2E49D77F9FFAF073C370720B` | PASS |
| 30 | 29 | 2 | `72147084CF09A123ECE4BD77FB3BA74F` | `72147084CF09A123ECE4BD77FB3BA74F` | PASS |
| 31 | 30 | 2 | `6D2C65466BD515C494F6FD0054AF2D3D` | `6D2C65466BD515C494F6FD0054AF2D3D` | PASS |
| 32 | 31 | 2 | `89703C55CB5ED201153E0D53E788B581` | `89703C55CB5ED201153E0D53E788B581` | PASS |
| 33 | 32 | 2 | `2FDEE642B4C31C2F205DCC8B3DAD4542` | `2FDEE642B4C31C2F205DCC8B3DAD4542` | PASS |

Các trường hợp biên đã được phủ trong bảng trên:

- Count 1: AD rỗng (`ad_empty=1`), đi thẳng từ khởi tạo sang finalization.
- Count 2–16: AD ngắn hơn một block, cần padding `0x80`.
- Count 17: AD đúng 16 byte, lõi phải chèn thêm một block chỉ có padding (`PAD_ONLY`).
- Count 18–32: AD hơn một block, block cuối thiếu byte.
- Count 33: AD đúng 32 byte, hai block đầy và một block chỉ có padding.

---

## 2. Kiểm tra hoạt động (`tb_ascon_functional.v`)

Tag mong đợi được tính bằng mô hình tham chiếu Ascon-128a viết sẵn trong testbench (hàm `ref_tag`). Nhóm SANITY chứng minh mô hình này khớp KAT, nên các test sau có thể dùng Key, Nonce và AD ngẫu nhiên, AD dài tới 64 byte.

**Kiểm tra toàn cục** chạy ở mọi chu kỳ trong suốt mô phỏng:

- `busy` và `done` không cùng bằng 1.
- `ad_ready=1` chỉ khi `busy=1`.
- `ad_we` trong lõi luôn bằng `ad_valid & ad_ready`, tức dữ liệu chỉ được chốt ở cạnh có cả hai tín hiệu bằng 1.
- `done` không kéo dài quá 1 chu kỳ.
- Các ngõ ra không bị X/Z sau reset.
- Khi `ad_valid=0`, bus `ad_data`, `ad_nbytes`, `ad_last` được lái bằng giá trị ngẫu nhiên để chứng minh DUT bỏ qua chúng.

### Kết quả theo test case

| Mã | Kịch bản | Cách kiểm tra | Kết quả mong đợi | Kết quả |
|---|---|---|---|:---:|
| SANITY | 5 vector KAT (Count 1, 2, 17, 18, 33) | So tag DUT và tag của mô hình tham chiếu với giá trị KAT hard-code | Cả hai khớp KAT | PASS |
| TC13 | Reset lúc khởi động | Giữ `rst_n=0` từ đầu, rồi chạy một giao dịch và reset lại. Kiểm tra `busy`, `done`, `ad_ready`, `tag_out`, FSM ở IDLE, thanh ghi state, key/nonce, P8/P12 | `busy=0`, `done=0`, tag và thanh ghi về 0, lõi không tự chạy sau khi nhả reset | PASS |
| TC14 | Reset giữa giao dịch | Hạ `rst_n` (bất đồng bộ, giữa chu kỳ) ở 4 điểm: trong P12 khởi tạo, khi chờ AD, trong P8, trong P12 cuối. Sau đó chạy giao dịch mới | Giao dịch cũ bị huỷ, mọi thứ về 0 ngay sau khi hạ `rst_n`. Giao dịch sau reset cho tag đúng | PASS |
| TC15 | Trì hoãn gửi AD nhiều chu kỳ | Sau `start`, giữ `ad_valid=0` 300 chu kỳ, theo dõi FSM, `ad_ready`, thanh ghi state, `tag_out`. Sau đó gửi AD | Đứng yên ở `WAIT_AD`, `ad_ready=1`, không đổi dữ liệu. Tag đúng sau khi gửi | PASS |
| TC16 | Chèn khoảng nghỉ ngẫu nhiên giữa các block AD | AD dài 33, 48, 50, 64 byte. Chạy không nghỉ và chạy nghỉ ngẫu nhiên 0–25 chu kỳ giữa các block | Tag hai lần giống nhau và đúng với mô hình tham chiếu, `ad_ready` không rơi trong lúc chờ | PASS |
| TC17 | `ad_valid=1` trước `ad_ready=1`, dữ liệu ổn định | AD dài 5, 16, 40, 47 byte. Đưa `ad_valid` lên ngay sau `start`, giữ dữ liệu cố định đến khi nhận | Chỉ nhận ở cạnh có cả hai bằng 1, số handshake bằng số block, tag đúng | PASS |
| TC18 | Giữ `ad_valid=1`, chuyển block sau mỗi handshake | AD dài 17, 32, 48, 61 byte. `ad_valid` không hạ giữa các block, dữ liệu đổi ngay sau handshake | Mỗi block nhận đúng một lần (đếm handshake), tag đúng | PASS |
| TC19 | Phát `start` khi lõi đang bận | AD dài 0, 25, 48 byte. Mỗi chu kỳ trong lúc bận, phát `start=1` kèm key, nonce, `ad_empty` ngẫu nhiên khác | Không ghi đè key/nonce (đọc trực tiếp thanh ghi mỗi chu kỳ), không khởi động lại, số handshake đúng, tag đúng, không có giao dịch thừa | PASS |
| TC20 | Đổi `key_d`, `nonce_d`, `ad_empty` sau khi đã nhận `start` | AD dài 0, 9, 16, 35 byte. Sau `start`, ba tín hiệu này đổi ngẫu nhiên mỗi chu kỳ đến hết giao dịch | Giao dịch dùng giá trị đã chốt, tag đúng | PASS |
| TC21 | Giao dịch mới bắt đầu ngay chu kỳ `done=1` | Chuỗi 6 giao dịch (AD dài 20, 0, 33, 16, 7, 48 byte), mỗi giao dịch sau phát `start` đúng chu kỳ `done=1` của giao dịch trước, không reset | `tag_out` hợp lệ tại chu kỳ `done`, giao dịch mới nhận key/nonce mới và cho tag đúng | PASS |
| TC22 | Chạy liên tiếp nhiều giao dịch khác nhau | 24 giao dịch, AD dài 0–64 byte (xen kẽ rỗng, 1, 15, 16, 17, 32, 48, 64...), chế độ gửi AD ngẫu nhiên, một phần chạy sát nhau. Cuối cùng lặp lại đầu vào của giao dịch thứ 4 | Mọi tag đúng, lặp lại cùng đầu vào cho cùng tag (không mang dữ liệu hay trạng thái cũ) | PASS |
| TC23 | Giữ `start=1` xuyên qua lúc hoàn thành | AD rỗng, `start=1` giữ từ đầu. Sau `done` lần 1 kiểm tra trạng thái kế tiếp, rồi hạ `start` | Theo RTL hiện tại, lõi nhận giao dịch mới tại `DONE` (vào `LOAD_INIT`). Có đúng 2 xung `done`, cả hai tag đúng, độ trễ hai giao dịch bằng nhau (`start` giữ 1 không làm khởi động lại giữa chừng), lõi về IDLE sau khi nhả `start` | PASS |
| TC24 | Quan sát `done`, `busy`, `tag_out` | Giao dịch 1 rồi nghỉ 40 chu kỳ, sau đó giao dịch 2. Giám sát mỗi chu kỳ | `done` dài đúng 1 chu kỳ. Tag hợp lệ khi `done=1` và giữ nguyên lúc rảnh. Trong giao dịch kế tiếp `tag_out` giữ tag cũ đến hết `TAG_WRITE`, rồi đổi sang tag mới. `busy=1` suốt giao dịch, `busy=0` tại `done` | PASS |

**Tổng kết:** 13 test (SANITY + TC13–TC24) PASS, 0 FAIL, 0 lỗi.


---
