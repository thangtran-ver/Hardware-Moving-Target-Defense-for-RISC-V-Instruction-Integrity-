// ascon_top.v -- Ascon-128a v1.2 (AD-only MAC: plaintext rong)
// Top = ascon_controller (FSM) + datapath dung 1 thanh ghi state chung.
//
// Giao tiep:
//   * start: xung 1 chu ky khi busy = 0; key_d/nonce_d/ad_empty duoc chot luc nay.
//   * ad_empty = 1 neu khong co AD (bat buoc, KHONG gui beat 0 byte thay the).
//   * AD theo valid/ready: ad_data canh trai (byte dau o [127:120]).
//     Moi beat tru beat cuoi phai du 16 byte (ad_last = 0).
//     Beat cuoi: 1..16 byte, hoac 0 byte lam terminator sau it nhat 1 beat day.
//   * done = 1 trong 1 chu ky; tag_out giu gia tri den lan tinh tiep theo.
module ascon_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         ad_empty,
    input  wire [127:0] key_d,
    input  wire [127:0] nonce_d,

    input  wire [127:0] ad_data,
    input  wire [4:0]   ad_nbytes,
    input  wire         ad_last,
    input  wire         ad_valid,
    output wire         ad_ready,

    output wire [127:0] tag_out,
    output wire         done,
    output wire         busy
);

// ------------------------------------------------------------ tin hieu dieu khien
wire        kn_we, ad_we, state_we, tag_we;
wire [2:0]  sel;
wire [1:0]  pad_sel;
wire        p8_start, p8_done, p8_busy;
wire        p12_start, p12_done, p12_busy;
wire [4:0]  nbytes_q;
wire        last_q;

// ------------------------------------------------------------ datapath
wire [63:0]  K0, K1, N0, N1;
wire [319:0] STAGE;          // state hien tai (thanh ghi chung)
wire [319:0] NEXT_STAGE;     // ngo ra MUX -> thanh ghi state
wire [319:0] D_INIT, D_POST, D_FINAL;
wire [127:0] AD_BLOCK;

wire [63:0] S0 = STAGE[319:256];
wire [63:0] S1 = STAGE[255:192];
wire [63:0] S2 = STAGE[191:128];
wire [63:0] S3 = STAGE[127:64];
wire [63:0] S4 = STAGE[63:0];

wire [63:0] b0, b1, b2, b3, b4;   // sau absorb AD
wire [63:0] c0, c1, c2, c3, c4;   // ngo ra P8
wire [63:0] d0, d1, d2, d3, d4;   // ngo ra P12

// ------------------------------------------------------------ FSM controller
ascon_controller u_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .ad_empty(ad_empty),
    .ad_valid(ad_valid),
    .nbytes_q(nbytes_q),
    .last_q(last_q),
    .p8_done(p8_done),
    .p12_done(p12_done),
    .kn_we(kn_we),
    .ad_we(ad_we),
    .state_we(state_we),
    .tag_we(tag_we),
    .sel(sel),
    .pad_sel(pad_sel),
    .p8_start(p8_start),
    .p12_start(p12_start),
    .ad_ready(ad_ready),
    .busy(busy),
    .done(done)
);

// ------------------------------------------------------------ key / nonce
ascon_key_nonce_reg dut1 (
    .clk(clk),
    .rst_n(rst_n),
    .we(kn_we),
    .key_d(key_d),
    .nonce_d(nonce_d),
    .K0(K0),
    .K1(K1),
    .N0(N0),
    .N1(N1)
);

// sel = 000: IV || K || N
ascon_initial_state dut2 (
    .K0(K0),
    .K1(K1),
    .N0(N0),
    .N1(N1),
    .D_INIT(D_INIT)
);

// sel = 001: S3 ^= K0, S4 ^= K1 (sau P12 init)
ascon_post_init dut3 (
    .S0(S0), .S1(S1), .S2(S2), .S3(S3), .S4(S4),
    .K0(K0),
    .K1(K1),
    .D_POST(D_POST)
);

// Buffer + padding AD
ascon_ad_buffer_padding dut4 (
    .clk(clk),
    .rst_n(rst_n),
    .data_d(ad_data),
    .nbytes_d(ad_nbytes),
    .last_d(ad_last),
    .we(ad_we),
    .pad_sel(pad_sel),
    .block_out(AD_BLOCK),
    .nbytes_q(nbytes_q),
    .last_q(last_q)
);

// sel = 010: S0||S1 ^= AD_BLOCK
ascon_ad_absorb dut5 (
    .AD_BLOCK(AD_BLOCK),
    .S0(S0), .S1(S1), .S2(S2), .S3(S3), .S4(S4),
    .S0_new(b0), .S1_new(b1), .S2_new(b2), .S3_new(b3), .S4_new(b4)
);

// sel = 011: pad PT rong, XOR key, domain separation
ascon_final_pre dut6 (
    .S0(S0), .S1(S1), .S2(S2), .S3(S3), .S4(S4),
    .K0(K0),
    .K1(K1),
    .D_FINAL(D_FINAL)
);

// sel = 100: P8 (absorb AD)
ascon_p8 dut7 (
    .clk(clk),
    .rst_n(rst_n),
    .start(p8_start),
    .x0(S0), .x1(S1), .x2(S2), .x3(S3), .x4(S4),
    .y0(c0), .y1(c1), .y2(c2), .y3(c3), .y4(c4),
    .busy(p8_busy),
    .done(p8_done)
);

// sel = 101: P12 dung chung cho init va finalization
ascon_p12 dut8 (
    .clk(clk),
    .rst_n(rst_n),
    .start(p12_start),
    .x0(S0), .x1(S1), .x2(S2), .x3(S3), .x4(S4),
    .y0(d0), .y1(d1), .y2(d2), .y3(d3), .y4(d4),
    .busy(p12_busy),
    .done(p12_done)
);

// MUX chon gia tri ghi vao state
ascon_state_mux dut9 (
    .sel(sel),
    .D_INIT(D_INIT),
    .D_POST(D_POST),
    .D_AD({b0, b1, b2, b3, b4}),
    .D_FINAL(D_FINAL),
    .P8_OUT({c0, c1, c2, c3, c4}),
    .P12_OUT({d0, d1, d2, d3, d4}),
    .NEXT_STAGE(NEXT_STAGE)
);

ascon_state_reg dut10 (
    .clk(clk),
    .rst_n(rst_n),
    .we(state_we),
    .NEXT_STAGE(NEXT_STAGE),
    .STAGE(STAGE)
);

// Tag = {S3 ^ K0, S4 ^ K1}, chot o TAG_WRITE
ascon_tag_output dut11 (
    .clk(clk),
    .rst_n(rst_n),
    .we(tag_we),
    .S3(S3),
    .S4(S4),
    .K0(K0),
    .K1(K1),
    .tag(tag_out)
);

endmodule
