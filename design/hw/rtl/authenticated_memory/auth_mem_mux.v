
module auth_mem_mux (
    input  wire        en,
    input  wire [1:0]  sel,
    input  wire [31:0] code_addr,
    input  wire [31:0] tag_addr,
    input  wire [31:0] req_addr,
    input  wire [31:0] req_wdata,
    input  wire [3:0]  req_wstrb,
    output wire        m_valid,
    output reg  [31:0] m_addr,
    output reg  [31:0] m_wdata,
    output reg  [3:0]  m_wstrb
);
localparam [1:0] SEL_CODE = 2'b00, SEL_TAG = 2'b01, SEL_DATA = 2'b10;

assign m_valid = en;

always @(*) begin
    m_addr  = 32'b0;
    m_wdata = 32'b0;
    m_wstrb = 4'b0;
    if (en) begin
        case (sel)
            SEL_CODE: m_addr = code_addr;
            SEL_TAG:  m_addr = tag_addr;
            SEL_DATA: begin
                m_addr  = req_addr;
                m_wdata = req_wdata;
                m_wstrb = req_wstrb;
            end
            default: ;
        endcase
    end
end
endmodule
