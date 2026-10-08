module ascon_controller (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire ad_empty,

    input wire ad_valid,
    input wire [4:0] nbytes_q,
    input wire last_q,

    input wire p8_done,
    input wire p12_done,

    output reg kn_we,
    output reg ad_we,
    output reg state_we,
    output reg tag_we,

    output reg [2:0] sel,
    output reg [1:0] pad_sel,

    output reg p8_start,
    output reg p12_start,

    output reg ad_ready,
    output reg busy,
    output reg done
);

localparam [4:0]
    IDLE             = 5'd0,
    LOAD_INIT        = 5'd1,
    START_P12_INIT   = 5'd2,
    WAIT_P12_INIT    = 5'd3,
    POST_INIT        = 5'd4,
    WAIT_AD          = 5'd5,
    AD_ABSORB        = 5'd6,
    START_P8_AD      = 5'd7,
    WAIT_P8_AD       = 5'd8,
    PAD_ONLY         = 5'd9,
    START_P8_PAD     = 5'd10,
    WAIT_P8_PAD      = 5'd11,
    FINAL_PRE        = 5'd12,
    START_P12_FINAL  = 5'd13,
    WAIT_P12_FINAL   = 5'd14,
    TAG_WRITE        = 5'd15,
    DONE             = 5'd16;

reg [4:0] state;
reg [4:0] next_state;
reg ad_empty_q;

// Thanh ghi trang thai FSM va co AD rong.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        ad_empty_q <= 1'b0;
    end else begin
        state <= next_state;

        // Nhan start o IDLE va ca o DONE (back-to-back, khong mat xung start).
        if (((state == IDLE) || (state == DONE)) && start) begin
            ad_empty_q <= ad_empty;
        end
    end
end

// Logic chuyen trang thai va cac tin hieu dieu khien.
always @(*) begin
    next_state = state;

    kn_we = 1'b0;
    ad_we = 1'b0;
    state_we = 1'b0;
    tag_we = 1'b0;

    sel = 3'b000;
    pad_sel = 2'b00;

    p8_start = 1'b0;
    p12_start = 1'b0;

    ad_ready = 1'b0;
    busy = 1'b1;
    done = 1'b0;

    case (state)
        IDLE: begin
            busy = 1'b0;

            if (start) begin
                kn_we = 1'b1;
                next_state = LOAD_INIT;
            end
        end

        LOAD_INIT: begin
            sel = 3'b000;
            state_we = 1'b1;
            next_state = START_P12_INIT;
        end

        START_P12_INIT: begin
            p12_start = 1'b1;
            next_state = WAIT_P12_INIT;
        end

        WAIT_P12_INIT: begin
            sel = 3'b101;
            state_we = p12_done;

            if (p12_done) begin
                next_state = POST_INIT;
            end
        end

        POST_INIT: begin
            sel = 3'b001;
            state_we = 1'b1;

            if (ad_empty_q) begin
                next_state = FINAL_PRE;
            end else begin
                next_state = WAIT_AD;
            end
        end

        WAIT_AD: begin
            ad_ready = 1'b1;
            ad_we = ad_valid && ad_ready;

            if (ad_valid && ad_ready) begin
                next_state = AD_ABSORB;
            end
        end

        AD_ABSORB: begin
            sel = 3'b010;
            state_we = 1'b1;

            if (nbytes_q == 5'd16) begin
                pad_sel = 2'b00;
            end else begin
                pad_sel = 2'b01;
            end

            next_state = START_P8_AD;
        end

        START_P8_AD: begin
            p8_start = 1'b1;
            next_state = WAIT_P8_AD;
        end

        WAIT_P8_AD: begin
            sel = 3'b100;
            state_we = p8_done;

            if (p8_done) begin
                if (!last_q) begin
                    next_state = WAIT_AD;
                end else if (nbytes_q == 5'd16) begin
                    next_state = PAD_ONLY;
                end else begin
                    next_state = FINAL_PRE;
                end
            end
        end

        PAD_ONLY: begin
            pad_sel = 2'b10;
            sel = 3'b010;
            state_we = 1'b1;
            next_state = START_P8_PAD;
        end

        START_P8_PAD: begin
            p8_start = 1'b1;
            next_state = WAIT_P8_PAD;
        end

        WAIT_P8_PAD: begin
            sel = 3'b100;
            state_we = p8_done;

            if (p8_done) begin
                next_state = FINAL_PRE;
            end
        end

        FINAL_PRE: begin
            sel = 3'b011;
            state_we = 1'b1;
            next_state = START_P12_FINAL;
        end

        START_P12_FINAL: begin
            p12_start = 1'b1;
            next_state = WAIT_P12_FINAL;
        end

        WAIT_P12_FINAL: begin
            sel = 3'b101;
            state_we = p12_done;

            if (p12_done) begin
                next_state = TAG_WRITE;
            end
        end

        TAG_WRITE: begin
            tag_we = 1'b1;
            next_state = DONE;
        end

        DONE: begin
            busy = 1'b0;
            done = 1'b1;

            // Start trung chu ky done: bat dau lan moi ngay, khong ve IDLE.
            if (start) begin
                kn_we = 1'b1;
                next_state = LOAD_INIT;
            end else begin
                next_state = IDLE;
            end
        end

        default: begin
            busy = 1'b0;
            next_state = IDLE;
        end
    endcase
end

endmodule
