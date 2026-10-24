module ascon_state_mux(
input wire [2:0] sel,
input wire [319:0] D_INIT,
input wire [319:0] D_POST,
input wire [319:0] D_AD,
input wire [319:0] D_FINAL,
input wire [319:0] P8_OUT,
input wire [319:0] P12_OUT,
output reg [319:0] NEXT_STAGE);
always @(*) begin
case(sel) 
3'b000: NEXT_STAGE = D_INIT;
3'b001: NEXT_STAGE = D_POST;
3'b010: NEXT_STAGE = D_AD;
3'b011: NEXT_STAGE = D_FINAL;
3'b100: NEXT_STAGE = P8_OUT;
3'b101: NEXT_STAGE = P12_OUT;
default : NEXT_STAGE = 0;
endcase
end
endmodule 
