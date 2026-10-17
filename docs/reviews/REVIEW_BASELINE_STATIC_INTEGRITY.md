# Review baseline Static Authenticated Execution

Ngày review: 2026-10-11. Folder: `D:\JOURNAL MTD`
Phạm vi: block diagram (PicoRV32 / Authenticated Memory / System Memory / Ascon-128A / Trusted Key and Context) và các file RTL `authenticated_memory_wrapper.v`, `system_memory.v`, `trusted_key_and_context.v`, `ascon_top.v`, `ascon_controller.v`.
Cách review: chỉ đọc code, không sửa file nào. Wrapper chưa có logic nên chưa mô phỏng được.

---

## 0. Kết luận nhanh

- **Hướng kiến trúc đúng cho baseline.** Verifier đặt ở memory wrapper; key `K_code` đi thẳng từ khối trusted vào Ascon, không qua wrapper; tag lưu ở vùng riêng; context lấy từ khối tin cậy.
- **Chưa phải baseline.** Wrapper mới là khung. Các quyết định baseline phải trả lời (message format, granularity, fault policy, vị trí chặn, đo chi phí) chưa có trong RTL lẫn sơ đồ.

Trạng thái từng module:

| Module | Trạng thái |
|---|---|
| `ascon_top.v` + `ascon_controller.v` | Xong. PASS 3042/3042, FSM coverage 21/21 (bản sửa 08/10) |
| `trusted_key_and_context.v` | OK. CFG = 64+64+32+32+32 = 224 bit, khớp port |
| `system_memory.v` | Chạy được, cần bổ sung cho attack campaign (mục 2.3) |
| `authenticated_memory_wrapper.v` | **Mới là khung, chưa chạy được** (mục 2.1) |
| `ascon_top_prefix.v` | Bản cũ có lỗi, trùng tên module `ascon_top`. **Xoá hoặc đổi đuôi `.bak`**, nếu không `vlog *.v` sẽ báo trùng module |

---

## 1. Các điểm cần lưu ý (thiết kế, threat model)

### 1.1 Mục tiêu của baseline
Baseline là **đối chứng bắt buộc**, không phải MTD. Nó phải trả lời được 4 câu:
1. Chi phí cơ bản của integrity verification.
2. Tag granularity phù hợp.
3. Verification nên đặt ở memory wrapper, fetch/frontend hay chỗ khác.
4. Static context binding ngăn được modification/transplantation tới đâu.

→ Mọi quyết định bên dưới nên là **parameter** để quét được, không hard-code.

### 1.2 Ascon dùng làm MAC
- Dùng Ascon-128a **v1.2**, plaintext rỗng, chỉ có AD → tag chính là MAC trên AD.
- Nonce cố định hoặc lặp lại **không phải lỗi** trong chế độ này, vì không có plaintext để lộ. Tag chỉ trở thành hàm xác định của (key, nonce, AD), đúng thứ cần cho verify tĩnh.
- Trong journal ghi rõ "Ascon-128a v1.2", **không** ghi "NIST SP 800-232" (hai bản không tương thích bit).
- AD luôn khác rỗng, nên buộc `ad_empty = 0`.

### 1.3 Message format đề xuất (cần chốt)

```
nonce[127:0] = { PROGRAM_ID[63:0], IMAGE_ID[63:0] }   // vừa đúng 128 bit lấy từ CFG
AD           = { block_addr[31:0], word0, word1, ..., word(G-1) }   // big-endian, MSB-aligned
tag_ref      = tag_rom[block_index]  (T bit đầu của tag)
```

Field nào chặn tấn công nào (đây là bảng "static binding ngăn tới đâu"):

| Tấn công | Bị chặn bởi | Ghi chú |
|---|---|---|
| Sửa nội dung lệnh | code words trong AD | |
| Dời block sang địa chỉ khác (transplant nội bộ image) | `block_addr` trong AD | Nếu bỏ `addr` khỏi message thì **không** chặn được |
| Đổi cặp (code, tag) giữa 2 địa chỉ | `block_addr` | |
| Ghép block hoặc tag từ firmware khác | `PROGRAM_ID` | |
| Rollback về image cũ | `IMAGE_ID` | Chỉ đúng nếu **tăng IMAGE_ID mỗi lần release** |
| Chèn mã vào data RAM rồi nhảy tới | **region check** | Chưa có (mục 2.1) |
| Replay cặp (code, tag) hợp lệ cùng version, cùng địa chỉ | không chặn | Không phải tấn công với static. Đây là chỗ để MTD/version động cải thiện |
| ROP/JOP dùng lại code hợp lệ | không chặn | Ngoài phạm vi, ghi vào giới hạn |

