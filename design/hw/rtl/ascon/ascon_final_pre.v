module ascon_final_pre (
    input wire [63:0] S0,
    input wire [63:0] S1,
    input wire [63:0] S2,
    input wire [63:0] S3,
    input wire [63:0] S4,
    input wire [63:0] K0,
    input wire [63:0] K1,

    output wire [319:0] D_FINAL
);

wire [63:0] a0, a1, a2, a3, a4;

// Padding plaintext rong.
assign a0 = S0 ^ 64'h8000000000000000;

// S1 giu nguyen.
assign a1 = S1;

// XOR key truoc P12 cuoi.
assign a2 = S2 ^ K0;
assign a3 = S3 ^ K1;

// Domain separation.
assign a4 = S4 ^ 64'h0000000000000001;

assign D_FINAL = {a0, a1, a2, a3, a4};

endmodule