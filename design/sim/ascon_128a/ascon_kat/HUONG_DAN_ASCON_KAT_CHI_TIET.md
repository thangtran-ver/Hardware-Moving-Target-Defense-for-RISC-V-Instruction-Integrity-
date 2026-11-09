# Hướng dẫn chi tiết: kiểm thử Ascon-128a bằng golden test (KAT) với Verilator và GTKWave



## 1. Tổng quan

| Mục | Nội dung |
|---|---|
| Đối tượng kiểm thử | Lõi Ascon-128a trong `design/hw/rtl/ascon/ascon_*.v` (17 file), top là `ascon_top.v` |
| Golden test | KAT của ascon-c, biến thể `ascon128av12`, định dạng NIST LWC (`LWC_AEAD_KAT_128_128.txt`) |
| Công cụ | Verilator 5.020 (mô phỏng), GTKWave (xem sóng), Python 3 (sinh vector) |
| Môi trường | Ubuntu 24.04 trong WSL trên Windows |

**Phạm vi test.** Lõi RTL chỉ tính tag xác thực trên AD (dùng để bảo vệ tính toàn vẹn mã lệnh), không mã hóa plaintext. Vì vậy chỉ dùng được **33 vector PT rỗng** trong 1089 vector của KAT (AD dài 0–32 byte). Với PT rỗng thì CT trong KAT chính là tag 16 byte, và testbench so tag này với `tag_out` của RTL. 1056 vector còn lại (PT khác rỗng) cần lõi có đường mã hóa nên không kiểm được với RTL hiện tại.

**Lưu ý chọn đúng file KAT.** Ascon-128 và Ascon-128a có cùng tên file `LWC_AEAD_KAT_128_128.txt` nhưng nội dung khác nhau. RTL của dự án là **128a**, nên phải dùng KAT của `ascon128av12`. Vector đầu của 128a có CT `7A834E6F09210957067B10FD831F0078`.

---

## 2. Cài đặt Ubuntu (WSL) và Verilator

### 2.1 Cài WSL và Ubuntu 24.04 (nếu chưa có)

Mở **PowerShell với quyền Administrator** và chạy:

```powershell
wsl --install -d Ubuntu-24.04
```

Khởi động lại máy nếu được yêu cầu. Lần đầu mở Ubuntu, hệ thống hỏi tên người dùng và **mật khẩu** (dùng cho `sudo`, hãy nhớ mật khẩu này).

Mở Ubuntu sau này: Start Menu → **Ubuntu 24.04**, hoặc trong PowerShell gõ `wsl -d Ubuntu-24.04`.

> Mọi lệnh `bash` trong tài liệu này chạy **trong cửa sổ Ubuntu**, không phải PowerShell (trừ khi ghi rõ).

### 2.2 Cài Verilator và công cụ cần thiết

```bash
sudo apt update
sudo apt install -y verilator g++ make python3
verilator --version
```

Kết quả mong đợi (Ubuntu 24.04): `Verilator 5.020 2024-01-01 ...`. Cần Verilator **5.x** vì script dùng `--binary` và `--timing`.


## 3. Cấu trúc thư mục test

```text
repo
├── design\hw\rtl\ascon\ascon_*.v     # 17 file RTL Ascon-128a
└── design\sim\ascon_128a\ascon_kat\
    ├── LWC_AEAD_KAT_128_128_ascon128a.txt   # KAT gốc, 1089 vector
    ├── gen_vectors.py                  # lọc 33 vector PT rỗng -> kat_vectors.txt
    ├── kat_vectors.txt                 # vector cho testbench (tự sinh)
    ├── tb_ascon_kat.v                  # testbench
    ├── run_verilator.sh                # chạy test bằng Verilator, lưu log
    ├── show_result.sh                  # xem lại log, không chạy lại
    ├── view_wave.tcl / view_wave.sh / view_wave.bat   # tự mở waveform
    ├── run_modelsim.bat / run_modelsim.do             # bản cho ModelSim
    └── results\                        # log các lần chạy (tạo tự động)
        ├── kat_<ngày_giờ>.log
        └── latest.log
```

