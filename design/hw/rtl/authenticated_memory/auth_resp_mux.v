
module auth_resp_mux (
    input  wire        en,
    input  wire [1:0]  sel,
    input  wire [31:0] buf_rdata,
    input  wire [31:0] m_rdata,
    output wire        cpu_mem_ready,
    output reg  [31:0] cpu_mem_rdata
);
localparam [1:0] SEL_BUF = 2'b00, SEL_MEM = 2'b01, SEL_ZERO = 2'b10;

assign cpu_mem_ready = en;

always @(*) begin
    cpu_mem_rdata = 32'b0;
    if (en) begin
        case (sel)
            SEL_BUF: cpu_mem_rdata = buf_rdata;
            SEL_MEM: cpu_mem_rdata = m_rdata;
            default: cpu_mem_rdata = 32'b0;
        endcase
    end
end
endmodule
