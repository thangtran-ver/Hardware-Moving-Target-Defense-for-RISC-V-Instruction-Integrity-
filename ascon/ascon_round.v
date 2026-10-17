	module ascon_round (
	input wire [63:0] x0,x1,x2,x3,x4,
	input wire [7:0] constant,
	output wire [63:0] y0,y1,y2,y3,y4);
	wire [63:0] a0,a1,a2,a3,a4,b0,b1,b2,b3,b4;
	ascon_add_constant dut_1 (
	.x0(x0),
	.x1(x1),
	.x2(x2),
	.x3(x3),
	.x4(x4),
	.constant(constant),
	.x0_new(a0),
	.x1_new(a1),
	.x2_new(a2),
	.x3_new(a3),
	.x4_new(a4)
	);
	ascon_sbox dut_2 (
	.x0(a0),
	.x1(a1),
	.x2(a2),
	.x3(a3),
	.x4(a4),
	.y0(b0),
	.y1(b1),
	.y2(b2),
	.y3(b3),
	.y4(b4)
	);
	ascon_xor_diffusion dut_3 (
	.x0(b0),
	.x1(b1),
	.x2(b2),
	.x3(b3),
	.x4(b4),
	.x0_new(y0),
	.x1_new(y1),
	.x2_new(y2),
	.x3_new(y3),
	.x4_new(y4)
	);
	endmodule 

