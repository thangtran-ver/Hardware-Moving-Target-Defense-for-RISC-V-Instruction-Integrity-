module ascon_add_constant (
input wire [63:0] x0,x1,x2,x3,x4,
input wire [7:0] constant,
output wire [63:0] x0_new,x1_new,x2_new,x3_new,x4_new);
assign x0_new = x0;
assign x3_new = x3;
assign x4_new = x4;
assign x1_new = x1;
assign x2_new = x2 ^ {56'b0,constant};
endmodule 