---

## 4. Chạy test

```bash
cd design/sim/ascon_128a/ascon_kat
chmod +x run_verilator.sh show_result.sh view_wave.sh
./run_verilator.sh
```

Nếu báo lỗi liên quan `\r` (tệp bị dính ký tự xuống dòng kiểu Windows), chạy:

```bash
sed -i 's/\r$//' run_verilator.sh show_result.sh view_wave.sh
```

### 4.1 Script làm gì

1. `gen_vectors.py` đọc KAT gốc, giữ 33 vector PT rỗng, ghi `kat_vectors.txt` (mỗi dòng: key, nonce, độ dài AD, AD, tag).
2. `verilator --binary --timing ...` biên dịch 17 file RTL và `tb_ascon_kat.v`. Đầu ra build nằm ở `/tmp/vl_ascon_kat` (nhanh hơn so với build trên ổ `/mnt/d`). Log biên dịch ở `build.log`.
3. Chạy chương trình mô phỏng, in kết quả và lưu log vào `results/`.
4. In `==== KET QUA: PASS ====` (mã thoát 0) hoặc `FAIL` (mã thoát 1).

### 4.2 Lệnh Verilator tương đương

```bash
cd design/sim/ascon_128a/ascon_kat
python3 gen_vectors.py
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
  --top-module tb_ascon_kat --Mdir /tmp/vl_ascon_kat -o Vtb \
  ../../../hw/rtl/ascon/ascon_*.v tb_ascon_kat.v
/tmp/vl_ascon_kat/Vtb
```

Phải chạy `Vtb` khi đang đứng trong `design/sim/ascon_128a/ascon_kat`, vì testbench mở `kat_vectors.txt` theo đường dẫn tương đối.

### 4.3 Kết quả mong đợi

```text
==================== ASCON-128a KAT (tag, PT rong) ====================
[ 1] AD= 0 byte | expected = 7a834e6f09210957067b10fd831f0078 | result = 7a834e6f09210957067b10fd831f0078 | PASS
[ 2] AD= 1 byte | expected = af3031b07b129ec84153373ddcaba528 | result = af3031b07b129ec84153373ddcaba528 | PASS
...
[33] AD=32 byte | expected = 2fdee642b4c31c2f205dcc8b3dad4542 | result = 2fdee642b4c31c2f205dcc8b3dad4542 | PASS
=============================== THONG KE ===============================
  Tong so vector : 33
  PASS           : 33
  FAIL           : 0
  Ty le dung     : 100%
  KET QUA CHUNG  : PASS
========================================================================
==== KET QUA: PASS ====  (log: results/kat_YYYYMMDD_HHMMSS.log)
```

Mỗi dòng là một vector: tag mong đợi (từ KAT), tag RTL tính được (`tag_out`) và PASS/FAIL.

---

## 5. Testbench kích lõi như thế nào (giao thức)

Với mỗi vector, testbench làm theo thứ tự:

1. Đặt `key_d`, `nonce_d`, `ad_empty` (=1 nếu AD rỗng), rồi phát xung `start` 1 chu kỳ. Lõi chốt key, nonce và `ad_empty` đúng lúc `start`.
2. Nếu AD không rỗng, chia AD thành các khối 16 byte (byte đầu ở bit cao nhất của `ad_data`). Khối cuối có `ad_last=1` và `ad_nbytes` bằng số byte thực; các khối trước có `ad_nbytes=16`.
3. Mỗi khối: đưa `ad_data`, `ad_nbytes`, `ad_last`, `ad_valid=1` và **giữ nguyên cho đến khi thấy `ad_ready=1`**, rồi hạ `ad_valid`. Khối chỉ được nhận khi `ad_valid && ad_ready` cùng bằng 1.
4. Chờ `done`, lấy `tag_out` và so với tag trong KAT.

