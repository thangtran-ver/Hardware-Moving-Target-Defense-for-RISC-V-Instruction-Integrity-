
module auth_controller #(
    parameter integer G          = 4,
    parameter integer T          = 128,
    parameter integer FAULT_HALT = 0
)(
    input  wire       clk,
    input  wire       rst_n,
    // trang thai
    input  wire       cpu_mem_valid,
    input  wire       req_instr,    
    input  wire       in_code,       
    input  wire       wr_protected,  
    input  wire       buf_hit,       
    input  wire       m_ready,
    input  wire [3:0] cnt,           
    input  wire       a_busy,
    input  wire       a_ad_ready,
    input  wire       a_done,
    input  wire       last_beat,
    input  wire       tag_ok,
    output reg        req_we,        
    output reg        cnt_clr,
    output reg        cnt_inc,
    output reg        beat_clr,
    output reg        beat_inc,
    output reg        code_we,       
    output reg        tag_we,        
    output reg        buf_inv,       
    output reg        buf_set,       
    output reg        fault_set,
    output reg        m_en,          
    output reg  [1:0] m_sel,        
    output reg        resp_en,       
    output reg  [1:0] resp_sel,      
    output wire       a_start,
    output wire       a_ad_valid,
    output reg        inc_fetch,
    output reg        inc_hit,
    output reg        inc_verify,
    output reg        inc_data,
    output reg        inc_fault,
    output reg        inc_stall,
    output wire [3:0] state_dbg
);
localparam integer TAG_WORDS = T / 32;

localparam [3:0]
    IDLE          = 4'd0,
    CHECK_REQUEST = 4'd1,
    READ_CODE     = 4'd2,
    READ_TAG      = 4'd3,
    START_ASCON   = 4'd4,
    SEND_AD       = 4'd5,
    WAIT_ASCON    = 4'd6,
    COMPARE       = 4'd7,
    RESPONSE      = 4'd8,
    FAULT         = 4'd9,
    MEMORY_ACCESS = 4'd10;

localparam [1:0] M_CODE = 2'b00, M_TAG = 2'b01, M_DATA = 2'b10;
localparam [1:0] R_BUF  = 2'b00, R_MEM = 2'b01, R_ZERO = 2'b10;

reg [3:0] state, next_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
end

assign state_dbg  = state;
assign a_start    = (state == START_ASCON);   // Moore
assign a_ad_valid = (state == SEND_AD);       // Moore

always @(*) begin
    next_state = state;
    req_we     = 1'b0;
    cnt_clr    = 1'b0;
    cnt_inc    = 1'b0;
    beat_clr   = 1'b0;
    beat_inc   = 1'b0;
    code_we    = 1'b0;
    tag_we     = 1'b0;
    buf_inv    = 1'b0;
    buf_set    = 1'b0;
    fault_set  = 1'b0;
    m_en       = 1'b0;
    m_sel      = M_CODE;
    resp_en    = 1'b0;
    resp_sel   = R_BUF;
    inc_fetch  = 1'b0;
    inc_hit    = 1'b0;
    inc_verify = 1'b0;
    inc_data   = 1'b0;

    case (state)
        IDLE: begin
            if (cpu_mem_valid) begin
                req_we     = 1'b1;
                next_state = CHECK_REQUEST;
            end
        end

        CHECK_REQUEST: begin
            cnt_clr  = 1'b1;
            beat_clr = 1'b1;
            if (req_instr) begin
                inc_fetch = 1'b1;
                if (!in_code)
                    next_state = FAULT;          // fetch ngoai vung CODE
                else if (buf_hit) begin
                    inc_hit    = 1'b1;
                    next_state = RESPONSE;       // block da verify
                end else begin
                    buf_inv    = 1'b1;           
                    next_state = READ_CODE;
                end
            end else begin
                inc_data = 1'b1;
                if (wr_protected)
                    next_state = FAULT;          // ghi vao CODE/TAG
                else
                    next_state = MEMORY_ACCESS;
            end
        end

        READ_CODE: begin
            m_en  = 1'b1;
            m_sel = M_CODE;
            if (m_ready) begin
                code_we = 1'b1;
                if (cnt == G - 1) begin
                    cnt_clr    = 1'b1;
                    next_state = READ_TAG;
                end else
                    cnt_inc = 1'b1;
            end
        end

        READ_TAG: begin
            m_en  = 1'b1;
            m_sel = M_TAG;
            if (m_ready) begin
                tag_we  = 1'b1;
                cnt_inc = 1'b1;
                if (cnt == TAG_WORDS - 1)
                    next_state = START_ASCON;
            end
        end

        START_ASCON: begin
            if (!a_busy) begin
                inc_verify = 1'b1;
                next_state = SEND_AD;
            end
        end

        SEND_AD: begin
            if (a_ad_ready) begin
                if (last_beat) next_state = WAIT_ASCON;
                else           beat_inc   = 1'b1;
            end
        end

        WAIT_ASCON: begin
            if (a_done)
                next_state = COMPARE;
        end

        COMPARE: begin
            if (tag_ok) begin
                buf_set    = 1'b1;
                next_state = RESPONSE;
            end else
                next_state = FAULT;
        end

        RESPONSE: begin
            resp_en    = 1'b1;
            resp_sel   = R_BUF;
            next_state = IDLE;
        end

        MEMORY_ACCESS: begin
            m_en  = 1'b1;
            m_sel = M_DATA;
            if (m_ready) begin
                resp_en    = 1'b1;
                resp_sel   = R_MEM;
                next_state = IDLE;
            end
        end

        FAULT: begin
            fault_set = 1'b1;
            buf_inv   = 1'b1;
            if (FAULT_HALT != 0)
                next_state = FAULT;              // CPU treo
            else begin
                resp_en    = 1'b1;               // tra 0 -> PicoRV32 trap
                resp_sel   = R_ZERO;
                next_state = IDLE;
            end
        end

        default: next_state = IDLE;
    endcase
end

always @(*) begin
    inc_fault = (next_state == FAULT) && (state != FAULT);
    inc_stall = (state != IDLE) && req_instr;
end
endmodule