### 1.4 Vị trí verify và ranh giới no-unauthorized-effect
- PicoRV32 không có I-cache hay prefetch, nên verify ở wrapper ≈ verify ở fetch path. Dùng `cpu_mem_instr` để phân biệt fetch và data.
- Baseline chọn **verify-before-forward**: chỉ bật `cpu_mem_ready` cho fetch **sau khi tag khớp**. Lệnh chưa xác thực không bao giờ tới decoder, nên ranh giới no-unauthorized-effect rõ ràng.
- Biến thể verify song song/speculative (forward trước, chặn ở commit) phải sửa core vì PicoRV32 không có commit stage. Để làm sau, ghi lại là hướng so sánh.

### 1.5 Granularity và metadata
Hiện `tag_rom` (8 KB) = `code_rom` (8 KB), tức đang ngầm chọn **overhead metadata 100%**: 128 bit/4 lệnh, hoặc 32 bit/lệnh.

Ước lượng chi phí (latency Ascon đo được: `33 + 12·ceil(L/16)`, +11 nếu L chia hết 16; memory trả mỗi word sau khoảng 2 chu kỳ):

| G (word/block) | AD L (byte) | Ascon (clk) | Đọc memory | ≈ chi phí 1 lần verify |
|---|---|---|---|---|
| 1 | 8 | 45 | 1 code + T/32 tag | ~50 clk mỗi lệnh |
| 4 | 20 | 57 | 4 code + T/32 tag | ~75–80 clk mỗi 4 lệnh |
| 8 | 36 | 69 | 8 code + T/32 tag | ~95 clk mỗi 8 lệnh |

Metadata overhead = T / (32·G). Ví dụ G=4: T=128 → 100%, T=64 → 50%, T=32 → 25%.
→ Đây chỉ là **ước lượng**. Số thật phải lấy từ counter (mục 3.4).

### 1.6 Threat model: phải ghi rõ trong bài
- Lệnh load data từ vùng code (`.rodata` nằm trong `.text`, `cpu_mem_instr=0`) **không được xác thực**.
- Key là hằng `parameter`, tổng hợp thành hằng số trong logic. Chấp nhận cho baseline, nhưng ghi là giới hạn (chưa nạp key/CSR, chưa PUF).
- Tag không cần bí mật. CPU đọc được vùng tag là được, nhưng không được ghi nếu muốn đo tấn công đúng.
- Không chống fault injection lên chính verifier.

---

## 2. Các điểm còn sai

### 2.1 `authenticated_memory_wrapper.v` (nặng nhất)
- [ ] Có khai báo state `IDLE..MEMORY_ACCESS` nhưng **không có logic chuyển trạng thái** và không có `always @(*)` cho next state.
- [ ] `state = IDLE;` và `next_state = CHECK_REQUEST;` dùng **blocking `=`** trong khối `always @(posedge clk)`. Phải dùng `<=` và tách next-state ra khối tổ hợp.
- [ ] Không có nhánh khi `cpu_mem_valid = 1`, nên **CPU treo vĩnh viễn** (không bao giờ có `cpu_mem_ready`).
- [ ] `auth_fault` **không được reset và không được drive**, nên ra X.
- [ ] `cpu_mem_ready <= 0` bị gán lặp 2 lần (vô hại nhưng nên dọn).
- [ ] Nhánh `!cpu_mem_valid` reset toàn bộ output về 0. Nếu đang verify mà CPU hạ valid (không xảy ra với PicoRV32, nhưng xảy ra khi reset/trap) thì giao dịch đang dở với memory hoặc Ascon bị cắt ngang. Cần xử lý abort cho đúng: chờ Ascon `done` rồi mới về IDLE.
- [ ] Thiếu port `a_ad_empty` (hoặc buộc 0 trong top).
- [ ] Data path (fetch và data) chưa có: `m_*` không nối với `cpu_mem_*`.