Điểm cần nhớ: `ad_ready` chỉ lên ở trạng thái `WAIT_AD`, tức sau khi `start` đã chạy xong P12 khởi tạo. Vì vậy nên **phát `start` trước, rồi mới đưa AD**. `ad_valid` lên sớm thì chỉ phải chờ, không mất dữ liệu; nhưng không được hạ `ad_valid` trước khi `ad_ready` lên.

Các trường hợp biên đã được phủ: AD rỗng, 1–15 byte, đúng 16 byte (cần khối padding riêng, trạng thái `PAD_ONLY`), 17–31 byte, đúng 32 byte.

---

## 6. Cài GTKWave và xem waveform

### 6.1 Cài GTKWave

Trong Ubuntu:

```bash
sudo apt install -y gtkwave
```

GTKWave là ứng dụng đồ họa. Trên Windows 11 (và Windows 10 bản mới) có WSLg nên cửa sổ tự hiện. Nếu không hiện, cài GTKWave cho Windows (gtkwave.sourceforge.net) rồi mở trực tiếp `design\sim\ascon_128a\ascon_kat\wave.vcd` trong repo.

### 6.2 Tạo file waveform

```bash
./run_verilator.sh wave
```

Tham số `wave` bật `--trace` và tạo `wave.vcd` (khoảng 2,5 MB) trong `design/sim/ascon_128a/ascon_kat`.

### 6.3 Mở waveform và tự thêm tín hiệu

```bash
gtkwave -S view_wave.tcl wave.vcd
```

`view_wave.tcl` tự thêm tín hiệu, đổi sang hex và zoom toàn bộ. Phải chạy lệnh này **trong terminal (khi dấu nhắc lệnh đang rảnh)**; không dán nội dung Tcl vào terminal hay vào GTKWave, vì Tcl chỉ chạy được khi nằm trong tệp.

Nếu GTKWave đã mở sẵn, vào menu **File → Read Tcl Script File…** và chọn `view_wave.tcl`.

Zoom vào một đoạn thời gian (ví dụ hai vector đầu, 400–1300 ns):

```bash
ZOOM_FROM_NS=400 ZOOM_TO_NS=1300 gtkwave -S view_wave.tcl wave.vcd
```

Hoặc dùng `./view_wave.sh 400 1300` (script tự tạo `wave.vcd` nếu chưa có; `./view_wave.sh --rebuild` chạy lại mô phỏng trước khi mở).

### 6.4 Chọn tín hiệu muốn xem

Danh sách tín hiệu nằm trong khối `set want { ... }` ở đầu `view_wave.tcl`. Ví dụ chỉ xem 6 tín hiệu chính:

```tcl
set want {
  clk rst_n start ad_valid ad_ready tag_out
}
```

Bộ đầy đủ: `clk rst_n mode start ad_empty ad_valid ad_ready ad_last ad_nbytes ad_data key_d nonce_d busy done tag_out dut.u_ctrl.state`.

### 6.5 Thêm tín hiệu bằng tay (không dùng script)

1. Ở khung **SST** (trên cùng bên trái) mở `TOP` → `tb_ascon_kat`. Khung **Signals** bên dưới liệt kê tín hiệu.
2. **Bấm đúp** tín hiệu để thêm vào khung sóng; hoặc chọn nhiều tín hiệu (giữ `Ctrl`/`Shift`) rồi bấm **Append** (thêm xuống cuối), **Insert** (chèn trên tín hiệu đang chọn) hoặc **Replace**.
3. Xem trạng thái FSM: mở `dut` → `u_ctrl`, thêm `state`.
4. Đổi sang hex: chọn tín hiệu, chuột phải → **Data Format → Hexadecimal**.
5. Xóa tín hiệu: chọn rồi nhấn `Delete`. Sắp xếp lại: kéo thả trong khung Signals giữa.
6. Bấm **Zoom Fit** để xem toàn bộ thời gian.
7. Lưu bố cục: **File → Write Save File** thành `wave.gtkw`, lần sau mở bằng `gtkwave wave.vcd wave.gtkw`.


