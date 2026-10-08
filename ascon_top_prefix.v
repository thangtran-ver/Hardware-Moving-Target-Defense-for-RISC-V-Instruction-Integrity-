module ascon_top(
input wire clk,
input wire rst_n,
input wire we,
input wire start,
input wire [127:0] ad_data,
input wire [127:0] key_d,
input wire [127:0] nonce_d,

input wire [4:0] ad_nbytes,
input wire ad_last,
input wire ad_valid,
output wire ad_ready,
output reg [127:0] tag_out,
output reg done,
output reg busy);
wire [63:0] K0,K1,N0,N1;
ascon_key_nonce_reg dut1 (
.clk(clk),
.rst_n(rst_n),
.we(we),
.key_d(key_d),
.nonce_d(nonce_d),
.K0(K0),
.K1(K1),
.N0(N0),
.N1(N1)
);
wire [319:0] D_INIT;
ascon_initial_state dut2(
.K0(K0),
.K1(K1),
.N0(N0),
.N1(N1),
.D_INIT(D_INIT)
);
wire p12_start;
wire p12_done;
wire p12_busy;
wire [63:0] a0,a1,a2,a3,a4;
ascon_p12 dut3 (
.clk(clk),
.rst_n(rst_n),
.start(p12_start),
.busy(p12_busy),
.done(p12_done),
.x0(D_INIT[319:256]),
.x1(D_INIT[255:192]),
.x2(D_INIT[191:128]),
.x3(D_INIT[127:64]),
.x4(D_INIT[63:0]),
.y0(a0),
.y1(a1),
.y2(a2),
.y3(a3),
.y4(a4)
);
wire [319:0] D_POST;

ascon_post_init dut4 (
    .S0(a0),    // y0 cua P12
    .S1(a1),    // y1 cua P12
    .S2(a2),    // y2 cua P12
    .S3(a3),    // y3 cua P12
    .S4(a4),    // y4 cua P12

    .K0(K0),
    .K1(K1),

    .D_POST(D_POST)
);
wire [319:0] STAGE;
ascon_state_reg dut5(
.clk(clk),
.rst_n(rst_n),
.we(we),
.NEXT_STAGE(D_POST),
.STAGE(STAGE)
);
wire [127:0] AD_BLOCK;
wire [4:0] nbytes_q;
wire last_q;

wire ad_we;
wire [1:0] pad_sel;

ascon_ad_buffer_padding dut6 (
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
wire [63:0] b0,b1,b2,b3,b4;
ascon_ad_absorb dut7(
.AD_BLOCK(AD_BLOCK),
.S0(D_POST[319:256]),
.S1(D_POST[255:192]),
.S2(D_POST[191:128]),
.S3(D_POST[127:64]),
.S4(D_POST[63:0]),
.S0_new(b0),
.S1_new(b1),
.S2_new(b2),
.S3_new(b3),
.S4_new(b4)
);
wire [63:0] c0,c1,c2,c3,c4;
wire p8_busy;
wire p8_done;
wire p8_start;
ascon_p8 dut8(
.x0(b0),
.x1(b1),
.x2(b2),
.x3(b3),
.x4(b4),
.y0(c0),
.y1(c1),
.y2(c2),
.y3(c3),
.y4(c4),
.clk(clk),
.start(p8_start),
.rst_n(rst_n),
.done(p8_done),
.busy(p8_busy)
);


wire [319:0] D_FINAL;
ascon_final_pre dut9(
.S0(c0),
.S1(c1),
.S2(c2),
.S3(c3),
.S4(c4),
.K0(K0),
.K1(K1),
.D_FINAL(D_FINAL)
);
wire [63:0] d0,d1,d2,d3,d4;
reg final_busy;
reg final_done;
reg final_start;
ascon_p12 dut10 (
.clk(clk),
.rst_n(rst_n),
.start(final_busy),
.busy(final_busy),
.done(final_done),
.x0(D_FINAL[319:256]),
.x1(D_FINAL[255:192]),
.x2(D_FINAL[191:128]),
.x3(D_FINAL[127:64]),
.x4(D_FINAL[63:0]),
.y0(d0),
.y1(d1),
.y2(d2),
.y3(d3),
.y4(d4)
);
reg [127:0] tag_q;
ascon_tag_output dut10(
.clk(clk),
.rst_n(rst_n),
.we(we),
.S3(d3),
.S4(d4),
.K1(K1),
.K0(K0),
.tag(tag_q)
);
always @(posedge clk or negedge rst_n) begin
if(!rst_n) begin
tag_out <= 0;
end
else if(busy) begin
tag_out <= tag_out;
end
else if(done) begin
tag_out <= tag_q;
end
end
endmodule

