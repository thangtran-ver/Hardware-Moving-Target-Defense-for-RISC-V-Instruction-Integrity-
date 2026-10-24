module auth_perf_counters (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        inc_fetch,    // moi lan CPU fetch
    input  wire        inc_hit,      // fetch trung buffer
    input  wire        inc_verify,   // moi lan chay Ascon
    input  wire        inc_data,     // moi truy cap data
    input  wire        inc_fault,    // moi lan vao FAULT
    input  wire        inc_stall,    // moi chu ky CPU cho trong fetch
    output reg  [31:0] perf_fetch,
    output reg  [31:0] perf_hit,
    output reg  [31:0] perf_verify,
    output reg  [31:0] perf_data,
    output reg  [31:0] perf_fault,
    output reg  [31:0] perf_stall
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        perf_fetch  <= 32'd0;
        perf_hit    <= 32'd0;
        perf_verify <= 32'd0;
        perf_data   <= 32'd0;
        perf_fault  <= 32'd0;
        perf_stall  <= 32'd0;
    end else begin
        if (inc_fetch)  perf_fetch  <= perf_fetch  + 32'd1;
        if (inc_hit)    perf_hit    <= perf_hit    + 32'd1;
        if (inc_verify) perf_verify <= perf_verify + 32'd1;
        if (inc_data)   perf_data   <= perf_data   + 32'd1;
        if (inc_fault)  perf_fault  <= perf_fault  + 32'd1;
        if (inc_stall)  perf_stall  <= perf_stall  + 32'd1;
    end
end
endmodule
