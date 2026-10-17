module ascon_key_nonce_reg (
input wire clk,
input wire rst_n,
input wire we,
input wire [127:0] key_d,
input wire [127:0] nonce_d,
output reg [63:0] K0,
output reg [63:0] K1,
output reg [63:0] N0,
output reg [63:0] N1
);
always @(posedge clk or negedge rst_n) begin
if(!rst_n) begin
K0 <= 0;
K1 <= 0;
N0 <= 0;
N1 <= 0;
end
else if(!we) begin
K0 <= K0;
K1 <= K1;
N0 <= N0;
N1 <= N1;
end
else begin
K0 <= key_d[127:64];
K1 <= key_d[63:0];
N0 <= nonce_d[127:64];
N1 <= nonce_d[63:0];
end
end
endmodule


