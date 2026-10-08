module ascon_p8 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x0, x1, x2, x3, x4,
    output wire [63:0] y0, y1, y2, y3, y4,
    output reg busy,
    output reg done
);

reg [7:0] constant;
reg [2:0] round_index;
reg [63:0] s0, s1, s2, s3, s4;

wire [63:0] next_s0, next_s1, next_s2, next_s3, next_s4;

always @(*) begin
    case (round_index)
        3'b000: constant = 8'hB4;
        3'b001: constant = 8'hA5;
        3'b010: constant = 8'h96;
        3'b011: constant = 8'h87;
        3'b100: constant = 8'h78;
        3'b101: constant = 8'h69;
        3'b110: constant = 8'h5A;
        3'b111: constant = 8'h4B;
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

        round_index <= 3'b000;
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
            if (round_index == 3'b111) begin
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
