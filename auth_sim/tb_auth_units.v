`timescale 1ns/1ps
// tb_auth_units.v -- unit test cho tung khoi con cua authenticated_memory_wrapper.
// Moi khoi in "[PASS]/[FAIL] <ten>"; cuoi cung in "UNIT errors = N".
// Cau hinh: G = 4, T = 128, CODE 0x0000_0000..0x0000_1FFF, TAG_BASE 0x0001_0000.
module tb_auth_units;
localparam integer G = 4, T = 128;

reg clk = 0, rst_n = 0;
always #5 clk = ~clk;
integer errs = 0, blk_err;

task check32(input [255:0] name, input [127:0] got, input [127:0] exp);
    if (got !== exp) begin
        errs = errs + 1; blk_err = blk_err + 1;
        $display("   sai %0s: got %h exp %h", name, got, exp);
    end
endtask
task report(input [255:0] name);
    $display("[%s] %0s", (blk_err == 0) ? "PASS" : "FAIL", name);
endtask

localparam [223:0] CFG = {64'd1, 64'd1, 32'h0000_0000, 32'h0000_1FFF, 32'h0001_0000};

// ------------------------------------------------ auth_cfg_decode
wire [63:0] pid, iid; wire [31:0] cb, cl, tb, tl;
auth_cfg_decode #(.G(G), .T(T)) u_cfg (.cfg(CFG), .program_id(pid), .image_id(iid),
    .code_base(cb), .code_limit(cl), .tag_base(tb), .tag_limit(tl));

// ------------------------------------------------ auth_addr_check
reg [31:0] ck_addr; reg [3:0] ck_wstrb; wire ck_in_code, ck_wp;
auth_addr_check u_chk (.addr(ck_addr), .wstrb(ck_wstrb), .code_base(cb), .code_limit(cl),
    .tag_base(tb), .tag_limit(tl), .in_code(ck_in_code), .wr_protected(ck_wp));

// ------------------------------------------------ auth_addr_gen
reg [31:0] ag_addr; reg [3:0] ag_cnt; wire [31:0] ag_blk, ag_caddr, ag_taddr; wire [2:0] ag_off;
auth_addr_gen #(.G(G), .T(T)) u_agen (.req_addr(ag_addr), .code_base(cb), .tag_base(tb),
    .cnt(ag_cnt), .blk_base(ag_blk), .word_off(ag_off), .code_addr(ag_caddr), .tag_addr(ag_taddr));

// ------------------------------------------------ auth_counter
reg c_clr = 0, c_inc = 0; wire [3:0] c_cnt;
auth_counter #(.W(4)) u_cnt (.clk(clk), .rst_n(rst_n), .clr(c_clr), .inc(c_inc), .cnt(c_cnt));

// ------------------------------------------------ auth_code_buffer
reg b_we = 0, b_inv = 0, b_set = 0; reg [3:0] b_widx = 0; reg [31:0] b_wdata = 0, b_setblk = 0, b_look = 0;
reg [2:0] b_ridx = 0; wire b_hit; wire [31:0] b_rdata; wire [32*G-1:0] b_flat;
auth_code_buffer #(.G(G)) u_buf (.clk(clk), .rst_n(rst_n), .we(b_we), .widx(b_widx), .wdata(b_wdata),
    .inv(b_inv), .set(b_set), .set_blk(b_setblk), .lookup_blk(b_look), .rd_idx(b_ridx),
    .hit(b_hit), .rdata(b_rdata), .code_flat(b_flat));

// ------------------------------------------------ auth_tag_reg
reg t_we = 0; reg [3:0] t_widx = 0; reg [31:0] t_wdata = 0; wire [T-1:0] t_q;
auth_tag_reg #(.T(T)) u_tag (.clk(clk), .rst_n(rst_n), .we(t_we), .widx(t_widx), .wdata(t_wdata), .tag_q(t_q));

// ------------------------------------------------ auth_ad_packer
reg [1:0] p_beat = 0; wire [127:0] p_data; wire [4:0] p_nb; wire p_last;
auth_ad_packer #(.G(G)) u_pack (.blk_base(32'h0000_0010),
    .code_flat({32'h1111_1111, 32'h2222_2222, 32'h3333_3333, 32'h4444_4444}),
    .beat(p_beat), .ad_data(p_data), .ad_nbytes(p_nb), .last(p_last));

// ------------------------------------------------ auth_tag_compare
reg [127:0] cmp_tag; reg [T-1:0] cmp_ref; wire cmp_ok;
auth_tag_compare #(.T(T)) u_cmp (.a_tag(cmp_tag), .tag_ref(cmp_ref), .tag_ok(cmp_ok));

// ------------------------------------------------ auth_fault_reg
reg f_set = 0; wire f_q;
auth_fault_reg u_fault (.clk(clk), .rst_n(rst_n), .set(f_set), .fault(f_q));

// ------------------------------------------------ auth_mem_mux / auth_resp_mux
reg mm_en; reg [1:0] mm_sel; wire mm_valid; wire [31:0] mm_addr, mm_wdata; wire [3:0] mm_wstrb;
auth_mem_mux u_mmux (.en(mm_en), .sel(mm_sel), .code_addr(32'hC0DE_0000), .tag_addr(32'h7A90_0000),
    .req_addr(32'hDA7A_0000), .req_wdata(32'h1234_5678), .req_wstrb(4'b0011),
    .m_valid(mm_valid), .m_addr(mm_addr), .m_wdata(mm_wdata), .m_wstrb(mm_wstrb));
reg rm_en; reg [1:0] rm_sel; wire rm_ready; wire [31:0] rm_rdata;
auth_resp_mux u_rmux (.en(rm_en), .sel(rm_sel), .buf_rdata(32'hB0F0_B0F0), .m_rdata(32'hAE11_AE11),
    .cpu_mem_ready(rm_ready), .cpu_mem_rdata(rm_rdata));

// ------------------------------------------------ auth_controller
reg k_valid = 0, k_instr = 0, k_incode = 0, k_wp = 0, k_hit = 0, k_mready = 0;
reg k_busy = 0, k_adready = 0, k_done = 0, k_last = 0, k_tagok = 0; reg [3:0] k_cnt = 0;
wire k_req_we, k_cnt_clr, k_cnt_inc, k_beat_clr, k_beat_inc, k_code_we, k_tag_we;
wire k_buf_inv, k_buf_set, k_fault_set, k_m_en, k_resp_en, k_start, k_adv;
wire [1:0] k_m_sel, k_resp_sel; wire [3:0] k_state;
wire k_if, k_ih, k_iv, k_id, k_ifa, k_is;
auth_controller #(.G(G), .T(T), .FAULT_HALT(0)) u_ctrl (
    .clk(clk), .rst_n(rst_n), .cpu_mem_valid(k_valid), .req_instr(k_instr),
    .in_code(k_incode), .wr_protected(k_wp), .buf_hit(k_hit), .m_ready(k_mready), .cnt(k_cnt),
    .a_busy(k_busy), .a_ad_ready(k_adready), .a_done(k_done), .last_beat(k_last), .tag_ok(k_tagok),
    .req_we(k_req_we), .cnt_clr(k_cnt_clr), .cnt_inc(k_cnt_inc), .beat_clr(k_beat_clr),
    .beat_inc(k_beat_inc), .code_we(k_code_we), .tag_we(k_tag_we), .buf_inv(k_buf_inv),
    .buf_set(k_buf_set), .fault_set(k_fault_set), .m_en(k_m_en), .m_sel(k_m_sel),
    .resp_en(k_resp_en), .resp_sel(k_resp_sel), .a_start(k_start), .a_ad_valid(k_adv),
    .inc_fetch(k_if), .inc_hit(k_ih), .inc_verify(k_iv), .inc_data(k_id),
    .inc_fault(k_ifa), .inc_stall(k_is), .state_dbg(k_state));

// state code (khop auth_controller)
localparam [3:0] S_IDLE=0, S_CHECK=1, S_RCODE=2, S_RTAG=3, S_START=4, S_SEND=5,
                 S_WAIT=6, S_CMP=7, S_RESP=8, S_FAULT=9, S_MEM=10;

task step; begin @(posedge clk); #1; end endtask

integer i;
initial begin
    #12 rst_n = 1; #1;

    // ---- cfg_decode
    blk_err = 0;
    check32("program_id", pid, 1); check32("image_id", iid, 1);
    check32("code_base", cb, 32'h0); check32("code_limit", cl, 32'h1FFF);
    check32("tag_base", tb, 32'h10000); check32("tag_limit", tl, 32'h11FFF);   // 512 block x 16 B
    report("auth_cfg_decode");

    // ---- addr_check
    blk_err = 0;
    ck_wstrb = 0;
    ck_addr = 32'h0000_0000; #1 check32("in_code @0", ck_in_code, 1);
    ck_addr = 32'h0000_1FFC; #1 check32("in_code @1FFC", ck_in_code, 1);
    ck_addr = 32'h0000_2000; #1 check32("in_code @2000", ck_in_code, 0);
    ck_addr = 32'h0000_0002; #1 check32("in_code misaligned", ck_in_code, 0);
    ck_addr = 32'h0002_0100; #1 check32("in_code data RAM", ck_in_code, 0);
    ck_addr = 32'h0000_0010; ck_wstrb = 4'hF; #1 check32("wr_protected code", ck_wp, 1);
    ck_addr = 32'h0001_0004; #1 check32("wr_protected tag", ck_wp, 1);
    ck_addr = 32'h0002_0000; #1 check32("wr_protected data", ck_wp, 0);
    ck_addr = 32'h0000_1FFF; #1 check32("bien code_limit", ck_wp, 1);
    ck_addr = 32'h0001_1FFF; #1 check32("bien tag_limit", ck_wp, 1);
    ck_addr = 32'h0001_2000; #1 check32("sau tag_limit", ck_wp, 0);
    ck_addr = 32'h0000_0010; ck_wstrb = 4'h0; #1 check32("read code ok", ck_wp, 0);
    report("auth_addr_check");

    // ---- addr_gen
    blk_err = 0;
    ag_addr = 32'h0000_0014; ag_cnt = 0; #1
    check32("blk_base", ag_blk, 32'h10); check32("word_off", ag_off, 1);
    ag_cnt = 2; #1 check32("code_addr cnt2", ag_caddr, 32'h18);
    ag_cnt = 1; #1 check32("tag_addr blk1 cnt1", ag_taddr, 32'h10014);   // 0x10000 + 1*16 + 4
    ag_addr = 32'h0000_003C; ag_cnt = 3; #1
    check32("blk_base 3C", ag_blk, 32'h30); check32("word_off 3C", ag_off, 3);
    check32("tag_addr blk3 cnt3", ag_taddr, 32'h1003C);
    report("auth_addr_gen");

    // ---- counter
    blk_err = 0;
    c_inc = 1; step; step; step; c_inc = 0; check32("cnt after 3 inc", c_cnt, 3);
    c_clr = 1; c_inc = 1; step; c_clr = 0; c_inc = 0; check32("clr uu tien", c_cnt, 0);
    report("auth_counter");

    // ---- code_buffer
    blk_err = 0;
    b_we = 1;
    for (i = 0; i < G; i = i + 1) begin b_widx = i; b_wdata = 32'hA000_0000 + i; step; end
    b_we = 0;
    check32("code_flat", b_flat, {32'hA000_0000, 32'hA000_0001, 32'hA000_0002, 32'hA000_0003});
    b_ridx = 2; #1 check32("rdata idx2", b_rdata, 32'hA000_0002);
    b_look = 32'h40; #1 check32("hit truoc set", b_hit, 0);
    b_set = 1; b_setblk = 32'h40; step; b_set = 0; check32("hit sau set", b_hit, 1);
    b_look = 32'h50; #1 check32("hit block khac", b_hit, 0);
    b_look = 32'h40; b_inv = 1; b_set = 1; step; b_inv = 0; b_set = 0;
    check32("inv uu tien set", b_hit, 0);
    report("auth_code_buffer");

    // ---- tag_reg
    blk_err = 0;
    t_we = 1;
    for (i = 0; i < T/32; i = i + 1) begin t_widx = i; t_wdata = 32'h1111_1111 * (i + 1); step; end
    t_we = 0;
    check32("tag_q", t_q, {32'h1111_1111, 32'h2222_2222, 32'h3333_3333, 32'h4444_4444});
    report("auth_tag_reg");

    // ---- ad_packer  (G=4: AD = 20 byte -> beat0 16 byte, beat1 4 byte)
    blk_err = 0;
    p_beat = 0; #1
    check32("beat0 data", p_data, {32'h0000_0010, 32'h1111_1111, 32'h2222_2222, 32'h3333_3333});
    check32("beat0 nbytes", p_nb, 16); check32("beat0 last", p_last, 0);
    p_beat = 1; #1
    check32("beat1 data", p_data, {32'h4444_4444, 96'b0});
    check32("beat1 nbytes", p_nb, 4); check32("beat1 last", p_last, 1);
    report("auth_ad_packer");

    // ---- tag_compare
    blk_err = 0;
    cmp_tag = 128'hDEAD_BEEF_0011_2233_4455_6677_8899_AABB; cmp_ref = cmp_tag; #1
    check32("tag bang nhau", cmp_ok, 1);
    cmp_ref = cmp_tag ^ 128'h1; #1 check32("lech 1 bit", cmp_ok, 0);
    report("auth_tag_compare");

    // ---- fault_reg
    blk_err = 0;
    check32("fault sau reset", f_q, 0);
    f_set = 1; step; f_set = 0; step; step; check32("sticky", f_q, 1);
    report("auth_fault_reg");

    // ---- mem_mux / resp_mux
    blk_err = 0;
    mm_en = 0; mm_sel = 2; #1 check32("m_valid tat", mm_valid, 0); check32("m_wstrb tat", mm_wstrb, 0);
    mm_en = 1; mm_sel = 0; #1 check32("sel code", mm_addr, 32'hC0DE_0000); check32("code wstrb", mm_wstrb, 0);
    mm_sel = 1; #1 check32("sel tag", mm_addr, 32'h7A90_0000);
    mm_sel = 2; #1 check32("sel data addr", mm_addr, 32'hDA7A_0000);
    check32("sel data wdata", mm_wdata, 32'h1234_5678); check32("sel data wstrb", mm_wstrb, 4'b0011);
    rm_en = 0; rm_sel = 0; #1 check32("ready tat", rm_ready, 0);
    rm_en = 1; #1 check32("resp buf", rm_rdata, 32'hB0F0_B0F0);
    rm_sel = 1; #1 check32("resp mem", rm_rdata, 32'hAE11_AE11);
    rm_sel = 2; #1 check32("resp zero", rm_rdata, 32'h0);
    report("auth_mem_mux + auth_resp_mux");

    // ---- controller: fetch miss -> verify dung -> RESPONSE
    blk_err = 0;
    step;   // can thoi diem ngay sau canh clock
    check32("reset -> IDLE", k_state, S_IDLE);
    k_valid = 1; k_instr = 1; k_incode = 1; #1 check32("IDLE req_we", k_req_we, 1);
    step; k_valid = 0; check32("-> CHECK", k_state, S_CHECK);
    #1 check32("CHECK buf_inv (miss)", k_buf_inv, 1);
    step; check32("-> READ_CODE", k_state, S_RCODE);
    #1 check32("READ_CODE m_en", k_m_en, 1); check32("READ_CODE m_sel", k_m_sel, 0);
    k_mready = 1; k_cnt = 3; #1 check32("word cuoi: cnt_clr", k_cnt_clr, 1);
    step; k_cnt = 0; check32("-> READ_TAG", k_state, S_RTAG);
    #1 check32("READ_TAG m_sel", k_m_sel, 1); check32("READ_TAG tag_we", k_tag_we, 1);
    k_cnt = 3; step; k_mready = 0; check32("-> START_ASCON", k_state, S_START);
    check32("a_start Moore", k_start, 1);
    step; check32("-> SEND_AD", k_state, S_SEND); check32("a_ad_valid Moore", k_adv, 1);
    k_adready = 1; k_last = 0; #1 check32("beat_inc", k_beat_inc, 1);
    k_last = 1; step; k_adready = 0; check32("-> WAIT_ASCON", k_state, S_WAIT);
    step; check32("cho a_done", k_state, S_WAIT);
    k_done = 1; step; k_done = 0; check32("-> COMPARE", k_state, S_CMP);
    k_tagok = 1; #1 check32("buf_set", k_buf_set, 1);
    step; check32("-> RESPONSE", k_state, S_RESP);
    check32("resp_en", k_resp_en, 1); check32("resp_sel buf", k_resp_sel, 0);
    step; check32("-> IDLE", k_state, S_IDLE);
    // fetch ngoai vung CODE -> FAULT -> tra 0
    k_valid = 1; k_incode = 0; step; k_valid = 0; step;
    check32("ngoai CODE -> FAULT", k_state, S_FAULT);
    check32("FAULT fault_set", k_fault_set, 1); check32("FAULT resp zero", k_resp_sel, 2);
    step; check32("FAULT -> IDLE", k_state, S_IDLE);
    // data write vao CODE -> FAULT; data read -> MEMORY_ACCESS
    k_valid = 1; k_instr = 0; k_wp = 1; step; k_valid = 0; step;
    check32("ghi CODE -> FAULT", k_state, S_FAULT);
    step; k_valid = 1; k_wp = 0; step; k_valid = 0; step;
    check32("doc data -> MEM", k_state, S_MEM);
    k_mready = 1; #1 check32("MEM resp_sel mem", k_resp_sel, 1);
    step; k_mready = 0; check32("MEM -> IDLE", k_state, S_IDLE);
    report("auth_controller");

    $display("UNIT errors = %0d", errs);
    $finish;
end
endmodule
