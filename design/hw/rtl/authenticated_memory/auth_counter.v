module auth_counter #(
    parameter integer W = 4
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         clr,
    input  wire         inc,
    output reg  [W-1:0] cnt
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)   cnt <= {W{1'b0}};
    else if (clr) cnt <= {W{1'b0}};
    else if (inc) cnt <= cnt + 1'b1;
end
endmodule
