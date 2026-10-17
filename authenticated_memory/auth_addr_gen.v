
module auth_addr_gen #(
    parameter integer G = 4,
    parameter integer T = 128
)(
    input  wire [31:0] req_addr,
    input  wire [31:0] code_base,
    input  wire [31:0] tag_base,
    input  wire [3:0]  cnt,
    output wire [31:0] blk_base,
    output wire [2:0]  word_off,
    output wire [31:0] code_addr,
    output wire [31:0] tag_addr
);
localparam integer BLK_BYTES = 4 * G;
localparam integer LOG2_BLK  = $clog2(BLK_BYTES);
localparam integer LOG2_TAGB = $clog2(T / 8);
localparam [31:0]  BLK_MASK  = ~(BLK_BYTES - 1);

wire [31:0] off_bytes = req_addr & (BLK_BYTES - 1);
wire [31:0] blk_index = (blk_base - code_base) >> LOG2_BLK;

assign blk_base  = req_addr & BLK_MASK;
assign word_off  = off_bytes[4:2];
assign code_addr = blk_base + {cnt, 2'b00};
assign tag_addr  = tag_base + (blk_index << LOG2_TAGB) + {cnt, 2'b00};
endmodule
