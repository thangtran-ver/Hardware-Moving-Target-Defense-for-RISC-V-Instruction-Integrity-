# RTL: SoC PicoRV32 + bo xac thuc lenh (Ascon) tren Tang Nano 20K

Baseline **static instruction integrity**: moi block lenh duoc xac thuc bang tag Ascon
truoc khi CPU duoc phep thuc thi. Day la doi chung (static), chua phai lazy migration / MTD.

## Tong quan

CPU PicoRV32 khong noi thang vao bo nho. Moi truy cap di qua `authenticated_memory_wrapper`:

- **Fetch lenh** trong vung CODE: wrapper doc 1 block code (`G` word) va tag tuong ung tu bo nho,
  nho `ascon_top` tinh lai tag, so sanh. Dung thi tra lenh cho CPU va nho block vao buffer
  (cac fetch sau trong cung block khong phai verify lai). Sai thi **fault**.
- **Truy cap data**: di thang xuong bo nho / UART, khong xac thuc.
- **Ghi vao vung CODE hoac TAG**: bi chan (fault).

```
                         +--------------------------------------------+
                         |            authenticated_memory_wrapper    |
 +-----------+  cpu_mem  |  auth_controller (FSM)                     |  m_*   +---------------------+
 | PicoRV32  |<--------->|  req_reg / addr_check / addr_gen           |<------>| sel_uart ?          |
 | (u_cpu)   |           |  code_buffer / tag_reg / ad_packer         |        |  0x02xx_xxxx: UART  |
 +-----------+           |  tag_compare / fault_reg / perf_counters   |        |  else: system mem   |
                         +-------------------+------------------------+        +----------+----------+
                                             | a_*   ^ cfg                                 |
                                       +-----v-----+ |                      +--------------v---------+
                                       | ascon_top | |                      | fpga_system_memory     |
                                       | (u_ascon) | |                      |  CODE / TAG / DATA     |
                                       +-----^-----+ |                      +------------------------+
                                             | K_code|
                                       +-----+-------+--+
                                       | trusted_key_   |
                                       | and_context    |
                                       +----------------+
```

## Cau truc thu muc

| Duong dan | Vai tro |
| --- | --- |
| `tangnano20k_top.v` | Top-level cho Tang Nano 20K: reset, noi day SoC, tach bus memory/UART, bao loi |
| `picorv32.v` | Core RISC-V RV32I (ma nguon ben thu ba, xem muc Nguon ben thu ba) |
| `authenticated_memory/` | Wrapper xac thuc: `authenticated_memory_wrapper.v` va cac khoi con `auth_*.v` |
| `ascon/` | Loi Ascon tinh tag; danh sach file trong `ascon/files.f` |
| `trusted_key/` | `trusted_key_and_context.v`: key va context (`PROGRAM_ID`, `IMAGE_ID`, base/limit) |
| `fpga_system_memory.v` | Bo nho tren BSRAM, tu nap `$readmemh` tu 3 file hex |
| `fpga_uart.v` | Thanh ghi UART cho CPU (TX, status, RX FIFO 16 byte) |
| `uart_tx.v`, `uart_rx.v` | Bo phat / bo thu UART |
| `uart_src_mux.v` | Chon nguon cho `uart_tx`: CPU hoac bo bao loi |
| `auth_fault_uart_reporter.v` | In thong bao loi xac thuc qua UART |

### Cac khoi trong `authenticated_memory/`

| File | Vai tro |
| --- | --- |
| `auth_controller.v` | FSM dieu khien toan bo luong xac thuc |
| `auth_cfg_decode.v` | Tach `CFG` thanh `program_id`, `image_id`, base/limit |
| `auth_req_reg.v` | Chot request cua CPU |
| `auth_addr_check.v` | Kiem tra dia chi co thuoc vung CODE khong, lenh ghi co vao vung bao ve khong |
| `auth_addr_gen.v` | Sinh dia chi block code va dia chi tag |
| `auth_code_buffer.v` | Luu block da verify (hit thi khong verify lai) |
| `auth_tag_reg.v` | Luu tag tham chieu doc tu bo nho |
| `auth_ad_packer.v` | Dong goi block + dia chi thanh du lieu AD cho Ascon |
| `auth_tag_compare.v` | So sanh tag Ascon tinh duoc voi tag luu |
| `auth_fault_reg.v` | Co fault (sticky) |
| `auth_mem_mux.v`, `auth_resp_mux.v` | Chon dia chi gui bo nho / du lieu tra CPU |
| `auth_counter.v` | Bo dem word va beat |
| `auth_perf_counters.v` | Dem fetch, hit, verify, data, fault, stall |

## Luong xac thuc (FSM trong `auth_controller`)

```
IDLE -> CHECK_REQUEST
  fetch ngoai vung CODE ............ FAULT
  fetch, buffer hit ................ RESPONSE
  fetch, buffer miss ............... READ_CODE -> READ_TAG -> START_ASCON
                                      -> SEND_AD -> WAIT_ASCON -> COMPARE
                                         tag dung: RESPONSE   tag sai: FAULT
  ghi vao CODE/TAG ................. FAULT
  truy cap data khac ............... MEMORY_ACCESS -> IDLE
FAULT: dat co auth_fault; FAULT_HALT=0 tra 0 cho CPU (CPU trap), FAULT_HALT=1 treo CPU
```

Tag duoc tinh tu **nonce = {PROGRAM_ID, IMAGE_ID}**, key `KEY_CODE` va du lieu AD gom noi dung block
cung dia chi block, nen sua lenh, doi cho block, dung image cu hay sai key deu lam tag khong khop.

