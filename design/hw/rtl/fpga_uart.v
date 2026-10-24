//======================================================================
//  fpga_uart.v -- KHOI MOI: thanh ghi UART cho CPU (bus slave tren m_*)
//
//  Nam tren bus m_* (sau authenticated_memory_wrapper, canh memory).
//  CPU truy cap bang lw/sw thuong -> wrapper xem la truy cap DATA va
//  chuyen thang xuong (MEMORY_ACCESS), khong qua xac thuc.
//  Giao thuc giong system_memory: mem_ready 1 xung, chu ky sau request.
//
//      0x0200_0010  [7:0]  TX data   (ghi -> yeu cau gui 1 byte)
//      0x0200_0014  [0]    TX busy   (doc; cho ve 0 roi moi ghi byte ke)
//                   [1]    RX ready  (doc; 1 = FIFO RX con byte)
//                   [2]    RX overrun(doc; 1 = da mat byte vi FIFO day,
//                                     tu xoa sau lan doc nay)
//      0x0200_0018  [7:0]  RX data   (doc -> lay 1 byte ra khoi FIFO;
//                                     FIFO rong thi doc = 0)
//      dia chi khac trong 0x02xx_xxxx: doc = 0, ghi bi bo qua
//
//  TX: khoi nay KHONG noi thang vao uart_tx: byte cua CPU (cpu_we/cpu_data)
//      di qua uart_src_mux, noi chon giua CPU va auth_fault_uart_reporter.
//  RX: byte tu uart_rx (rx_valid/rx_data) vao FIFO 16 byte, de go nhanh
//      hoac dan (paste) ca dong lenh khi CPU dang ban in ket qua cung
//      khong mat ky tu.
//======================================================================
module fpga_uart (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_valid,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_addr,
    output reg  [31:0] mem_rdata,
    output reg         mem_ready,
    output wire        cpu_we,      // -> uart_src_mux
    output wire [7:0]  cpu_data,    // -> uart_src_mux
    input  wire        busy,        // <- uart_src_mux (ban phat dang ban)
    input  wire        rx_valid,    // <- uart_rx (xung 1 chu ky)
    input  wire [7:0]  rx_data      // <- uart_rx
);
wire acc   = mem_valid && !mem_ready;
wire is_wr = (mem_wstrb != 4'b0000);
wire r_dat = (mem_addr[5:2] == 4'd4);      // 0x10
wire r_st  = (mem_addr[5:2] == 4'd5);      // 0x14
wire r_rx  = (mem_addr[5:2] == 4'd6);      // 0x18

assign cpu_we   = acc && is_wr && r_dat && mem_wstrb[0];
assign cpu_data = mem_wdata[7:0];

// ---------------------------------------------------------- FIFO RX
reg [7:0] fifo [0:15];
reg [3:0] wp, rp;
reg [4:0] cnt;                              // 0..16
reg       ovr;

wire empty = (cnt == 5'd0);
wire full  = (cnt == 5'd16);
wire pop   = acc && !is_wr && r_rx && !empty;
wire push  = rx_valid && !full;

always @(posedge clk) if (push) fifo[wp] <= rx_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_ready <= 1'b0;
        mem_rdata <= 32'b0;
        wp <= 4'd0; rp <= 4'd0; cnt <= 5'd0; ovr <= 1'b0;
    end else begin
        mem_ready <= acc;
        if (acc)
            mem_rdata <= r_st ? {29'b0, ovr, !empty, busy} :
                         r_rx ? {24'b0, empty ? 8'h00 : fifo[rp]} : 32'b0;

        if (push) wp <= wp + 4'd1;
        if (pop)  rp <= rp + 4'd1;
        case ({push, pop})
            2'b10:   cnt <= cnt + 5'd1;
            2'b01:   cnt <= cnt - 5'd1;
            default: ;
        endcase

        if (rx_valid && full)               ovr <= 1'b1;
        else if (acc && !is_wr && r_st)     ovr <= 1'b0;
    end
end

endmodule
