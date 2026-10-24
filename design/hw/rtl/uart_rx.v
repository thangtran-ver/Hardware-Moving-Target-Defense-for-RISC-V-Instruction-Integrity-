//======================================================================
//  uart_rx.v -- KHOI MOI: bo thu UART 8N1 (PC -> FPGA)
//
//  - 8 bit du lieu, khong parity, 1 stop bit (8N1), cung DIV voi uart_tx
//      DIV = 27_000_000 / 115200 = 234  (sai so +0.16%)
//  - Chan rx qua 2 flip-flop dong bo (tin hieu ngoai, khong cung clock).
//  - Phat hien start bit (canh xuong), doi nua bit roi lay mau giua bit
//    de kiem tra start bit con thap (loc nhieu), sau do lay mau giua
//    moi bit du lieu.  LSB truoc.
//  - Xong stop bit: valid = 1 trong 1 chu ky, data giu byte vua nhan.
//    Stop bit = 0 (loi khung) -> bo byte, khong bao valid.
//
//  Muc nghi cua duong RX la MUC CAO (PULL_MODE=UP trong .cst).
//======================================================================
`default_nettype none

module uart_rx #(
    parameter integer CLK_HZ = 27_000_000,
    parameter integer BAUD   = 115200
) (
    input  wire       clk,
    input  wire       resetn,
    input  wire       rx,        // tu chan FPGA (TXD cua CP2102)
    output reg  [7:0] data,      // byte vua nhan
    output reg        valid      // xung 1 chu ky khi co byte moi
);

    localparam integer DIV  = CLK_HZ / BAUD;
    localparam integer HALF = DIV / 2;

    reg [1:0]  sync;             // dong bo 2 tang
    reg [15:0] cnt;
    reg [3:0]  idx;              // 0 = start, 1..8 = data, 9 = stop
    reg [7:0]  sh;
    reg        active;

    wire rx_s = sync[1];

    always @(posedge clk) begin
        if (!resetn) begin
            sync   <= 2'b11;
            cnt    <= 16'd0;
            idx    <= 4'd0;
            sh     <= 8'd0;
            active <= 1'b0;
            data   <= 8'd0;
            valid  <= 1'b0;
        end else begin
            sync  <= {sync[0], rx};
            valid <= 1'b0;

            if (!active) begin
                if (!rx_s) begin                 // canh xuong: start bit
                    active <= 1'b1;
                    cnt    <= 16'd0;
                    idx    <= 4'd0;
                end
            end else begin
                // lan lay mau dau o giua start bit (HALF), sau do moi DIV
                if (cnt == ((idx == 4'd0) ? HALF[15:0] : DIV[15:0]) - 16'd1) begin
                    cnt <= 16'd0;
                    case (idx)
                        4'd0: if (rx_s) active <= 1'b0;      // nhieu, khong phai start
                              else      idx    <= 4'd1;
                        4'd9: begin                          // stop bit
                                  active <= 1'b0;
                                  if (rx_s) begin
                                      data  <= sh;
                                      valid <= 1'b1;
                                  end
                              end
                        default: begin                       // bit du lieu 1..8
                                  sh  <= {rx_s, sh[7:1]};
                                  idx <= idx + 4'd1;
                              end
                    endcase
                end else begin
                    cnt <= cnt + 16'd1;
                end
            end
        end
    end

endmodule

`default_nettype wire
