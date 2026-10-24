
module authenticated_memory_wrapper #(
    parameter integer G          = 4,   // so word moi block: 1, 2, 4, 8
    parameter integer T          = 128, // so bit tag: 32, 64, 128
    parameter integer FAULT_HALT = 0    
)(
    input  wire         clk,
    input  wire         rst_n,
//cpu
    input  wire         cpu_mem_valid,
    input  wire         cpu_mem_instr,
    input  wire [31:0]  cpu_mem_addr,
    input  wire [31:0]  cpu_mem_wdata,
    input  wire [3:0]   cpu_mem_wstrb,
    output wire         cpu_mem_ready,
    output wire [31:0]  cpu_mem_rdata,
//u4 system memory
    input  wire         m_ready,
    input  wire [31:0]  m_rdata,
    output wire         m_valid,
    output wire [31:0]  m_addr,
    output wire [31:0]  m_wdata,
    output wire [3:0]   m_wstrb,
//u3 ascon
    input  wire         a_ad_ready,
    input  wire         a_busy,
    input  wire         a_done,
    input  wire [127:0] a_tag,
    output wire [127:0] a_nonce,
    output wire [127:0] a_ad_data,
    output wire [4:0]   a_ad_nbytes,
    output wire         a_start,
    output wire         a_ad_last,
    output wire         a_ad_valid,
//u5 trusted key and context
    input  wire [223:0] cfg,
    output wire         auth_fault
);

wire [63:0]  program_id, image_id;
wire [31:0]  code_base, code_limit, tag_base, tag_limit;

wire         req_instr;
wire [31:0]  req_addr, req_wdata;
wire [3:0]   req_wstrb;

wire         in_code, wr_protected;
wire [31:0]  blk_base, code_addr, tag_addr;
wire [2:0]   word_off;

wire [3:0]   cnt;
wire [1:0]   beat;
wire         buf_hit;
wire [31:0]  buf_rdata;
wire [32*G-1:0] code_flat;
wire [T-1:0] tag_q;
wire         last_beat, tag_ok;

wire req_we, cnt_clr, cnt_inc, beat_clr, beat_inc, code_we, tag_we;
wire buf_inv, buf_set, fault_set, m_en, resp_en;
wire [1:0] m_sel, resp_sel;
wire inc_fetch, inc_hit, inc_verify, inc_data, inc_fault, inc_stall;
wire [3:0] state_dbg;

wire [31:0] perf_fetch, perf_hit, perf_verify, perf_data, perf_fault, perf_stall;

assign a_nonce = {program_id, image_id};

auth_controller #(.G(G), .T(T), .FAULT_HALT(FAULT_HALT)) u_ctrl (
    .clk(clk), .rst_n(rst_n),
    .cpu_mem_valid(cpu_mem_valid), .req_instr(req_instr),
    .in_code(in_code), .wr_protected(wr_protected), .buf_hit(buf_hit),
    .m_ready(m_ready), .cnt(cnt),
    .a_busy(a_busy), .a_ad_ready(a_ad_ready), .a_done(a_done),
    .last_beat(last_beat), .tag_ok(tag_ok),
    .req_we(req_we), .cnt_clr(cnt_clr), .cnt_inc(cnt_inc),
    .beat_clr(beat_clr), .beat_inc(beat_inc),
    .code_we(code_we), .tag_we(tag_we), .buf_inv(buf_inv), .buf_set(buf_set),
    .fault_set(fault_set), .m_en(m_en), .m_sel(m_sel),
    .resp_en(resp_en), .resp_sel(resp_sel),
    .a_start(a_start), .a_ad_valid(a_ad_valid),
    .inc_fetch(inc_fetch), .inc_hit(inc_hit), .inc_verify(inc_verify),
    .inc_data(inc_data), .inc_fault(inc_fault), .inc_stall(inc_stall),
    .state_dbg(state_dbg)
);

