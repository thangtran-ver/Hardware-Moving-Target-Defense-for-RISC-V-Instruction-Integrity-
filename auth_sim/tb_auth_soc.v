`timescale 1ns/1ps
// tb_auth_soc.v -- chay firmware tren PicoRV32 qua Authenticated Memory.
// Plusargs:
//   +code=<hex> +tag=<hex> [+data=<hex>]   nap code_rom / tag_rom / data_ram
//   +attack=<n>   0: khong tan cong
//                 1: lat 1 bit code o 0x14 truoc khi chay
//                 2: lat 1 bit tag cua block 1 truoc khi chay
//                 3: doi cho block 1 va block 2 (ca code lan tag)
//                 4: TOCTOU - sua code o 0x14 SAU khi block da vao buffer
//   +maxcyc=<n>
//   +expect=clean|fault|toctou|wcode   tu kiem tra va in CHECK PASS/FAIL
// -DPLAIN: PicoRV32 noi thang system_memory (khong verify) de lay so chu ky goc.
module tb_auth_soc;
parameter integer G = 4;
parameter integer T = 128;

reg clk = 0, rst_n = 0;
always #5 clk = ~clk;

wire trap, auth_fault;

`ifdef PLAIN
wire        mv, mi, mr; wire [31:0] ma, mwd, mrd; wire [3:0] mws;
picorv32 #(.COMPRESSED_ISA(0), .CATCH_ILLINSN(1), .CATCH_MISALIGN(1), .ENABLE_IRQ(0),
           .PROGADDR_RESET(0), .STACKADDR(32'h0002_1000)) u_cpu (
    .clk(clk), .resetn(rst_n), .trap(trap), .mem_valid(mv), .mem_instr(mi), .mem_ready(mr),
    .mem_addr(ma), .mem_wdata(mwd), .mem_wstrb(mws), .mem_rdata(mrd));
system_memory u_mem (.clk(clk), .rst_n(rst_n), .mem_valid(mv), .mem_wdata(mwd),
    .mem_wstrb(mws), .mem_addr(ma), .mem_rdata(mrd), .mem_ready(mr));
assign auth_fault = 1'b0;
`define MEM u_mem
`else
auth_soc_top #(.G(G), .T(T)) dut (.clk(clk), .rst_n(rst_n), .trap(trap), .auth_fault(auth_fault));
`define MEM dut.u_mem
`endif

reg [1023:0] fcode, ftag, fdata, fexp;
reg ok;
integer attack, maxcyc, cyc, i, toctou_done;
reg [31:0] tmp;

always @(posedge clk) if (rst_n) cyc <= cyc + 1;

`ifndef PLAIN
// TOCTOU: khi CPU vua nhan lenh o 0x14 lan dau (block 0x10 da verify, nam trong
// buffer), sua lenh 0x14 trong memory: addi x3,x3,1 -> addi x3,x3,2
always @(posedge clk) if (attack == 4 && !toctou_done && dut.cpu_mem_ready
                          && dut.cpu_mem_instr && dut.cpu_mem_addr == 32'h14) begin
    `MEM.code_rom[5] <= 32'h00218193;
    toctou_done <= 1;
end
`endif

initial begin
    cyc = 0; toctou_done = 0;
    if (!$value$plusargs("attack=%d", attack)) attack = 0;
    if (!$value$plusargs("maxcyc=%d", maxcyc)) maxcyc = 20000;
    for (i = 0; i < 2048; i = i + 1) begin `MEM.code_rom[i] = 0; `MEM.tag_rom[i] = 0; end
    for (i = 0; i < 1024; i = i + 1) `MEM.data_ram[i] = 0;
    if ($value$plusargs("code=%s", fcode)) $readmemh(fcode, `MEM.code_rom);
    if ($value$plusargs("tag=%s",  ftag))  $readmemh(ftag,  `MEM.tag_rom);
    if ($value$plusargs("data=%s", fdata)) $readmemh(fdata, `MEM.data_ram);

    case (attack)
        1: `MEM.code_rom[5] = `MEM.code_rom[5] ^ 32'h0000_0100;
        2: `MEM.tag_rom[1*(T/32)] = `MEM.tag_rom[1*(T/32)] ^ 32'h8000_0000;
        3: for (i = 0; i < G; i = i + 1) begin
               tmp = `MEM.code_rom[G+i]; `MEM.code_rom[G+i] = `MEM.code_rom[2*G+i]; `MEM.code_rom[2*G+i] = tmp;
           end
        default: ;
    endcase
    if (attack == 3)
        for (i = 0; i < T/32; i = i + 1) begin
            tmp = `MEM.tag_rom[(T/32)+i]; `MEM.tag_rom[(T/32)+i] = `MEM.tag_rom[2*(T/32)+i]; `MEM.tag_rom[2*(T/32)+i] = tmp;
        end

    #23 rst_n = 1;
    while (cyc < maxcyc && !trap && `MEM.data_ram[2] !== 32'hDEADBEEF) @(posedge clk);
    repeat (20) @(posedge clk);   // de lenh ghi CODE (neu co) kip xay ra
    $display("RESULT cyc=%0d trap=%0d auth_fault=%0d d0=%0d d1=%0d d2=%h code0=%h code5=%h",
             cyc, trap, auth_fault, `MEM.data_ram[0], `MEM.data_ram[1], `MEM.data_ram[2], `MEM.code_rom[0], `MEM.code_rom[5]);
    if ($value$plusargs("expect=%s", fexp)) begin
        ok = 0;
        if (fexp == "clean" || fexp == "toctou")
            ok = !trap && !auth_fault && `MEM.data_ram[0] == 55 && `MEM.data_ram[1] == 110
                 && `MEM.data_ram[2] == 32'hDEADBEEF;
        else if (fexp == "fault")
            ok = auth_fault && `MEM.data_ram[2] !== 32'hDEADBEEF;
        else if (fexp == "wcode")
            ok = !trap && auth_fault && `MEM.data_ram[2] == 32'hDEADBEEF && `MEM.code_rom[0] == 32'h00020537;
        $display("CHECK %s attack=%0d expect=%0s", ok ? "PASS" : "FAIL", attack, fexp);
    end
`ifndef PLAIN
    $display("PERF fetch=%0d hit=%0d verify=%0d data=%0d fault=%0d stall=%0d",
             dut.u_auth.perf_fetch, dut.u_auth.perf_hit, dut.u_auth.perf_verify,
             dut.u_auth.perf_data, dut.u_auth.perf_fault, dut.u_auth.perf_stall);
`endif
    $finish;
end
endmodule