### 2.2 Block diagram
- [ ] Thiếu `ad_empty` ở khối Ascon (vẽ thêm, hoặc ghi chú "tied 0").
- [ ] `auth_fault → TRUSTED KEY AND CONTEXT`: RTL `trusted_key_and_context` **không có input**. Phải chốt fault đi đâu (xem 3.3) rồi sửa sơ đồ: ví dụ ra khối Fault/Status (sticky reg, LED/UART) và/hoặc về CPU (trap).
- [ ] Thiếu luồng **offline signing** (compile → objcopy → signer → `tag_rom.hex`). Không có nó thì baseline không có bước provisioning.
- [ ] Thiếu khối **counters** (đo chi phí).
- [ ] Nên ghi chú trên mũi tên CFG: `{PROGRAM_ID, IMAGE_ID, CODE_BASE, CODE_LIMIT, TAG_BASE}`.
- [ ] Nên ghi chú message format (mục 1.3) ngay cạnh khối Ascon hoặc wrapper.

### 2.3 `system_memory.v`
- [ ] Vùng code/tag **chỉ đọc qua bus**: lệnh ghi vào đó trả `ready` nhưng bỏ qua mà không báo gì. Không mô phỏng được attacker sửa code/tag lúc chạy. Cần cổng ghi tấn công (mục 3.5).
- [ ] Lệnh đọc ngoài vùng hoặc không aligned trả `0` kèm `ready`, không báo lỗi. Với fetch thì wrapper phải chặn trước (region check).
- [ ] Thiếu `$readmemh` cho `code_rom` và `tag_rom` (hoặc thêm parameter tên file).
- [ ] Ghi data commit ở chu kỳ sau `ready` (`write_pending`). Chạy được, nhưng có thể đơn giản thành ghi ngay chu kỳ nhận request.
- [ ] Các hằng `CODE_BASE/TAG_BASE/...` bị định nghĩa **2 nơi** (đây và `trusted_key_and_context`). Gom về 1 file `include` hoặc parameter truyền từ top để không lệch nhau.

### 2.4 `trusted_key_and_context.v`
- [ ] Thiếu `TAG_LIMIT`, `G` (granularity), `T` (tag width). Nên đưa vào CFG hoặc parameter chung.
- [ ] Không có input `auth_fault` dù sơ đồ vẽ có. Sửa sơ đồ hoặc thêm port (xem 2.2).

### 2.5 Dọn dẹp
- [ ] `ascon_top_prefix.v` trùng tên module `ascon_top`, nên xoá hoặc đổi `.bak`.
- [ ] Các file `.bak` cũ.
- [ ] `ascon_p12.v`: `round_index <= 3'b000` gán vào thanh ghi 4 bit; comment "round thu 8" là copy từ p8.
- [ ] `ascon_initial_state.v`: `reg IV` khai báo mà không dùng.

---

## 3. Cần làm thêm (theo thứ tự)

### 3.1 Chốt spec (làm trước khi viết RTL)
- [ ] Message format (mục 1.3), thứ tự byte, cách đánh `block_index = (addr - CODE_BASE) / (4·G)`.
- [ ] Layout tag: `tag_addr = TAG_BASE + block_index · (T/8)`.
- [ ] Parameter: `G ∈ {1, 2, 4, 8}`, `T ∈ {32, 64, 128}`.
- [ ] Fault policy (3.3).

### 3.2 Viết FSM wrapper
Luồng đề xuất cho fetch (`cpu_mem_instr = 1`):
1. `IDLE`: nhận `cpu_mem_valid`, chốt `addr/instr/wdata/wstrb`.
2. `CHECK_REQUEST`:
   - fetch ngoài `[CODE_BASE, CODE_LIMIT]` → `FAULT`;
   - fetch trúng buffer đã verify → trả lệnh từ buffer → `RESPONSE`;
   - data access → `MEMORY_ACCESS` (đi thẳng, không verify).
3. `READ_CODE`: đọc G word của block vào buffer tạm.
4. `READ_TAG`: đọc T/32 word tag.
5. `START_ASCON` → `SEND_AD` (gửi `block_addr || words` theo valid/ready, beat cuối `ad_last`) → `WAIT_ASCON`.
6. `COMPARE`: so `a_tag[127 -: T]` với tag đọc được.
   - khớp: đánh dấu buffer valid, trả word cần fetch **từ buffer** (chống TOCTOU) → `RESPONSE`;
   - sai → `FAULT`.
7. `RESPONSE`: `cpu_mem_ready = 1` đúng 1 chu kỳ.

