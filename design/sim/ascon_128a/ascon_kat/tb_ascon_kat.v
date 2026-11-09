`timescale 1ns/1ps
// Testbench KAT cho ascon_top (Ascon-128a, chi xac thuc AD, PT rong).
// Doc kat_vectors.txt (tao boi gen_vectors.py), so tag_out voi CT trong KAT.
module tb_ascon_kat;
    reg          clk = 0, rst_n = 0, start = 0, ad_empty = 0;
    reg  [127:0] key_d = 0, nonce_d = 0, ad_data = 0;
    reg  [4:0]   ad_nbytes = 0;
    reg          ad_last = 0, ad_valid = 0;
    wire         ad_ready, done, busy;
    wire [127:0] tag_out;

    ascon_top dut (.clk(clk), .rst_n(rst_n), .start(start), .ad_empty(ad_empty),
                   .key_d(key_d), .nonce_d(nonce_d),
                   .ad_data(ad_data), .ad_nbytes(ad_nbytes), .ad_last(ad_last),
                   .ad_valid(ad_valid), .ad_ready(ad_ready),
                   .tag_out(tag_out), .done(done), .busy(busy));

    always #5 clk = ~clk;   // 100 MHz

    integer fd, rc, n_total, n_pass, n_fail, adlen, i, nblk, cyc;
    reg [127:0] k, nn, exp_tag, got_tag;
    reg [255:0] ad;
    reg [127:0] blk;
    reg         got_done;

    task run_vector;
        begin
            ad_empty = (adlen == 0);
            key_d = k; nonce_d = nn;
            @(posedge clk); #1 start = 1;
            @(posedge clk); #1 start = 0;
            // so khoi AD: 0 neu rong, nguoc lai ceil(adlen/16)
            nblk = (adlen + 15) / 16;
            for (i = 0; i < nblk; i = i + 1) begin
                blk       = ad[255 - 128*i -: 128];
                ad_data   = blk;
                ad_last   = (i == nblk - 1);
                ad_nbytes = (i == nblk - 1) ? (adlen - 16*i) : 5'd16;
                ad_valid  = 1;
                cyc = 0;
                @(posedge clk);
                while (!ad_ready && cyc < 100) begin @(posedge clk); cyc = cyc + 1; end
                #1 ad_valid = 0; ad_last = 0; ad_nbytes = 0; ad_data = 0;
            end
            // cho done
            got_done = 0; cyc = 0;
            while (!got_done && cyc < 2000) begin
                @(posedge clk);
                if (done) begin got_done = 1; got_tag = tag_out; end
                cyc = cyc + 1;
            end
        end
    endtask

    initial begin
        n_total = 0; n_pass = 0; n_fail = 0;
        repeat (4) @(posedge clk);
        #1 rst_n = 1;
        repeat (2) @(posedge clk);

        $display("==================== ASCON-128a KAT (tag, PT rong) ====================");
        fd = $fopen("kat_vectors.txt", "r");
        if (fd == 0) begin $display("[tb] LOI: khong mo duoc kat_vectors.txt (chay gen_vectors.py truoc)"); $finish; end

        while (!$feof(fd)) begin
            rc = $fscanf(fd, "%h %h %d %h %h\n", k, nn, adlen, ad, exp_tag);
            if (rc == 5) begin
                run_vector;
                n_total = n_total + 1;
                if (got_done && got_tag === exp_tag) begin
                    n_pass = n_pass + 1;
                    $display("[%2d] AD=%2d byte | expected = %032h | result = %032h | PASS", n_total, adlen, exp_tag, got_tag);
                end else begin
                    n_fail = n_fail + 1;
                    $display("[%2d] AD=%2d byte | expected = %032h | result = %032h | FAIL%s", n_total, adlen, exp_tag, got_tag, got_done ? "" : " (timeout, khong co done)");
                end
                repeat (3) @(posedge clk);
            end
        end
        $fclose(fd);

        $display("=============================== THONG KE ===============================");
        $display("  Tong so vector : %0d", n_total);
        $display("  PASS           : %0d", n_pass);
        $display("  FAIL           : %0d", n_fail);
        $display("  Ty le dung     : %0d%%", (n_total > 0) ? (n_pass * 100 / n_total) : 0);
        if (n_fail == 0 && n_total > 0) $display("  KET QUA CHUNG  : PASS"); else $display("  KET QUA CHUNG  : FAIL");
        $display("========================================================================");
        $finish;
    end

    // waveform (chi hoat dong khi bien dich voi --trace)
    initial if ($test$plusargs("wave")) begin $dumpfile("wave.vcd"); $dumpvars(0, tb_ascon_kat); end

    // watchdog
    initial begin #50_000_000; $display("[tb] TIMEOUT"); $finish; end
endmodule
