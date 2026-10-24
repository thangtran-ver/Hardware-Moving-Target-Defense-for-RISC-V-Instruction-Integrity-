
module auth_code_buffer #(
    parameter integer G = 4
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          we,
    input  wire [3:0]    widx,
    input  wire [31:0]   wdata,
    input  wire          inv,
    input  wire          set,
    input  wire [31:0]   set_blk,
    input  wire [31:0]   lookup_blk,
    input  wire [2:0]    rd_idx,
    output wire          hit,
    output wire [31:0]   rdata,
    output wire [32*G-1:0] code_flat
);
reg [31:0] word_q [0:G-1];
reg        valid_q;
reg [31:0] blk_q;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < G; i = i + 1) word_q[i] <= 32'b0;
        valid_q <= 1'b0;
        blk_q   <= 32'b0;
    end else begin
        if (we)
            word_q[widx] <= wdata;
        if (inv)
            valid_q <= 1'b0;
        else if (set) begin
            valid_q <= 1'b1;
            blk_q   <= set_blk;
        end
    end
end

assign hit   = valid_q && (blk_q == lookup_blk);
assign rdata = word_q[rd_idx];

genvar gi;
generate
    for (gi = 0; gi < G; gi = gi + 1) begin : g_flat
        assign code_flat[32*G-1-32*gi -: 32] = word_q[gi];
    end
endgenerate
endmodule
