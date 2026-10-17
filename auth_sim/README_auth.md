# Authenticated Memory Wrapper: baseline static integrity

Ngày: 2026-10-13. Mô phỏng bằng Icarus Verilog với PicoRV32 thật (YosysHQ). Chưa chạy lại trên ModelSim.

Wrapper đã được tách thành 14 khối nhỏ (mục "Cấu trúc khối"). Hành vi giống hệt bản gộp: 11/11 kịch bản và bảng chi phí G/T cho cùng số chu kỳ.

## File

| File | Vị trí | Nội dung |
|---|---|---|
| `authenticated_memory_wrapper.v` | `authenticated_memory/` | Top của verifier, chỉ nối dây 14 khối `auth_*.v`. Parameter `G`, `T`, `FAULT_HALT` |
| `auth_*.v` (14 file) | `authenticated_memory/` | Các khối con, xem mục "Cấu trúc khối" |
| `tb_auth_units.v` | `auth_sim\` | Unit test từng khối con, in `[PASS]/[FAIL]` theo khối |
| `auth_soc_top.v` | `soc/` | Top: PicoRV32 + wrapper + system_memory + ascon_top + trusted_key_and_context |
| `tb_auth_soc.v` | `auth_sim\` | Testbench chạy firmware, có các kịch bản tấn công, tự in `CHECK PASS/FAIL` |
| `sign_code.py` | `auth_sim\` | Signer offline: code hex → code đệm đủ block + tag hex |
| `gen_fw.py` | `auth_sim\` | Sinh firmware test RV32I (assembler mini, chỉ dùng cho TB) |
| `ascon_ref.py` | `auth_sim\` | Golden model Ascon-128a v1.2 (khớp 1089/1089 KAT), signer dùng |
| `picorv32.v` | `auth_sim\` | PicoRV32 gốc (YosysHQ, giấy phép ISC) |
| `*.hex` | `auth_sim\` | Firmware và tag đã ký sẵn cho các kịch bản |
| `files.f`, `run_all.do` | `auth_sim\` | Danh sách file và script ModelSim |

Các khối đang dùng nằm trong `authenticated_memory/`. Bản lưu và bản nháp được giữ tại `archive/backups/` và `archive/legacy/`. `auth_request_check.v` và `auth_request_reg.v` chưa dùng trong build; RTL hiện tại dùng `auth_addr_check.v` và `auth_req_reg.v`.

## Cấu trúc khối

| Khối | Loại | Việc làm | Tín hiệu chính |
|---|---|---|---|
| `auth_controller` | FSM | 11 state, chỉ sinh tín hiệu điều khiển | vào: trạng thái từ datapath; ra: `*_we`, `*_clr/inc`, `m_en/m_sel`, `resp_en/resp_sel`, `a_start`, `a_ad_valid` |
| `auth_cfg_decode` | tổ hợp | Tách CFG, tính `tag_limit` | `cfg` → `program_id`, `image_id`, `code_base/limit`, `tag_base/limit` |
| `auth_req_reg` | tuần tự | Chốt request CPU khi `we` | `cpu_mem_*` → `req_*` |
| `auth_addr_check` | tổ hợp | Fetch có hợp lệ không, ghi có vào vùng cấm không | → `in_code`, `wr_protected` |
| `auth_addr_gen` | tổ hợp | Sinh địa chỉ | → `blk_base`, `word_off`, `code_addr`, `tag_addr` |
| `auth_counter` (×2) | tuần tự | Đếm word đọc / beat AD | `clr`, `inc` → `cnt` |
| `auth_code_buffer` | tuần tự | Buffer G word + valid + block, so hit | → `hit`, `rdata`, `code_flat` |
| `auth_tag_reg` | tuần tự | Ghép T bit tag đọc từ memory | → `tag_q` |
| `auth_ad_packer` | tổ hợp | Ghép `{blk_base, words}` thành beat 128 bit | → `ad_data`, `ad_nbytes`, `last` |
| `auth_tag_compare` | tổ hợp | So T bit đầu của `a_tag` | → `tag_ok` |
| `auth_fault_reg` | tuần tự | `auth_fault` sticky | `set` → `fault` |
| `auth_mem_mux` | tổ hợp | Chọn request xuống memory: code / tag / data | `m_en`, `m_sel` → `m_*` |
| `auth_resp_mux` | tổ hợp | Chọn dữ liệu trả CPU: buffer / memory / 0 | `resp_en`, `resp_sel` → `cpu_mem_*` |
| `auth_perf_counters` | tuần tự | 6 bộ đếm chi phí | `inc_*` → `perf_*` |

Bảng điều khiển của FSM (state → tín hiệu bật → state kế):

| State | Bật | Sang |
|---|---|---|
| `IDLE` | `req_we` khi `cpu_mem_valid` | `CHECK_REQUEST` |
| `CHECK_REQUEST` | `cnt_clr`, `beat_clr`; miss thì `buf_inv` | fetch: `FAULT` / `RESPONSE` (hit) / `READ_CODE`; data: `FAULT` (`wr_protected`) / `MEMORY_ACCESS` |
| `READ_CODE` | `m_en`, `m_sel=code`; `m_ready` → `code_we` + `cnt_inc` | `READ_TAG` sau word G−1 |
| `READ_TAG` | `m_en`, `m_sel=tag`; `m_ready` → `tag_we` + `cnt_inc` | `START_ASCON` sau word T/32−1 |
| `START_ASCON` | `a_start` (Moore) | `SEND_AD` khi `!a_busy` |
| `SEND_AD` | `a_ad_valid` (Moore); `a_ad_ready` → `beat_inc` | `WAIT_ASCON` sau beat cuối |
| `WAIT_ASCON` | — | `COMPARE` khi `a_done` |
| `COMPARE` | `buf_set` nếu `tag_ok` | `RESPONSE` / `FAULT` |
| `RESPONSE` | `resp_en`, `resp_sel=buffer` | `IDLE` |
| `MEMORY_ACCESS` | `m_en`, `m_sel=data`; `m_ready` → `resp_en`, `resp_sel=memory` | `IDLE` |
| `FAULT` | `fault_set`, `buf_inv`; `resp_sel=zero` | `IDLE` (hoặc ở lại nếu `FAULT_HALT=1`) |

Cách debug gợi ý:

1. Chạy `tb_auth_units` trước. Khối nào `[FAIL]` thì sửa khối đó; testbench in ra tên phép kiểm tra cùng giá trị got/exp.
2. Unit test đều PASS mà kịch bản hệ thống sai: mở waveform `dut.u_auth.u_ctrl.state` cùng tín hiệu điều khiển, đối chiếu với bảng FSM ở trên.
3. Unit test đã được thử bằng cách cố ý cài 6 lỗi (sai shift tag_addr, sai nbytes beat cuối, bỏ `inv`, đếm word lệch 1, lệch biên `code_limit`, đảo thứ tự word tag): bắt được cả 6.

## Thiết kế

- **Message:** `nonce = {PROGRAM_ID, IMAGE_ID}`, `AD = {block_addr, word0..word(G-1)}` (mỗi word MSB trước). Tag so sánh = T bit đầu, lưu ở `TAG_BASE + ((block_addr - CODE_BASE) / 4G) · (T/8)`.
- **Fetch (`cpu_mem_instr=1`):** `CHECK_REQUEST` → fault nếu ngoài `[CODE_BASE, CODE_LIMIT]`; trúng buffer thì trả luôn; không trúng thì `READ_CODE` (G word) → `READ_TAG` (T/32 word) → `START_ASCON` → `SEND_AD` → `WAIT_ASCON` → `COMPARE` → `RESPONSE` hoặc `FAULT`.
- **Verify-before-forward:** chỉ bật `cpu_mem_ready` cho fetch sau khi tag khớp. Lệnh trả cho CPU lấy từ buffer đã hash (`code_q`), không đọc lại memory.
- **Data (`cpu_mem_instr=0`):** đi thẳng xuống memory. Ghi vào vùng CODE hoặc TAG thì bị chặn và báo fault.
- **Fault:**
  - `FAULT_HALT=0` (mặc định): trả `0x00000000` kèm ready, PicoRV32 trap.
  - `FAULT_HALT=1`: giữ CPU treo.
  - Cả hai chế độ đều chốt `auth_fault` (sticky, chỉ xoá khi reset) và xoá buffer.
- **Counter** (đọc qua hierarchy `u_auth.perf_*`): fetch, hit, verify, data, fault, stall.
- **Output sang Ascon là Moore** (chỉ phụ thuộc state). Nếu để chung khối tổ hợp với logic đọc `a_busy`/`a_ad_ready`, mô phỏng sẽ bị treo do vòng lặp zero-delay qua controller Ascon (lỗi này đã gặp và đã sửa).
- **Ascon:** `ad_empty` buộc 0 trong `auth_soc_top`.

## Kết quả (G=4, T=128, Icarus)

| # | Kịch bản | Kết quả |
|---|---|---|
| 1 | Firmware + tag đúng | PASS: chạy hết, DATA = 55 / 110 / 0xDEADBEEF, không fault |
| 2 | Lật 1 bit code ở 0x14 | PASS: fault + trap, marker không được ghi |
| 3 | Lật 1 bit tag block 1 | PASS: fault |
| 4 | Đổi chỗ block 1 và 2 (cả code lẫn tag) | PASS: fault (nhờ `block_addr`) |
| 5 | Tag ký với PROGRAM_ID khác | PASS: fault ngay block đầu |
| 6 | Image cũ (IMAGE_ID khác) | PASS: fault |
| 7 | Tag ký bằng key khác | PASS: fault |
| 8 | Nhảy vào mã chèn trong data RAM | PASS: fault (region check, không cần tính tag) |
| 9 | TOCTOU: sửa 0x14 sau khi block đã vào buffer | PASS: vẫn chạy bản đã verify, kết quả đúng |
| 10 | Firmware không ký | PASS: fault ngay lệnh đầu |
| 11 | Store vào vùng CODE | PASS: lệnh ghi bị chặn, `auth_fault=1`, code không đổi |

Với G = 1 hoặc 2, kịch bản 9 cho kết quả fault thay vì chạy tiếp. Lý do: block chứa 0x14 bị đẩy khỏi buffer rồi fetch lại, lúc đó tag không khớp. Trong cả hai trường hợp, lệnh đã bị sửa đều không được thực thi.

`FAULT_HALT=1` cũng đã thử: CPU treo, `auth_fault=1`, không trap.

## Chi phí (firmware test, 57 lần fetch, buffer 1 line)

Số chu kỳ dưới đây tính cả 20 chu kỳ chờ cuối testbench. PicoRV32 nối thẳng memory: **235 chu kỳ**.

| G \ T | 32 | 64 | 128 | Số lần verify | Hit |
|---|---|---|---|---|---|
| 1 | 2997 | 3103 | 3315 | 53 | 4 |
| 2 | 1725 | 1779 | 1887 | 27 | 30 |
| 4 | 708 | 720 | 744 | 6 | 51 |
| 8 | 650 | 658 | 674 | 4 | 53 |

Chi phí do số lần verify quyết định, độ dài tag ảnh hưởng ít. Mỗi lần verify mất khoảng 2 chu kỳ cho mỗi word đọc từ memory, cộng 45–69 chu kỳ cho Ascon. Đây là số trên một firmware nhỏ, chỉ dùng để so sánh tương đối.

## Chạy lại trong ModelSim

Các lệnh `cd` dưới đây bắt đầu từ thư mục gốc project.

```
cd auth_sim
vsim -c -do run_all.do
```

Kết quả mong đợi: `UNIT errors = 0`, sau đó 13 dòng `CHECK PASS`.

Ký firmware thật bằng `auth_signer.py` (thay cho `sign_code.py`):

```
cd auth_sim\fw_c
build.bat
```

hoặc gọi trực tiếp:

```
python auth_signer.py sign  --elf fw.elf --out-code code.hex --out-tag tag.hex --out-data data.hex
python auth_signer.py check --code code.hex --tag tag.hex          (tìm block có tag sai)
python auth_signer.py trace --code code.hex --tag tag.hex --addr 0x14   (giá trị a_ad_data, a_tag mong đợi để so waveform)
```

- **Lệnh không bị mã hoá:** `code.hex` chứa lệnh plaintext, chỉ có `tag.hex` là thêm vào.
- **Đầu vào:** `--elf` (khuyên dùng), `--bin --bin-base`, `--memh` (file `$readmemh` 32 bit, ví dụ objcopy `--verilog-data-width=4`), `--vhex` (objcopy verilog 1 byte/token).
- **Tham số phải khớp RTL:** `--g`, `--t`, `--key` (= `KEY_CODE`), `--program-id`, `--image-id` (= parameter của `trusted_key_and_context`), cùng `--code-base`/`--code-limit`/`--tag-base`.
- **Đã kiểm tra:**
  - Firmware C trong `fw_c` (biên dịch bằng clang rv32i) chạy đúng qua RTL.
  - Giá trị `trace` khớp bit với `a_ad_data` và `a_tag` trong mô phỏng.
  - Kết quả của `auth_signer.py` trùng `sign_code.py` ở mọi G/T.
- **`fw_c/fw.elf` có sẵn được biên dịch bằng clang (zig cc)**, không phải xPack gcc. Muốn dùng gcc thì chạy lại `build.bat`.

Sinh lại tag cho firmware test của `gen_fw.py`:

```
python sign_code.py fw.hex --out-code code.hex --out-tag tag.hex --g 4 --t 128 --key 000102030405060708090A0B0C0D0E0F --program-id 1 --image-id 1
```

Lưu ý: `fw.hex` có định dạng `$readmemh` (1 word/dòng, `@` là chỉ số word), giống file nạp vào `code_rom`.

## Giới hạn và việc còn lại

- **Kích thước vùng TAG:** `system_memory` có tag_rom 2048 word. Cấu hình có metadata trên 100% (ví dụ G=1, T=128) chỉ phủ được một phần vùng CODE.
- **Buffer 1 line:** mỗi lần gọi hàm hoặc quay về block cũ đều phải verify lại. Có thể thêm 2–4 line để giảm chi phí.
- **Lệnh load data từ vùng CODE** (`.rodata`) chưa được xác thực.
- **Chưa có số Quartus.** Chưa chạy Yosys được ở môi trường này.
- **Chưa test firmware thật** biên dịch bằng gcc: cần một firmware objcopy `--verilog-data-width=4` rồi ký bằng `sign_code.py`.
