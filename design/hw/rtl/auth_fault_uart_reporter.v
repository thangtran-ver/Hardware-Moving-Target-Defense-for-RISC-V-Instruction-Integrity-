//======================================================================
//  auth_fault_uart_reporter.v -- KHOI MOI: in thong bao khi auth_fault = 1
//
//  Khi auth_fault (sticky, tu authenticated_memory_wrapper) len 1, khoi
//  nay chiem UART va in 1 dong:
//
//      [AUTH] FAULT: TAG-MISMATCH addr=0x00000140 trap=1
//
//  reason (tinh tu request bi tu choi, KHONG doc vao ben trong wrapper):
//      TAG-MISMATCH  fetch trong vung CODE nhung tag Ascon khong khop
//      FETCH-NOCODE  fetch ngoai vung CODE (vd nhay vao data RAM)
//      WRITE-PROT    lenh ghi vao vung CODE hoac TAG
//  Neu CPU da trap (fault khi fetch, FAULT_HALT = 0) thi in lap lai moi
//  ~2.5 s de mo terminal muon van thay. Neu CPU van chay (fault do lenh
//  ghi) thi chi in 1 lan roi tra UART cho firmware.
//  53 ky tu / dong. Bang ky tu duoc sinh tu dong.
//======================================================================
module auth_fault_uart_reporter #(
    parameter integer REPEAT_BITS = 26
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        fault,
    input  wire [1:0]  code,
    input  wire [31:0] addr,
    input  wire        trap,
    input  wire        uart_busy,
    output reg         uart_we,
    output reg  [7:0]  uart_data,
    output wire        active          // 1 = dang giu UART
);
localparam [6:0] MSG_LEN = 7'd53;

function [7:0] hx;
    input [3:0] n;
    hx = (n < 4'd10) ? (8'h30 + {4'd0, n}) : (8'h37 + {4'd0, n});
endfunction

reg [6:0] idx;
reg [7:0] ch;

always @(*) begin
    case (idx)
        7'd0: ch = 8'h0d;   // '\r'
        7'd1: ch = 8'h0a;   // '\n'
        7'd2: ch = 8'h5b;   // '['
        7'd3: ch = 8'h41;   // 'A'
        7'd4: ch = 8'h55;   // 'U'
        7'd5: ch = 8'h54;   // 'T'
        7'd6: ch = 8'h48;   // 'H'
        7'd7: ch = 8'h5d;   // ']'
        7'd8: ch = 8'h20;   // ' '
        7'd9: ch = 8'h46;   // 'F'
        7'd10: ch = 8'h41;   // 'A'
        7'd11: ch = 8'h55;   // 'U'
        7'd12: ch = 8'h4c;   // 'L'
        7'd13: ch = 8'h54;   // 'T'
        7'd14: ch = 8'h3a;   // ':'
        7'd15: ch = 8'h20;   // ' '
        7'd16: ch = (code == 2'd1) ? 8'h54 : (code == 2'd2) ? 8'h46 : 8'h57;
        7'd17: ch = (code == 2'd1) ? 8'h41 : (code == 2'd2) ? 8'h45 : 8'h52;
        7'd18: ch = (code == 2'd1) ? 8'h47 : (code == 2'd2) ? 8'h54 : 8'h49;
        7'd19: ch = (code == 2'd1) ? 8'h2d : (code == 2'd2) ? 8'h43 : 8'h54;
        7'd20: ch = (code == 2'd1) ? 8'h4d : (code == 2'd2) ? 8'h48 : 8'h45;
        7'd21: ch = (code == 2'd1) ? 8'h49 : (code == 2'd2) ? 8'h2d : 8'h2d;
        7'd22: ch = (code == 2'd1) ? 8'h53 : (code == 2'd2) ? 8'h4e : 8'h50;
        7'd23: ch = (code == 2'd1) ? 8'h4d : (code == 2'd2) ? 8'h4f : 8'h52;
        7'd24: ch = (code == 2'd1) ? 8'h41 : (code == 2'd2) ? 8'h43 : 8'h4f;
        7'd25: ch = (code == 2'd1) ? 8'h54 : (code == 2'd2) ? 8'h4f : 8'h54;
        7'd26: ch = (code == 2'd1) ? 8'h43 : (code == 2'd2) ? 8'h44 : 8'h20;
        7'd27: ch = (code == 2'd1) ? 8'h48 : (code == 2'd2) ? 8'h45 : 8'h20;
        7'd28: ch = 8'h20;   // ' '
        7'd29: ch = 8'h61;   // 'a'
        7'd30: ch = 8'h64;   // 'd'
        7'd31: ch = 8'h64;   // 'd'
        7'd32: ch = 8'h72;   // 'r'
        7'd33: ch = 8'h3d;   // '='
        7'd34: ch = 8'h30;   // '0'
        7'd35: ch = 8'h78;   // 'x'
        7'd36: ch = hx(addr[31:28]);
        7'd37: ch = hx(addr[27:24]);
        7'd38: ch = hx(addr[23:20]);
        7'd39: ch = hx(addr[19:16]);
        7'd40: ch = hx(addr[15:12]);
        7'd41: ch = hx(addr[11:8]);
        7'd42: ch = hx(addr[7:4]);
        7'd43: ch = hx(addr[3:0]);
        7'd44: ch = 8'h20;   // ' '
        7'd45: ch = 8'h74;   // 't'
        7'd46: ch = 8'h72;   // 'r'
        7'd47: ch = 8'h61;   // 'a'
        7'd48: ch = 8'h70;   // 'p'
        7'd49: ch = 8'h3d;   // '='
        7'd50: ch = trap ? 8'h31 : 8'h30;
        7'd51: ch = 8'h0d;   // '\r'
        7'd52: ch = 8'h0a;   // '\n'
        default: ch = 8'h20;
    endcase
end

localparam [2:0] S_IDLE = 3'd0, S_SEND = 3'd1, S_GAP = 3'd2, S_WAIT = 3'd3, S_DONE = 3'd4;
reg [2:0]             st;
reg [REPEAT_BITS-1:0] gap;

assign active = (st == S_SEND) || (st == S_GAP);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        st        <= S_IDLE;
        idx       <= 7'd0;
        gap       <= {REPEAT_BITS{1'b0}};
        uart_we   <= 1'b0;
        uart_data <= 8'h00;
    end else begin
        uart_we <= 1'b0;
        case (st)
            S_IDLE: if (fault) begin idx <= 7'd0; st <= S_SEND; end

            S_SEND: if (!uart_busy && !uart_we) begin
                        uart_data <= ch;
                        uart_we   <= 1'b1;
                        st        <= S_GAP;
                    end

            S_GAP:  if (idx == MSG_LEN - 7'd1) begin
                        gap <= {REPEAT_BITS{1'b0}};
                        st  <= S_WAIT;
                    end else begin
                        idx <= idx + 7'd1;
                        st  <= S_SEND;
                    end

            S_WAIT: if (!trap) st <= S_DONE;          // CPU con chay: in 1 lan
                    else begin
                        gap <= gap + 1'b1;
                        if (&gap) begin idx <= 7'd0; st <= S_SEND; end
                    end

            default: ;                                 // S_DONE
        endcase
    end
end

endmodule
