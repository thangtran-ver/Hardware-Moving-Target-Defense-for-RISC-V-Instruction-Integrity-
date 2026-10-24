module ascon_state_reg(
input wire clk,
input wire rst_n,
input wire we,
input wire [319:0] NEXT_STAGE,
output reg [319:0] STAGE
);
always @(posedge clk or negedge rst_n) begin
if(!rst_n) begin
STAGE <= 0;
end 
else if(!we) begin
STAGE <= STAGE;
end
else begin
STAGE <= NEXT_STAGE;
end
end
endmodule
