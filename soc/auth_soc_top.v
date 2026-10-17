// auth_soc_top.v -- PicoRV32 + Authenticated Memory + System Memory + Ascon-128a
// Noi day theo block diagram baseline. Dung lam top mo phong / Quartus.
module auth_soc_top #(
    parameter [127:0] KEY_CODE   = 128'h000102030405060708090A0B0C0D0E0F,
    parameter [63:0]  PROGRAM_ID = 64'd1,
    parameter [63:0]  IMAGE_ID   = 64'd1,
    parameter integer G          = 4,
    parameter integer T          = 128,
    parameter integer FAULT_HALT = 0
)(
    input  wire clk,
    input  wire rst_n,
    output wire trap,         // PicoRV32 trap (vd. lenh 0x00000000 khi fault)
    output wire auth_fault    // sticky
);

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

system_memory u_mem (
    .clk(clk), .rst_n(rst_n),
    .mem_valid(m_valid), .mem_wdata(m_wdata), .mem_wstrb(m_wstrb),
    .mem_addr(m_addr), .mem_rdata(m_rdata), .mem_ready(m_ready)
);

ascon_top u_ascon (
    .clk(clk), .rst_n(rst_n),
    .start(a_start),
    .ad_empty(1'b0),            // AD luon khac rong
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

endmodule
