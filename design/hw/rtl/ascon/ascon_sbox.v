module ascon_sbox (
    input  wire [63:0] x0, x1, x2, x3, x4,
    output reg  [63:0] y0, y1, y2, y3, y4
);

reg [4:0] sbox_in  [63:0];
reg [4:0] sbox_out [63:0];

integer i;
integer j;
integer k;

// Gom 1 bit tu moi word thanh dau vao S-box 5 bit.
always @(*) begin
    for (i = 0; i < 64; i = i + 1) begin
        sbox_in[i] = {x0[i], x1[i], x2[i], x3[i], x4[i]};
    end
end

// Tra bang S-box cho tung vi tri bit.
always @(*) begin
    for (j = 0; j < 64; j = j + 1) begin
        case (sbox_in[j])
            5'b00000: sbox_out[j] = 5'b00100;
            5'b00001: sbox_out[j] = 5'b01011;
            5'b00010: sbox_out[j] = 5'b11111;
            5'b00011: sbox_out[j] = 5'b10100;
            5'b00100: sbox_out[j] = 5'b11010;
            5'b00101: sbox_out[j] = 5'b10101;
            5'b00110: sbox_out[j] = 5'b01001;
            5'b00111: sbox_out[j] = 5'b00010;
            5'b01000: sbox_out[j] = 5'b11011;
            5'b01001: sbox_out[j] = 5'b00101;
            5'b01010: sbox_out[j] = 5'b01000;
            5'b01011: sbox_out[j] = 5'b10010;
            5'b01100: sbox_out[j] = 5'b11101;
            5'b01101: sbox_out[j] = 5'b00011;
            5'b01110: sbox_out[j] = 5'b00110;
            5'b01111: sbox_out[j] = 5'b11100;
            5'b10000: sbox_out[j] = 5'b11110;
            5'b10001: sbox_out[j] = 5'b10011;
            5'b10010: sbox_out[j] = 5'b00111;
            5'b10011: sbox_out[j] = 5'b01110;
            5'b10100: sbox_out[j] = 5'b00000;
            5'b10101: sbox_out[j] = 5'b01101;
            5'b10110: sbox_out[j] = 5'b10001;
            5'b10111: sbox_out[j] = 5'b11000;
            5'b11000: sbox_out[j] = 5'b10000;
            5'b11001: sbox_out[j] = 5'b01100;
            5'b11010: sbox_out[j] = 5'b00001;
            5'b11011: sbox_out[j] = 5'b11001;
            5'b11100: sbox_out[j] = 5'b10110;
            5'b11101: sbox_out[j] = 5'b01010;
            5'b11110: sbox_out[j] = 5'b01111;
            5'b11111: sbox_out[j] = 5'b10111;
            default:  sbox_out[j] = 5'b00000;
        endcase
    end
end

// Tach 5 bit ket qua ve 5 word output.
always @(*) begin
    for (k = 0; k < 64; k = k + 1) begin
        {y0[k], y1[k], y2[k], y3[k], y4[k]} = sbox_out[k];
    end
end

endmodule