module ascon_initial_state (
input wire [63:0] K0,
input wire [63:0] K1,
input wire [63:0] N0,
input wire [63:0] N1,
output wire [319:0] D_INIT);
reg [63:0] IV = 64'h80800C0800000000;
assign D_INIT = {
    64'h80800C0800000000,
    K0,
    K1,
    N0,
    N1
};
endmodule 