### 6.6 Đọc waveform

- Mỗi vector tương ứng một xung `start`, theo sau là chuỗi `ad_valid` và `ad_ready`, rồi xung `done`. Toàn bộ có 33 xung `start`.
- `ad_nbytes` tăng dần từ 0 lên 32 theo độ dài AD của từng vector.
- `tag_out` đổi giá trị sau mỗi `done` (`7A83…`, `AF30…`, `B486…`, …). So giá trị này với cột `expected` trong log.
- `state` là FSM của `ascon_controller` (ví dụ `03` = WAIT_P12_INIT, `08` = WAIT_P8_AD, `0E` = WAIT_P12_FINAL, `10` = DONE).
- Vector 1 chỉ có `start` (AD rỗng, `ad_empty=1`); từ vector 2 trở đi `ad_valid` lên ngay sau `start` và được giữ đến khi `ad_ready` xuất hiện.

---

## 7. Review kết quả bằng log (không cần chạy lại)

Mỗi lần `./run_verilator.sh` chạy xong, log được lưu:

- `results/kat_<ngày_giờ>.log`: log của từng lần chạy (có ngày chạy, phiên bản Verilator, từng vector và bảng thống kê).
- `results/latest.log`: bản sao của lần chạy mới nhất (`run.log` cũng là bản sao).

Xem lại bằng `show_result.sh`:

```bash
./show_result.sh          # in lại toàn bộ log mới nhất
./show_result.sh fail     # chỉ in dòng FAIL và bảng thống kê
./show_result.sh list     # liệt kê các log đã lưu (mới nhất trước)
```

Cũng có thể xem trực tiếp bằng `cat results/latest.log` hoặc mở thư mục `design\sim\ascon_128a\ascon_kat\results\` trong Windows.



---

## 8. Khi test FAIL

Dòng của vector sai kết thúc bằng `FAIL`. Nếu RTL không phát `done`, dòng có thêm `(timeout, khong co done)`.

| Triệu chứng | Hướng kiểm tra |
|---|---|
| Sai mọi vector | Sai thứ tự byte Key/Nonce; hoặc nhầm file KAT (Ascon-128 thay vì 128a) |
| Sai theo độ dài AD (đặc biệt 16, 32 byte) | `ascon_ad_buffer_padding.v` và trạng thái `PAD_ONLY` trong `ascon_controller.v` |
| `timeout, khong co done` | FSM kẹt ở `WAIT_AD`: kiểm tra `ad_valid` có bị hạ trước khi `ad_ready` lên, hoặc `ad_last` sai |

---

## 9. Lỗi thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `command not found` và `syntax error near unexpected token '}'` | Bạn đã dán nội dung Tcl vào terminal. Tcl phải nằm trong tệp `view_wave.tcl`, chạy bằng `gtkwave -S view_wave.tcl wave.vcd` |
| Terminal "treo" sau khi chạy `gtkwave` | GTKWave đang chạy ở foreground. Đóng cửa sổ GTKWave hoặc nhấn `Ctrl+C` |
| `Permission denied` khi chạy `.sh` | `chmod +x run_verilator.sh show_result.sh view_wave.sh` |
| Lỗi có ký tự `\r` | `sed -i 's/\r$//' <tên_file>.sh` |
| `verilator: command not found` | `sudo apt install -y verilator` |
| Cửa sổ GTKWave trống | Chưa thêm tín hiệu. Chạy lại bằng `gtkwave -S view_wave.tcl wave.vcd`, rồi bấm **Zoom Fit** |
| Không thấy `wave.vcd` | Chạy `./run_verilator.sh wave` (không có tham số `wave` thì không tạo file) |
| GTKWave không hiện cửa sổ | Cần WSLg (Windows 11/10 mới), hoặc dùng GTKWave bản Windows |

---