auth_cfg_decode #(.G(G), .T(T)) u_cfg (
    .cfg(cfg), .program_id(program_id), .image_id(image_id),
    .code_base(code_base), .code_limit(code_limit),
    .tag_base(tag_base), .tag_limit(tag_limit)
);

auth_req_reg u_req (
    .clk(clk), .rst_n(rst_n), .we(req_we),
    .instr_d(cpu_mem_instr), .addr_d(cpu_mem_addr),
    .wdata_d(cpu_mem_wdata), .wstrb_d(cpu_mem_wstrb),
    .instr_q(req_instr), .addr_q(req_addr),
    .wdata_q(req_wdata), .wstrb_q(req_wstrb)
);

auth_addr_check u_chk (
    .addr(req_addr), .wstrb(req_wstrb),
    .code_base(code_base), .code_limit(code_limit),
    .tag_base(tag_base), .tag_limit(tag_limit),
    .in_code(in_code), .wr_protected(wr_protected)
);

auth_addr_gen #(.G(G), .T(T)) u_agen (
    .req_addr(req_addr), .code_base(code_base), .tag_base(tag_base), .cnt(cnt),
    .blk_base(blk_base), .word_off(word_off),
    .code_addr(code_addr), .tag_addr(tag_addr)
);

auth_counter #(.W(4)) u_cnt (
    .clk(clk), .rst_n(rst_n), .clr(cnt_clr), .inc(cnt_inc), .cnt(cnt)
);

auth_counter #(.W(2)) u_beat (
    .clk(clk), .rst_n(rst_n), .clr(beat_clr), .inc(beat_inc), .cnt(beat)
);

auth_code_buffer #(.G(G)) u_buf (
    .clk(clk), .rst_n(rst_n),
    .we(code_we), .widx(cnt), .wdata(m_rdata),
    .inv(buf_inv), .set(buf_set), .set_blk(blk_base),
    .lookup_blk(blk_base), .rd_idx(word_off),
    .hit(buf_hit), .rdata(buf_rdata), .code_flat(code_flat)
);

auth_tag_reg #(.T(T)) u_tag (
    .clk(clk), .rst_n(rst_n), .we(tag_we), .widx(cnt), .wdata(m_rdata),
    .tag_q(tag_q)
);

auth_ad_packer #(.G(G)) u_pack (
    .blk_base(blk_base), .code_flat(code_flat), .beat(beat),
    .ad_data(a_ad_data), .ad_nbytes(a_ad_nbytes), .last(last_beat)
);
assign a_ad_last = last_beat;

auth_tag_compare #(.T(T)) u_cmp (
    .a_tag(a_tag), .tag_ref(tag_q), .tag_ok(tag_ok)
);

auth_fault_reg u_fault (
    .clk(clk), .rst_n(rst_n), .set(fault_set), .fault(auth_fault)
);

auth_mem_mux u_mmux (
    .en(m_en), .sel(m_sel),
    .code_addr(code_addr), .tag_addr(tag_addr),
    .req_addr(req_addr), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
    .m_valid(m_valid), .m_addr(m_addr), .m_wdata(m_wdata), .m_wstrb(m_wstrb)
);

auth_resp_mux u_rmux (
    .en(resp_en), .sel(resp_sel), .buf_rdata(buf_rdata), .m_rdata(m_rdata),
    .cpu_mem_ready(cpu_mem_ready), .cpu_mem_rdata(cpu_mem_rdata)
);

auth_perf_counters u_perf (
    .clk(clk), .rst_n(rst_n),
    .inc_fetch(inc_fetch), .inc_hit(inc_hit), .inc_verify(inc_verify),
    .inc_data(inc_data), .inc_fault(inc_fault), .inc_stall(inc_stall),
    .perf_fetch(perf_fetch), .perf_hit(perf_hit), .perf_verify(perf_verify),
    .perf_data(perf_data), .perf_fault(perf_fault), .perf_stall(perf_stall)
);

endmodule
