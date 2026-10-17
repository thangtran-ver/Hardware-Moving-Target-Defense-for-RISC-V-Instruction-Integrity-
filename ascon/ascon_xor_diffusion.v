module ascon_xor_diffusion (
input wire [63:0] x0,x1,x2,x3,x4,
output wire [63:0] x0_new,x1_new,x2_new,x3_new,x4_new);
function [63:0] rotr;
input [63:0] x;
input integer n;
begin
rotr = (x >> n) | (x << (64-n));
end
endfunction
assign x0_new = x0 ^ rotr(x0, 19) ^ rotr(x0, 28);
assign x1_new = x1 ^ rotr(x1, 61) ^ rotr(x1, 39);
assign x2_new = x2 ^ rotr(x2, 1) ^ rotr(x2, 6);
assign x3_new = x3 ^ rotr(x3, 10) ^ rotr(x3, 17);
assign x4_new = x4 ^ rotr(x4, 7) ^ rotr(x4, 41);
endmodule
