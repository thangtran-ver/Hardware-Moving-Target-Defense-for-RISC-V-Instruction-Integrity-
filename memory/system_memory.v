module system_memory (
input wire clk,
input wire rst_n,
input wire mem_valid,
input wire [31:0] mem_wdata,
input wire [3:0] mem_wstrb,
input wire [31:0] mem_addr,
output reg [31:0] mem_rdata,
output reg mem_ready);
localparam CODE_BASE = 32'h0;
localparam TAG_BASE = 32'h00010000;
localparam DATA_BASE = 32'h00020000;
localparam CODE_END = 32'h00001FFF;
localparam TAG_END = 32'h00011FFF;
localparam DATA_END = 32'h00020FFF;
reg [31:0] code_rom [0:2047];
reg [31:0] tag_rom  [0:2047];
reg [31:0] data_ram [0:1023];
wire addr_aligned;
wire code_hit, tag_hit, data_hit;

wire [10:0] code_index;  // 0..2047
wire [10:0] tag_index;   // 0..2047
wire [9:0]  data_index;  // 0..1023

assign addr_aligned = (mem_addr[1:0] == 2'b00);

assign code_hit = addr_aligned &&
                  (mem_addr >= CODE_BASE) &&
                  (mem_addr <= CODE_END);

assign tag_hit = addr_aligned &&
                 (mem_addr >= TAG_BASE) &&
                 (mem_addr <= TAG_END);

assign data_hit = addr_aligned &&
                  (mem_addr >= DATA_BASE) &&
                  (mem_addr <= DATA_END);

assign code_index = (mem_addr - CODE_BASE) >> 2;
assign tag_index  = (mem_addr - TAG_BASE)  >> 2;
assign data_index = (mem_addr - DATA_BASE) >> 2;
reg        write_pending; // co yeu cau dang ghi ko
reg [9:0]  write_index_q; //ghi vao word nao tu 0..1023
reg [31:0] write_data_q; //gia tri 32 bit can ghi
reg [3:0]  write_strb_q; // chon byte can ghi
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_ready <= 1'b0;
        mem_rdata <= 32'b0;

        write_pending <= 1'b0;
        write_index_q <= 10'b0;
        write_data_q <= 32'b0;
        write_strb_q <= 4'b0;

    end else begin
        mem_ready <= 1'b0;
        write_pending <= 1'b0;

        if (write_pending && mem_valid && mem_ready) begin

            if (write_strb_q[0]) begin
                data_ram[write_index_q][7:0]
                    <= write_data_q[7:0];
            end

            if (write_strb_q[1]) begin
                data_ram[write_index_q][15:8]
                    <= write_data_q[15:8];
            end

            if (write_strb_q[2]) begin
                data_ram[write_index_q][23:16]
                    <= write_data_q[23:16];
            end

            if (write_strb_q[3]) begin
                data_ram[write_index_q][31:24]
                    <= write_data_q[31:24];
            end

        end else if (mem_valid && !mem_ready) begin
            mem_ready <= 1'b1;
            mem_rdata <= 32'b0;

            if (mem_wstrb == 4'b0000) begin
                if (code_hit) begin
                    mem_rdata <= code_rom[code_index];
                end else if (tag_hit) begin
                    mem_rdata <= tag_rom[tag_index];
                end else if (data_hit) begin
                    mem_rdata <= data_ram[data_index];
                end

            end else if (data_hit) begin
                write_pending <= 1'b1;
                write_index_q <= data_index;
                write_data_q <= mem_wdata;
                write_strb_q <= mem_wstrb;
            end
        end
    end
end

endmodule
