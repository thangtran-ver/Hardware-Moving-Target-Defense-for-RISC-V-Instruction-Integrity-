// ascon_mac_top.v -- integration wrapper (controller + datapath) used for
// verification. Wiring follows tb/tb_mac.v; the only additions are the
// controller and ascon_tag_output, which tb_mac.v does not instantiate.
//
// AD interface (valid/ready):
//   * ad_data is MSB-aligned: first byte in [127:120]; bytes beyond
//     ad_nbytes are don't-care (masked by the padding logic).
//   * every beat except the last must carry 16 bytes (ad_last = 0);
//     the last beat carries 1..16 bytes, or 0 bytes as a pure terminator
//     after at least one full beat.
//   * empty AD must be signalled with ad_empty = 1 at start.
module ascon_mac_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         ad_empty,
    input  wire [127:0] key,
    input  wire [127:0] nonce,
    input  wire         ad_valid,
    output wire         ad_ready,
    input  wire [127:0] ad_data,
    input  wire [4:0]   ad_nbytes,
    input  wire         ad_last,
    output wire [127:0] tag,
    output wire         busy,
    output wire         done
);

wire kn_we, ad_we, state_we, tag_we, p8_start, p12_start, p8_done, p12_done;
wire [2:0] sel;
wire [1:0] pad_sel;
wire [4:0] nbytes_q;
wire       last_q;

wire [63:0]  K0, K1, N0, N1;
wire [319:0] STAGE, NEXT, D_INIT, D_POST, D_FINAL;
wire [63:0]  S0 = STAGE[319:256], S1 = STAGE[255:192], S2 = STAGE[191:128],
             S3 = STAGE[127:64],  S4 = STAGE[63:0];
wire [127:0] blk;
wire [63:0]  a0, a1, a2, a3, a4, q0, q1, q2, q3, q4, r0, r1, r2, r3, r4;
wire         p8_busy, p12_busy;

ascon_controller u_ctrl (
    .clk(clk), .rst_n(rst_n), .start(start), .ad_empty(ad_empty),
    .ad_valid(ad_valid), .nbytes_q(nbytes_q), .last_q(last_q),
    .p8_done(p8_done), .p12_done(p12_done),
    .kn_we(kn_we), .ad_we(ad_we), .state_we(state_we), .tag_we(tag_we),
    .sel(sel), .pad_sel(pad_sel), .p8_start(p8_start), .p12_start(p12_start),
    .ad_ready(ad_ready), .busy(busy), .done(done));

ascon_key_nonce_reg u_kn (
    .clk(clk), .rst_n(rst_n), .we(kn_we), .key_d(key), .nonce_d(nonce),
    .K0(K0), .K1(K1), .N0(N0), .N1(N1));

ascon_initial_state u_init (.K0(K0), .K1(K1), .N0(N0), .N1(N1), .D_INIT(D_INIT));

ascon_post_init u_post (.S0(S0), .S1(S1), .S2(S2), .S3(S3), .S4(S4),
    .K0(K0), .K1(K1), .D_POST(D_POST));

ascon_ad_buffer_padding u_buf (
    .clk(clk), .rst_n(rst_n), .data_d(ad_data), .nbytes_d(ad_nbytes),
    .last_d(ad_last), .we(ad_we), .pad_sel(pad_sel),
    .block_out(blk), .nbytes_q(nbytes_q), .last_q(last_q));

ascon_ad_absorb u_abs (.AD_BLOCK(blk), .S0(S0), .S1(S1), .S2(S2), .S3(S3), .S4(S4),
    .S0_new(a0), .S1_new(a1), .S2_new(a2), .S3_new(a3), .S4_new(a4));

ascon_final_pre u_fin (.S0(S0), .S1(S1), .S2(S2), .S3(S3), .S4(S4),
    .K0(K0), .K1(K1), .D_FINAL(D_FINAL));

ascon_p8 u_p8 (.clk(clk), .rst_n(rst_n), .start(p8_start),
    .x0(S0), .x1(S1), .x2(S2), .x3(S3), .x4(S4),
    .y0(q0), .y1(q1), .y2(q2), .y3(q3), .y4(q4), .busy(p8_busy), .done(p8_done));

ascon_p12 u_p12 (.clk(clk), .rst_n(rst_n), .start(p12_start),
    .x0(S0), .x1(S1), .x2(S2), .x3(S3), .x4(S4),
    .y0(r0), .y1(r1), .y2(r2), .y3(r3), .y4(r4), .busy(p12_busy), .done(p12_done));

ascon_state_mux u_mux (.sel(sel), .D_INIT(D_INIT), .D_POST(D_POST),
    .D_AD({a0, a1, a2, a3, a4}), .D_FINAL(D_FINAL),
    .P8_OUT({q0, q1, q2, q3, q4}), .P12_OUT({r0, r1, r2, r3, r4}),
    .NEXT_STAGE(NEXT));

ascon_state_reg u_state (.clk(clk), .rst_n(rst_n), .we(state_we),
    .NEXT_STAGE(NEXT), .STAGE(STAGE));

ascon_tag_output u_tag (.clk(clk), .rst_n(rst_n), .we(tag_we),
    .S3(S3), .S4(S4), .K0(K0), .K1(K1), .tag(tag));

endmodule
