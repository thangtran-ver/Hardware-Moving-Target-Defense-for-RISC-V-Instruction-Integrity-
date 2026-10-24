module ascon_ad_buffer_padding(
input wire clk,
input wire rst_n,
input wire [127:0] data_d,
input wire [4:0] nbytes_d,
input wire last_d,
input wire we,
input wire [1:0] pad_sel,
output reg [127:0] block_out,
output reg [4:0] nbytes_q,
output reg last_q);
reg [127:0] data_q;
always @(posedge clk or negedge rst_n) begin
if(!rst_n) begin
data_q <= 0;
nbytes_q <= 0;
last_q <= 0;
end
else if(we) begin
data_q <= data_d;
nbytes_q <= nbytes_d;
last_q <= last_d;
end
end
always @(*) begin
    case (pad_sel)

        // Xuat nguyen block AD.
        2'b00: block_out = data_q;

        // Giu cac byte hop le, them 80, roi dien 00.
        2'b01: begin
            case (nbytes_q)
                5'd0:  block_out = 128'h80000000000000000000000000000000;
                5'd1:  block_out = {data_q[127:120], 8'h80, 112'b0};
                5'd2:  block_out = {data_q[127:112], 8'h80, 104'b0};
                5'd3:  block_out = {data_q[127:104], 8'h80, 96'b0};
                5'd4:  block_out = {data_q[127:96],  8'h80, 88'b0};
                5'd5:  block_out = {data_q[127:88],  8'h80, 80'b0};
                5'd6:  block_out = {data_q[127:80],  8'h80, 72'b0};
                5'd7:  block_out = {data_q[127:72],  8'h80, 64'b0};
                5'd8:  block_out = {data_q[127:64],  8'h80, 56'b0};
                5'd9:  block_out = {data_q[127:56],  8'h80, 48'b0};
                5'd10: block_out = {data_q[127:48],  8'h80, 40'b0};
                5'd11: block_out = {data_q[127:40],  8'h80, 32'b0};
                5'd12: block_out = {data_q[127:32],  8'h80, 24'b0};
                5'd13: block_out = {data_q[127:24],  8'h80, 16'b0};
                5'd14: block_out = {data_q[127:16],  8'h80, 8'b0};
                5'd15: block_out = {data_q[127:8],   8'h80};
                default: block_out = 128'b0;
            endcase
        end

        // Tao block chi co padding.
        2'b10: block_out = 128'h80000000000000000000000000000000;

        // Chua su dung.
        2'b11: block_out = 128'b0;

        default: block_out = 128'b0;
    endcase
end
endmodule
