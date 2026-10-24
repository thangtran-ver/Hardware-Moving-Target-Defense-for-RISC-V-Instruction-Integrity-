module auth_tag_compare #(
    parameter integer T = 128
)(
    input  wire [127:0] a_tag,
    input  wire [T-1:0] tag_ref,
    output wire         tag_ok
);
assign tag_ok = (a_tag[127 -: T] == tag_ref);
endmodule
