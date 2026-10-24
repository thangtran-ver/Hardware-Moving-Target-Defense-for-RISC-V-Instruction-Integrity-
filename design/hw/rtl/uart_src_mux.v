//======================================================================
//  uart_src_mux.v -- KHOI MOI: MUX chon nguon du lieu truoc uart_tx
//
//      fault_sel = 0 (binh thuong) : uart_tx <- CPU (fpga_uart, 0x0200_0010)
//      fault_sel = 1 (co loi)      : uart_tx <- auth_fault_uart_reporter
//
//  fault_sel = 'active' cua reporter: len 1 khi auth_fault = 1 va
//  reporter dang in dong "[AUTH] FAULT: ...".
//    - Fault khi fetch (CPU trap): reporter giu UART va in lai moi ~2.5 s.
//    - Fault do lenh ghi vao CODE/TAG (CPU van chay): in 1 dong roi
//      fault_sel ve 0, UART tra lai cho CPU.
//  Khi fault_sel = 1, CPU thay busy = 1 nen tu doi, khong mat byte nao
//  cua reporter; byte CPU ghi dung luc chuyen nguon (neu co) bi bo.
//======================================================================
module uart_src_mux (
    input  wire       fault_sel,
    // nguon 0: CPU
    input  wire       cpu_we,
    input  wire [7:0] cpu_data,
    output wire       cpu_busy,
    // nguon 1: fault reporter
    input  wire       flt_we,
    input  wire [7:0] flt_data,
    output wire       flt_busy,
    // -> uart_tx
    output wire       tx_we,
    output wire [7:0] tx_data,
    input  wire       tx_busy
);
assign tx_we    = fault_sel ? flt_we   : cpu_we;
assign tx_data  = fault_sel ? flt_data : cpu_data;
assign cpu_busy = tx_busy | fault_sel;
assign flt_busy = tx_busy;
endmodule
