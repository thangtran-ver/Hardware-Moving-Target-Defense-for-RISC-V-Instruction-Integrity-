
module auth_addr_check (
    input  wire [31:0] addr,
    input  wire [3:0]  wstrb,
    input  wire [31:0] code_base,
    input  wire [31:0] code_limit,
    input  wire [31:0] tag_base,
    input  wire [31:0] tag_limit,
    output wire        in_code,
    output wire        wr_protected
);
wire aligned     = (addr[1:0] == 2'b00);
wire in_code_rng = (addr >= code_base) && (addr <= code_limit);
wire in_tag_rng  = (addr >= tag_base)  && (addr <= tag_limit);
wire is_write    = (wstrb != 4'b0000);

assign in_code      = aligned && in_code_rng;
assign wr_protected = is_write && (in_code_rng || in_tag_rng);
endmodule
