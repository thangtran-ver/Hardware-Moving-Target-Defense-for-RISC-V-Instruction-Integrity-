//======================================================================
//  fpga_system_memory.v -- KHOI MOI: ban FPGA cua memory/system_memory.v
//
//  Giu NGUYEN cong, ban do dia chi va giao thuc cua system_memory:
//      CODE  0x0000_0000 .. 0x0000_1FFF   code_rom 2048 word  (chi doc)
//      TAG   0x0001_0000 .. 0x0001_1FFF   tag_rom  2048 word  (chi doc)
//      DATA  0x0002_0000 .. 0x0002_0FFF   data_ram 1024 word  (doc/ghi)
//      mem_valid && !mem_ready  ->  chu ky sau mem_ready = 1 (1 xung),
//      mem_rdata = word doc duoc (0 neu ngoai vung / la lenh ghi).
//
//  Khac system_memory o 2 cho (vi system_memory la mo hinh mo phong):
//    1) Moi mang co thanh ghi doc RIENG -> Gowin suy ra BSRAM.
//       (system_memory doc ca 3 mang vao chung 1 thanh ghi co reset bat
//        dong bo -> tong hop ra ~33 000 flip-flop.)
//    2) Tu nap code/tag/data bang $readmemh (CODE_INIT/TAG_INIT/DATA_INIT).
//       Trong mo phong, tb_auth_soc nap tu ngoai; tren FPGA khong lam vay duoc.
//  Lenh ghi duoc thuc hien ngay chu ky nhan request (system_memory ghi
//  cham hon 1 chu ky); nhin tu wrapper thi nhu nhau vi deu cho mem_ready.
//======================================================================
module fpga_system_memory #(
    parameter CODE_INIT = "code.hex",
    parameter TAG_INIT  = "tag.hex",
    parameter DATA_INIT = "data.hex"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_valid,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_addr,
    output wire [31:0] mem_rdata,
    output reg         mem_ready
);
localparam CODE_BASE = 32'h0;
localparam TAG_BASE  = 32'h00010000;
localparam DATA_BASE = 32'h00020000;
localparam CODE_END  = 32'h00001FFF;
localparam TAG_END   = 32'h00011FFF;
localparam DATA_END  = 32'h00020FFF;

reg [31:0] code_rom [0:2047];
reg [31:0] tag_rom  [0:2047];
reg [31:0] data_ram [0:1023];

initial begin
    $readmemh(CODE_INIT, code_rom);
    $readmemh(TAG_INIT,  tag_rom);
    $readmemh(DATA_INIT, data_ram);
end

wire addr_aligned = (mem_addr[1:0] == 2'b00);
wire code_hit = addr_aligned && (mem_addr >= CODE_BASE) && (mem_addr <= CODE_END);
wire tag_hit  = addr_aligned && (mem_addr >= TAG_BASE)  && (mem_addr <= TAG_END);
wire data_hit = addr_aligned && (mem_addr >= DATA_BASE) && (mem_addr <= DATA_END);

wire [31:0] code_off = mem_addr - CODE_BASE;
wire [31:0] tag_off  = mem_addr - TAG_BASE;
wire [31:0] data_off = mem_addr - DATA_BASE;
wire [10:0] code_index = code_off[12:2];
wire [10:0] tag_index  = tag_off[12:2];
wire [9:0]  data_index = data_off[11:2];

wire acc    = mem_valid && !mem_ready;
wire is_rd  = (mem_wstrb == 4'b0000);
wire wr_dat = acc && !is_rd && data_hit;

reg [31:0] code_q, tag_q, data_q;
reg [2:0]  sel_q;                       // {code, tag, data}

always @(posedge clk) if (acc) code_q <= code_rom[code_index];
always @(posedge clk) if (acc) tag_q  <= tag_rom[tag_index];

always @(posedge clk) begin
    if (acc) begin
        data_q <= data_ram[data_index];
        if (wr_dat && mem_wstrb[0]) data_ram[data_index][ 7: 0] <= mem_wdata[ 7: 0];
        if (wr_dat && mem_wstrb[1]) data_ram[data_index][15: 8] <= mem_wdata[15: 8];
        if (wr_dat && mem_wstrb[2]) data_ram[data_index][23:16] <= mem_wdata[23:16];
        if (wr_dat && mem_wstrb[3]) data_ram[data_index][31:24] <= mem_wdata[31:24];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_ready <= 1'b0;
        sel_q     <= 3'b000;
    end else begin
        mem_ready <= acc;
        if (acc)
            sel_q <= is_rd ? {code_hit, tag_hit, data_hit} : 3'b000;
    end
end

assign mem_rdata = sel_q[2] ? code_q :
                   sel_q[1] ? tag_q  :
                   sel_q[0] ? data_q : 32'b0;

endmodule
