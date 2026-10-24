
module auth_cfg_decode #(
    parameter integer G = 4,     // so word moi block
    parameter integer T = 128    // so bit tag
)(
    input  wire [223:0] cfg,
    output wire [63:0]  program_id,
    output wire [63:0]  image_id,
    output wire [31:0]  code_base,
    output wire [31:0]  code_limit,
    output wire [31:0]  tag_base,
    output wire [31:0]  tag_limit
);
localparam integer LOG2_BLK  = $clog2(4 * G);   
localparam integer LOG2_TAGB = $clog2(T / 8);   

assign program_id = cfg[223:160];
assign image_id   = cfg[159:96];
assign code_base  = cfg[95:64];
assign code_limit = cfg[63:32];
assign tag_base   = cfg[31:0];

assign tag_limit  = tag_base
                  + ((((code_limit - code_base) >> LOG2_BLK) + 32'd1) << LOG2_TAGB)
                  - 32'd1;
endmodule
