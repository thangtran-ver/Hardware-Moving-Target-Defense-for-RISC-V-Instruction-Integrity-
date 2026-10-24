module ascon_p12 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x0, x1, x2, x3, x4,
    output wire [63:0] y0, y1, y2, y3, y4,
    output reg busy,
    output reg done
);

reg [7:0] constant;
reg [3:0] round_index;
reg [63:0] s0, s1, s2, s3, s4;

wire [63:0] next_s0, next_s1, next_s2, next_s3, next_s4;

always @(*) begin
    case (round_index)
        4'b0000: constant = 8'hF0;
        4'b0001: constant = 8'hE1;
        4'b0010: constant = 8'hD2;
        4'b0011: constant = 8'hC3;
        4'b0100: constant = 8'hB4;
        4'b0101: constant = 8'hA5;
        4'b0110: constant = 8'h96;
        4'b0111: constant = 8'h87;
		  4'b1000: constant = 8'h78;
        4'b1001: constant = 8'h69;
        4'b1010: constant = 8'h5A;
        4'b1011: constant = 8'h4B;
        default: constant = 8'h00;
    endcase
end

ascon_round dut (
    .x0(s0),
    .x1(s1),
    .x2(s2),
    .x3(s3),
    .x4(s4),
    .constant(constant),
    .y0(next_s0),
    .y1(next_s1),
    .y2(next_s2),
    .y3(next_s3),
    .y4(next_s4)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s0 <= 64'b0;
        s1 <= 64'b0;
        s2 <= 64'b0;
        s3 <= 64'b0;
        s4 <= 64'b0;

        round_index <= 0;
        busy <= 1'b0;
        done <= 1'b0;
    end else begin
        done <= 1'b0;

        // MUX chon dau vao/hoi tiep, roi chot vao thanh ghi.
        if (busy || start) begin
            s0 <= busy ? next_s0 : x0;
            s1 <= busy ? next_s1 : x1;
            s2 <= busy ? next_s2 : x2;
            s3 <= busy ? next_s3 : x3;
            s4 <= busy ? next_s4 : x4;
        end

        if (!busy) begin
            if (start) begin
                round_index <= 3'b000;
                busy <= 1'b1;
            end
        end else begin
            if (round_index == 4'b1011) begin
                // Ket qua round thu 8 da duoc chot vao s.
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                round_index <= round_index + 3'b001;
            end
        end
    end
end

// Xuat trang thai cuoi da luu khi done = 1.
assign y0 = done ? s0 : 64'b0;
assign y1 = done ? s1 : 64'b0;
assign y2 = done ? s2 : 64'b0;
assign y3 = done ? s3 : 64'b0;
assign y4 = done ? s4 : 64'b0;

endmodule
