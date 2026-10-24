//======================================================================
//  tangnano20k_top.v -- KHOI MOI: top board Tang Nano 20K cho auth_soc
//
//  Noi day Y HET soc/auth_soc_top.v (cung ten instance u_cpu, u_auth,
//  u_ascon, u_trust; cung tham so), chi khac:
//    * u_mem dung fpga_system_memory (ban BSRAM + $readmemh) thay cho
//      system_memory (mo hinh mo phong).
//    * Bus m_* duoc tach: 0x02xx_xxxx -> fpga_uart (ngoai vi DUY NHAT),
//      con lai -> fpga_system_memory.
//    * uart_src_mux chon nguon cho uart_tx: CPU (binh thuong) hoac
//      auth_fault_uart_reporter (khi co loi).
//    * uart_rx (chan 42 <- TXD cua CP2102) dua byte vao FIFO RX cua
//      fpga_uart (0x0200_0018) -> firmware doc lenh rw/ww/... tu PC.
//    * Them power-on reset + nut reset, auth_fault_uart_reporter.
//
//  KHONG sua bat ky khoi nao cua thiet ke goc:
//      ascon/*.v, authenticated_memory/*.v, trusted_key/*.v,
//      auth_sim/picorv32.v  -- duoc CHEP NGUYEN BAN vao rtl/ (khong sua).
//
//  KEY_CODE / PROGRAM_ID / IMAGE_ID / G / T phai trung voi tham so
//  auth_signer.py (firmware/make_variants.py dung dung mac dinh nay).
//======================================================================
module tangnano20k_top #(
    parameter [127:0] KEY_CODE   = 128'h000102030405060708090A0B0C0D0E0F,
    parameter [63:0]  PROGRAM_ID = 64'd1,
    parameter [63:0]  IMAGE_ID   = 64'd1,
    parameter integer G          = 4,
    parameter integer T          = 128,
    parameter integer FAULT_HALT = 0,

    parameter CODE_INIT = "../../sw/firm/active/code.hex",
    parameter TAG_INIT  = "../../sw/firm/active/tag.hex",
    parameter DATA_INIT = "../../sw/firm/active/data.hex",

    parameter integer CLK_HZ      = 27_000_000,
    parameter integer UART_BAUD   = 115200,
    parameter integer REPORT_BITS = 26,
    parameter integer POR_BITS    = 16          // power-on reset ~2.4 ms
)(
    input  wire       sys_clk,      // chan 4, 27 MHz
    input  wire       btn_rst,      // chan 88, nut S1 -> reset (cuc tinh tu nhan)
    output wire       uart_tx,      // chan 41 -> RXD cua CP2102 (xem tangnano20k.cst)
    input  wire       uart_rx       // chan 42 <- TXD cua CP2102
);

