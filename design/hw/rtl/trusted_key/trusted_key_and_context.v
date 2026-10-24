module trusted_key_and_context #(
    parameter [127:0] KEY_CODE =
        128'h000102030405060708090A0B0C0D0E0F,

    parameter [63:0] PROGRAM_ID = 64'd1,
    parameter [63:0] IMAGE_ID   = 64'd1,

    parameter [31:0] CODE_BASE  = 32'h00000000,
    parameter [31:0] CODE_LIMIT = 32'h00001FFF,
    parameter [31:0] TAG_BASE   = 32'h00010000
)(
    output wire [127:0] K_code,
    output wire [223:0] CFG
);

assign K_code = KEY_CODE;

assign CFG = {PROGRAM_ID,IMAGE_ID,CODE_BASE,CODE_LIMIT,TAG_BASE};

endmodule