Yêu cầu kèm theo:
- [ ] **Verified-block buffer** tối thiểu 1 line (G word + tag + addr + valid). Invalidate khi reset hoặc fault.
- [ ] **Không đọc lại memory** sau khi verify: lệnh trả cho CPU phải là đúng word đã hash.
- [ ] Buộc `a_ad_empty = 0`; `a_nonce = {CFG.PROGRAM_ID, CFG.IMAGE_ID}`.
- [ ] Data write vào vùng code/tag từ CPU: chặn (không gửi xuống memory) và tuỳ chọn báo fault.

### 3.3 Fault handling (chọn 1 và ghi vào bài)
- [ ] **Phương án A (khuyến nghị):** trả `cpu_mem_rdata = 32'h00000000` kèm `ready`. PicoRV32 với `CATCH_ILLINSN=1` sẽ trap. Đồng thời chốt `auth_fault = 1` (sticky).
- [ ] Phương án B: giữ `cpu_mem_ready = 0` mãi (CPU treo) và `auth_fault = 1`.
- [ ] Đưa `auth_fault` ra LED/UART/MMIO status để quan sát trên kit.
- [ ] Ghi rõ trong bài: lệnh lỗi **không bao giờ** tới decoder.

### 3.4 Đo chi phí
Counter trong wrapper (đọc qua MMIO hoặc in trong TB):
- [ ] `n_fetch`, `n_verify` (miss), `n_hit`, `n_fault`.
- [ ] `cyc_stall_verify` (tổng chu kỳ CPU chờ do verify), `cyc_total`.
- [ ] So sánh với PicoRV32 gốc: cùng firmware, cùng memory latency → slowdown, CPI.
- [ ] Quartus: ALUT/FF/BRAM/Fmax riêng wrapper, Ascon và toàn hệ. Quét theo G/T.
- [ ] Metadata overhead = kích thước `tag_rom` / `.text`.

### 3.5 Signer và testbench tấn công
- [ ] `tools/sign_code.py`: đọc hex (objcopy `--verilog-data-width=4`), tách `.text`, tính tag theo message format, xuất `tag_rom.hex`. Dùng lại `verify/ascon_ref.py` (đã khớp 1089/1089 KAT).
- [ ] Kiểm tra bit-exact: tag do signer tính phải khớp tag `ascon_top` trả ra trên cùng block.
- [ ] Cổng ghi tấn công trong `system_memory` (chỉ dùng trong TB, ví dụ `ifdef ATTACK_PORT`) để sửa code/tag lúc đang chạy.
- [ ] Campaign (mỗi kịch bản: kỳ vọng fault hay pass, chu kỳ phát hiện):

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| 1 | Firmware + tag đúng | PASS, chạy hết, `n_fault = 0` |
| 2 | Lật 1 bit code (ngẫu nhiên, N lần) | FAULT ở lần fetch đầu tiên của block đó |
| 3 | Lật 1 bit tag | FAULT |
| 4 | Swap 2 block (code + tag) khác địa chỉ | FAULT (nhờ addr) |
| 5 | Block + tag lấy từ firmware khác (PROGRAM_ID khác) | FAULT |
| 6 | Image cũ (IMAGE_ID cũ) | FAULT |
| 7 | Chèn mã vào data RAM rồi nhảy tới | FAULT (region check) |
| 8 | Sửa code **sau** khi block đã vào buffer | Không thực thi bản sửa (TOCTOU) |
| 9 | Firmware không ký (tag_rom rỗng) | FAULT ngay lệnh đầu |

- [ ] Assertion: `cpu_mem_ready && cpu_mem_instr && !auth_fault` → word trả về phải bằng word đã verify trong buffer.

### 3.6 Cập nhật block diagram
- [ ] Thêm `ad_empty` (tied 0), khối Fault/Status, khối Counters, luồng signer offline.
- [ ] Ghi message format và tham số G/T lên sơ đồ.
- [ ] Để CFG là một interface có thể thay bằng region/version table ở bước 6 (MTD), không hard-wire.

---

## 4. Thứ tự làm gợi ý

1. Dọn `ascon_top_prefix.v` và các file `.bak`.
2. Chốt spec (3.1) và fault policy (3.3).
3. Viết signer (3.5) trước, để có `tag_rom.hex` làm golden.
4. Viết FSM wrapper (3.2) + counter (3.4).
5. TB kịch bản 1 (chạy đúng), rồi 2–9.
6. Quét G/T, lấy số Quartus.
7. Sửa block diagram theo spec đã chốt.