// ---------------------------------------------------------------- reset
// Power-on reset + nut S1. Khong gia dinh cuc tinh cua nut: sau power-on
// reset, muc dang doc duoc coi la "nha"; bat ky luc nao chan nut khac muc
// do thi giu reset. Cac khoi goc dung reset bat dong bo active-low, nen ta
// dua vao tin hieu da dong bo.
reg [1:0]          rs     = 2'b00;
reg [POR_BITS-1:0] por    = {POR_BITS{1'b0}};
reg                armed  = 1'b0;
reg                idle_l = 1'b0;
reg [7:0]          rcnt   = 8'd0;
reg                rst_n  = 1'b0;

wire btn_pressed = armed && (rs[1] != idle_l);

always @(posedge sys_clk) begin
    rs <= {rs[0], btn_rst};
    if (!por[POR_BITS-1])  por <= por + 1'b1;
    else if (!armed)       begin idle_l <= rs[1]; armed <= 1'b1; end

    if (!armed || btn_pressed) begin rcnt <= 8'd0; rst_n <= 1'b0; end
    else if (!rcnt[7])         begin rcnt <= rcnt + 8'd1; rst_n <= 1'b0; end
    else                       rst_n <= 1'b1;
end

wire clk = sys_clk;
wire trap, auth_fault;

// ======================= phan giong auth_soc_top =======================
// CPU <-> wrapper
wire        cpu_mem_valid, cpu_mem_instr, cpu_mem_ready;
wire [31:0] cpu_mem_addr, cpu_mem_wdata, cpu_mem_rdata;
wire [3:0]  cpu_mem_wstrb;
// wrapper <-> memory
wire        m_valid, m_ready;
wire [31:0] m_addr, m_wdata, m_rdata;
wire [3:0]  m_wstrb;
// wrapper <-> Ascon
wire [127:0] a_nonce, a_ad_data, a_tag;
wire [4:0]   a_ad_nbytes;
wire         a_start, a_ad_last, a_ad_valid, a_ad_ready, a_busy, a_done;
// trusted
wire [127:0] K_code;
wire [223:0] CFG;

picorv32 #(
    .COMPRESSED_ISA (0),
    .CATCH_ILLINSN  (1),
    .CATCH_MISALIGN (1),
    .ENABLE_IRQ     (0),
    .PROGADDR_RESET (32'h0000_0000),
    .STACKADDR      (32'h0002_1000)
) u_cpu (
    .clk       (clk),
    .resetn    (rst_n),
    .trap      (trap),
    .mem_valid (cpu_mem_valid),
    .mem_instr (cpu_mem_instr),
    .mem_ready (cpu_mem_ready),
    .mem_addr  (cpu_mem_addr),
    .mem_wdata (cpu_mem_wdata),
    .mem_wstrb (cpu_mem_wstrb),
    .mem_rdata (cpu_mem_rdata),
    .pcpi_wr   (1'b0),
    .pcpi_rd   (32'b0),
    .pcpi_wait (1'b0),
    .pcpi_ready(1'b0),
    .irq       (32'b0)
);

authenticated_memory_wrapper #(
    .G(G), .T(T), .FAULT_HALT(FAULT_HALT)
) u_auth (
    .clk(clk), .rst_n(rst_n),
    .cpu_mem_valid(cpu_mem_valid), .cpu_mem_instr(cpu_mem_instr),
    .cpu_mem_addr(cpu_mem_addr), .cpu_mem_wdata(cpu_mem_wdata),
    .cpu_mem_wstrb(cpu_mem_wstrb),
    .cpu_mem_ready(cpu_mem_ready), .cpu_mem_rdata(cpu_mem_rdata),
    .m_ready(m_ready), .m_rdata(m_rdata),
    .m_valid(m_valid), .m_addr(m_addr), .m_wdata(m_wdata), .m_wstrb(m_wstrb),
    .a_ad_ready(a_ad_ready), .a_busy(a_busy), .a_done(a_done), .a_tag(a_tag),
    .a_nonce(a_nonce), .a_ad_data(a_ad_data), .a_ad_nbytes(a_ad_nbytes),
    .a_start(a_start), .a_ad_last(a_ad_last), .a_ad_valid(a_ad_valid),
    .cfg(CFG),
    .auth_fault(auth_fault)
);

ascon_top u_ascon (
    .clk(clk), .rst_n(rst_n),
    .start(a_start),
    .ad_empty(1'b0),
    .key_d(K_code), .nonce_d(a_nonce),
    .ad_data(a_ad_data), .ad_nbytes(a_ad_nbytes), .ad_last(a_ad_last),
    .ad_valid(a_ad_valid), .ad_ready(a_ad_ready),
    .tag_out(a_tag), .done(a_done), .busy(a_busy)
);

trusted_key_and_context #(
    .KEY_CODE(KEY_CODE), .PROGRAM_ID(PROGRAM_ID), .IMAGE_ID(IMAGE_ID)
) u_trust (
    .K_code(K_code), .CFG(CFG)
);

// ======================= phan moi cho FPGA =============================
// Tach bus m_*: UART o 0x02xx_xxxx, con lai la memory
wire        sel_uart = (m_addr[31:24] == 8'h02);
wire        mem_ready_i, uart_ready;
wire [31:0] mem_rdata_i, uart_rdata;

fpga_system_memory #(
    .CODE_INIT(CODE_INIT), .TAG_INIT(TAG_INIT), .DATA_INIT(DATA_INIT)
) u_mem (
    .clk(clk), .rst_n(rst_n),
    .mem_valid(m_valid && !sel_uart), .mem_wdata(m_wdata), .mem_wstrb(m_wstrb),
    .mem_addr(m_addr), .mem_rdata(mem_rdata_i), .mem_ready(mem_ready_i)
);

wire       rep_we, rep_active, rep_busy;
wire [7:0] rep_data;
wire       cpu_tx_we, cpu_tx_busy;
wire [7:0] cpu_tx_data;
wire       tx_we, tx_busy;
wire [7:0] tx_data;
wire       rx_valid;
wire [7:0] rx_data;

// Bo thu UART: PC -> FPGA (chan 42)
uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(UART_BAUD)) u_uart_rx (
    .clk(clk), .resetn(rst_n),
    .rx(uart_rx), .data(rx_data), .valid(rx_valid)
);

// Thanh ghi UART cho CPU (0x0200_0010 TX / 0x0200_0014 status / 0x0200_0018 RX)
fpga_uart u_uart_regs (
    .clk(clk), .rst_n(rst_n),
    .mem_valid(m_valid && sel_uart), .mem_wdata(m_wdata), .mem_wstrb(m_wstrb),
    .mem_addr(m_addr), .mem_rdata(uart_rdata), .mem_ready(uart_ready),
    .cpu_we(cpu_tx_we), .cpu_data(cpu_tx_data), .busy(cpu_tx_busy),
    .rx_valid(rx_valid), .rx_data(rx_data)
);

// MUX truoc UART: co loi -> fault reporter, binh thuong -> CPU
uart_src_mux u_uart_mux (
    .fault_sel(rep_active),
    .cpu_we(cpu_tx_we), .cpu_data(cpu_tx_data), .cpu_busy(cpu_tx_busy),
    .flt_we(rep_we),    .flt_data(rep_data),    .flt_busy(rep_busy),
    .tx_we(tx_we), .tx_data(tx_data), .tx_busy(tx_busy)
);

uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(UART_BAUD)) u_uart (
    .clk(clk), .resetn(rst_n),
    .data(tx_data), .we(tx_we), .busy(tx_busy), .tx(uart_tx)
);

assign m_ready = mem_ready_i | uart_ready;
assign m_rdata = mem_ready_i ? mem_rdata_i : uart_rdata;

// Ghi lai request vua hoan tat, de biet request nao lam auth_fault len 1.
// (FAULT_HALT = 0: wrapper tra ready o state FAULT, auth_fault len 1 o
//  chu ky ngay sau.  FAULT_HALT = 1: CPU van dang giu request.)
reg [31:0] last_addr;
reg        last_instr, last_write, fault_d;
reg [31:0] f_addr;
reg [1:0]  f_code;

wire [31:0] cur_addr  = cpu_mem_valid ? cpu_mem_addr        : last_addr;
wire        cur_instr = cpu_mem_valid ? cpu_mem_instr       : last_instr;
wire        cur_write = cpu_mem_valid ? (|cpu_mem_wstrb)    : last_write;
wire        cur_incode = (cur_addr <= 32'h0000_1FFF);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        last_addr <= 32'b0; last_instr <= 1'b0; last_write <= 1'b0;
        fault_d <= 1'b0; f_addr <= 32'b0; f_code <= 2'd0;
    end else begin
        if (cpu_mem_valid && cpu_mem_ready) begin
            last_addr  <= cpu_mem_addr;
            last_instr <= cpu_mem_instr;
            last_write <= |cpu_mem_wstrb;
        end
        fault_d <= auth_fault;
        if (auth_fault && !fault_d) begin
            f_addr <= cur_addr;
            f_code <= cur_write ? 2'd3 : (cur_instr && cur_incode) ? 2'd1 : 2'd2;
        end
    end
end

auth_fault_uart_reporter #(.REPEAT_BITS(REPORT_BITS)) u_rep (
    .clk(clk), .rst_n(rst_n),
    .fault(fault_d),                 // tre 1 chu ky: f_addr/f_code da chot
    .code(f_code), .addr(f_addr), .trap(trap),
    .uart_busy(rep_busy),
    .uart_we(rep_we), .uart_data(rep_data),
    .active(rep_active)
);

endmodule