## Tham so can khop voi firmware

`tangnano20k_top` va `auth_signer.py` (trong `design/sw/firm/`) **phai dung cung tham so**,
neu lech thi ca firmware dung cung bi tu choi.

| Tham so | Mac dinh | Y nghia |
| --- | --- | --- |
| `KEY_CODE` | `128'h000102030405060708090A0B0C0D0E0F` | Key 128 bit |
| `PROGRAM_ID` | `1` | Dinh danh chuong trinh (64 bit) |
| `IMAGE_ID` | `1` | Phien ban image (64 bit) |
| `G` | `4` | So word moi block duoc xac thuc |
| `T` | `128` | So bit tag |
| `FAULT_HALT` | `0` | 0: tra 0 cho CPU de trap; 1: giu CPU |
| `CLK_HZ` / `UART_BAUD` | `27_000_000` / `115200` | Xung he thong va toc do UART |
| `CODE_INIT`, `TAG_INIT`, `DATA_INIT` | duong dan toi `active/*.hex` | File nap `$readmemh` |

> `CODE_INIT`, `TAG_INIT`, `DATA_INIT` dung duong dan **tuong doi**:
> `../../sw/firm/active/{code,tag,data}.hex`, tinh tu thu muc `design/hw/rtl/`.
> Neu Gowin khong tim thay file khi tong hop (Gowin co the tinh duong dan tuong doi theo thu muc
> du an `.gprj`), sua 3 tham so nay cho dung vi tri du an cua ban, hoac truyen tham so luc tong hop.

## Ban do bo nho

| Vung | Dia chi | Kich thuoc | Quyen |
| --- | --- | --- | --- |
| CODE | `0x0000_0000` - `0x0000_1FFF` | 2048 word | Chi doc, duoc xac thuc |
| TAG | `0x0001_0000` - `0x0001_1FFF` | 2048 word | Chi doc |
| DATA | `0x0002_0000` - `0x0002_0FFF` | 1024 word | Doc / ghi |
| UART TX data | `0x0200_0010` | byte | Ghi |
| UART status | `0x0200_0014` | `[0]` TX busy, `[1]` RX ready, `[2]` RX overrun | Doc |
| UART RX data | `0x0200_0018` | byte | Doc (lay 1 byte tu FIFO) |

Dia chi reset CPU `0x0000_0000`, stack `0x0002_1000`.

## Bao loi qua UART

Khi `auth_fault` len 1, `auth_fault_uart_reporter` chiem UART (115200 baud) va in 1 dong, vi du:

```
[AUTH] FAULT: TAG-MISMATCH addr=0x00000140 trap=1
```

| Ma | Ly do | Dieu kien |
| --- | --- | --- |
| `TAG-MISMATCH` | Fetch trong vung CODE nhung tag khong khop | Sua lenh, doi block, sai key, image cu |
| `FETCH-NOCODE` | Fetch ngoai vung CODE | Nhay vao data RAM |
| `WRITE-PROT` | Lenh ghi vao vung CODE/TAG | Firmware ghi de ma |

Neu CPU da trap, dong nay duoc in lap lai moi khoang 2.5 giay.

## Chan board (Tang Nano 20K)

| Tin hieu | Chan | Ghi chu |
| --- | --- | --- |
| `sys_clk` | 4 | 27 MHz |
| `btn_rst` | 88 | Nut S1; top tu nhan cuc tinh sau power-on reset |
| `uart_tx` | 41 | Toi RXD cua CP2102 |
| `uart_rx` | 42 | Tu TXD cua CP2102 |

File rang buoc `tangnano20k.cst` khong nam trong thu muc nay; dat o thu muc du an Gowin.

## Tong hop (Gowin)

1. Tao du an Gowin cho Tang Nano 20K, them toan bo `.v` trong thu muc nay (ke ca thu muc con),
   top module la `tangnano20k_top`.
2. Them file rang buoc chan `.cst`.
3. Chuan bi `code.hex`, `tag.hex`, `data.hex` (build va ky firmware, xem `design/sw/firm/README.md`).
4. Sua `CODE_INIT`, `TAG_INIT`, `DATA_INIT` tro toi cac file do.
5. Process -> **Clean**, roi Synthesize -> Place & Route -> Program.

`fpga_system_memory` dung thanh ghi doc rieng cho tung mang de Gowin suy ra BSRAM.

## Mo phong

Testbench nam trong `design/verification/` (xem README o do). Cac khoi trong `ascon/`, `authenticated_memory/`
va `trusted_key/` duoc dung nguyen ban cho ca mo phong lan FPGA. Chi cac file sau la rieng cho FPGA:
`tangnano20k_top.v`, `fpga_system_memory.v`, `fpga_uart.v`, `uart_*.v`, `auth_fault_uart_reporter.v`.

## Nguon ben thu ba

| Thanh phan | Nguon | License |
| --- | --- | --- |
| `picorv32.v` | PicoRV32, Claire Xenia Wolf (YosysHQ) | ISC (xem header trong file) |
| `ascon/` | Hien thuc Ascon (tac gia tu ghi ro nguon neu lay tu ben ngoai) | Cap nhat |

Cac file khac la ma cua tac gia du an.

## Trang thai

Day la baseline static. Chua co region/version table va giao thuc lazy prepare/publish/retire;
nhung muc do thuoc muc tieu nghien cuu, chua phai ket qua da dat.
