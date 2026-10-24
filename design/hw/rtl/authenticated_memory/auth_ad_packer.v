
module auth_ad_packer #(
    parameter integer G = 4
)(
    input  wire [31:0]     blk_base,
    input  wire [32*G-1:0] code_flat,
    input  wire [1:0]      beat,
    output wire [127:0]    ad_data,
    output wire [4:0]      ad_nbytes,
    output wire            last
);
localparam integer AD_BYTES = 4 + 4 * G;
localparam integer NBEATS   = (AD_BYTES + 15) / 16;
localparam integer LAST_NB  = AD_BYTES - 16 * (NBEATS - 1);
localparam integer AD_W     = NBEATS * 128;

wire [AD_W-1:0] ad_pad = {blk_base, code_flat, {(AD_W-32-32*G){1'b0}}};

assign last      = (beat == NBEATS - 1);
assign ad_data   = ad_pad[AD_W-1-128*beat -: 128];
assign ad_nbytes = last ? LAST_NB[4:0] : 5'd16;
endmodule
