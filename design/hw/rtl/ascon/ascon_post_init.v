module ascon_post_init (
input wire [63:0] S0,
input wire [63:0] S1,
input wire [63:0] S2,
input wire [63:0] S3,
input wire [63:0] S4,
input wire [63:0] K0,
input wire [63:0] K1,
output wire [319:0] D_POST);
wire [63:0] a0,a1,a2,a3,a4;
assign a0 = S0;
assign a1 = S1;
assign a2 = S2;
assign a3 = S3 ^ K0;
assign a4 = S4 ^ K1;
	assign D_POST = {a0,a1,a2,a3,a4};
endmodule

