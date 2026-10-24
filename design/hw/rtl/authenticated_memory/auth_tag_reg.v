module auth_tag_reg #(
    parameter integer T = 128
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         we,
    input  wire [3:0]   widx,
    input  wire [31:0]  wdata,
    output reg  [T-1:0] tag_q
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  tag_q <= {T{1'b0}};
    else if (we) tag_q[T-1-32*widx -: 32] <= wdata;
end
endmodule
