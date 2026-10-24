module ascon_ad_absorb (
input wire [127:0] AD_BLOCK,
input wire [63:0] S0,
input wire [63:0] S1,
input wire [63:0] S2,
input wire [63:0] S3,
input wire [63:0] S4,
output wire [63:0] S0_new,
output wire [63:0] S1_new,
output wire [63:0] S2_new,
output wire [63:0] S3_new,
output wire [63:0] S4_new);
assign S0_new = S0 ^ AD_BLOCK[127:64];
assign S1_new = S1 ^ AD_BLOCK[63:0];
assign S2_new = S2;
assign S3_new = S3;
assign S4_new = S4;
endmodule