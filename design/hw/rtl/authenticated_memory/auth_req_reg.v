module auth_req_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire        instr_d,
    input  wire [31:0] addr_d,
    input  wire [31:0] wdata_d,
    input  wire [3:0]  wstrb_d,
    output reg         instr_q,
    output reg  [31:0] addr_q,
    output reg  [31:0] wdata_q,
    output reg  [3:0]  wstrb_q
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        instr_q <= 1'b0;
        addr_q  <= 32'b0;
        wdata_q <= 32'b0;
        wstrb_q <= 4'b0;
    end else if (we) begin
        instr_q <= instr_d;
        addr_q  <= addr_d;
        wdata_q <= wdata_d;
        wstrb_q <= wstrb_d;
    end
end
endmodule
