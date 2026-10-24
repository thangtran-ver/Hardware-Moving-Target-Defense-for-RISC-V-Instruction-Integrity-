module auth_fault_reg (
    input  wire clk,
    input  wire rst_n,
    input  wire set,
    output reg  fault
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)   fault <= 1'b0;
    else if (set) fault <= 1'b1;
end
endmodule
