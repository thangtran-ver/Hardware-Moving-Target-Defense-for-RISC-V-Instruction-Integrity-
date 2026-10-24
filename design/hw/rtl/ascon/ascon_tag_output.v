module ascon_tag_output(
input wire clk,
input wire rst_n,
input wire we,
input wire [63:0] S3,S4,K0,K1,
output reg [127:0] tag);
always @(posedge clk or negedge rst_n) begin
if(!rst_n) begin
tag <= 0;
end
else if(!we) begin
tag <= tag;
end
else begin
tag <= {S3 ^ K0, S4 ^ K1};
end
end
endmodule