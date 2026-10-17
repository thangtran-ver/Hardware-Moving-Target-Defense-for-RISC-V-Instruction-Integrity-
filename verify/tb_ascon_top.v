`timescale 1ns/1ps
// Full-system test of ascon_mac_top (ascon_controller + datapath).
//   * top_vec.txt: official Ascon-128a v1.2 KAT (PT empty, AD 0..32 B),
//     tb/vec.txt vectors, 3000 random vectors (AD 0..256 B, random key/nonce)
//   * random ad_valid stalls, garbage on idle bus / invalid byte lanes,
//     key/nonce changed right after start, random reset mid-operation
//   * checks: tag, number of AD beats consumed, latency (clean vectors),
//     X on outputs, tag stable outside DONE, FSM transition coverage
// Stimulus is driven on negedge, DUT samples on posedge (race-free).
module tb_ascon_top;
localparam MAXB = 256;
localparam NCLEAN = 42;            // 33 official KAT + 9 vectors of tb/vec.txt

reg clk = 0, rst_n = 0;
always #5 clk = ~clk;

reg          start = 0, ad_empty = 0, ad_valid = 0, ad_last = 0;
reg  [127:0] key = 0, nonce = 0, ad_data = 0;
reg  [4:0]   ad_nbytes = 0;
wire         ad_ready, busy, done;
wire [127:0] tag;

ascon_top dut (.clk(clk), .rst_n(rst_n), .start(start), .ad_empty(ad_empty),
    .key_d(key), .nonce_d(nonce), .ad_valid(ad_valid), .ad_ready(ad_ready),
    .ad_data(ad_data), .ad_nbytes(ad_nbytes), .ad_last(ad_last),
    .tag_out(tag), .busy(busy), .done(done));

// ---------------------------------------------------------------- monitors
integer cyc = 0, hs = 0, errs = 0;
reg [127:0] tag_prev = 0;
reg         mon_on = 0;
always @(posedge clk) begin
    cyc <= cyc + 1;
    if (ad_valid && ad_ready) hs <= hs + 1;
end
always @(negedge clk) begin #2; if (rst_n && mon_on) begin
    if (^{tag, busy, done, ad_ready} === 1'bx) begin
        errs = errs + 1; $display("ERROR: X on outputs at cyc %0d", cyc);
    end
    if (tag !== tag_prev && !done) begin
        errs = errs + 1; $display("ERROR: tag changed outside DONE at cyc %0d", cyc);
    end
    if (done && busy)      begin errs = errs + 1; $display("ERROR: done && busy");        end
    if (ad_ready && !busy) begin errs = errs + 1; $display("ERROR: ad_ready while idle"); end
    tag_prev = tag;
end end

// watchdog: a hung handshake / FSM must fail fast instead of hanging the sim
integer wd = 0;
always @(negedge clk) begin
    if (done || !mon_on) wd = 0; else wd = wd + 1;
    if (wd > 20000) begin
        $display("ERROR: watchdog - no done for 20000 cycles (FSM state %0d)", dut.u_ctrl.state);
        $display("RESULT: FAIL"); $finish;
    end
end

// FSM transition coverage (hierarchical probe into the controller)
integer cov [0:1023];
integer ci;
initial for (ci = 0; ci < 1024; ci = ci + 1) cov[ci] = 0;
always @(posedge clk)
    if (rst_n && (dut.u_ctrl.state != dut.u_ctrl.next_state))
        cov[{dut.u_ctrl.state, dut.u_ctrl.next_state}] = cov[{dut.u_ctrl.state, dut.u_ctrl.next_state}] + 1;

// ---------------------------------------------------------------- stimulus
reg [11:0]        L;
reg [127:0]       vkey, vnonce, exp_tag;
reg [3:0]         term0;
reg [MAXB*8-1:0]  ad;
integer fd, nvec = 0, nb, j, rem, bytes, c0, lat, exp_lat, hs0, k, rst_at;
integer max_stall, garbage, gap;
reg     aborted, body_done;
integer t_rst;
integer seed = 32'h5EED_A5C0;
reg [127:0] mask, junk;
reg [4:0]   nbv;

function [127:0] rnd128; input dummy;
    rnd128 = {$random(seed), $random(seed), $random(seed), $random(seed)};
endfunction

task idle_cycles(input integer n);
    integer t;
    for (t = 0; t < n; t = t + 1) begin
        @(negedge clk);
        if (garbage) begin
            ad_data = rnd128(0); ad_nbytes = $random(seed); ad_last = $random(seed);
        end
    end
endtask

// one AD beat with valid/ready handshake; returns early if reset hits
task send_beat(input [127:0] d, input [4:0] n, input l);
    begin
        idle_cycles(max_stall ? ($unsigned($random(seed)) % (max_stall + 1)) : 0);
        @(negedge clk);
        ad_valid = 1; ad_data = d; ad_nbytes = n; ad_last = l;
        while (!ad_ready && !aborted) @(negedge clk);
        @(posedge clk); #1;
        ad_valid = 0;
        if (garbage) begin ad_data = rnd128(0); ad_nbytes = $random(seed); ad_last = $random(seed); end
    end
endtask

task drive_ad_and_wait;
    begin
        if (L != 0) begin
            nb  = (L + 15) / 16;
            rem = L;
            for (j = 0; j < nb && !aborted; j = j + 1) begin
                bytes = (rem >= 16) ? 16 : rem;
                mask  = ~(128'h0) << (8 * (16 - bytes));
                junk  = garbage ? rnd128(0) : 128'h0;      // junk in unused byte lanes
                nbv   = bytes;
                send_beat((ad[MAXB*8-1 - 128*j -: 128] & mask) | (junk & ~mask), nbv,
                          (j == nb - 1) && (term0 == 0));
                rem = rem - bytes;
            end
            if (term0 != 0 && !aborted) send_beat(rnd128(0), 5'd0, 1'b1);  // 0-byte terminator
        end
        while (!done && !aborted) @(negedge clk);
    end
endtask

// one tag computation; rst_cycle >= 0 -> pulse reset that many cycles after start
task run_one(input integer rst_cycle);
    begin
        aborted = 0;
        @(negedge clk);
        key = vkey; nonce = vnonce; ad_empty = (L == 0); start = 1;
        c0 = cyc; hs0 = hs;
        @(negedge clk);
        start = 0;
        if (garbage) begin key = rnd128(0); nonce = rnd128(0); ad_empty = $random(seed); end
        if (rst_cycle >= 0) begin
            body_done = 0;
            fork
                begin : RST
                    t_rst = 0;
                    while (t_rst < rst_cycle && !body_done) begin @(negedge clk); t_rst = t_rst + 1; end
                    if (!body_done) begin
                        rst_n = 0; aborted = 1; @(negedge clk); rst_n = 1; tag_prev = 0;
                    end
                end
                begin : BODY
                    drive_ad_and_wait;
                    body_done = 1;
                end
            join
        end else
            drive_ad_and_wait;
    end
endtask

task cov_report;
    integer t, miss, extra, a, b, known;
    reg [9:0] tr [0:20];
    begin
        tr[0]  = {5'd0, 5'd1};   tr[1]  = {5'd1, 5'd2};   tr[2]  = {5'd2, 5'd3};
        tr[3]  = {5'd3, 5'd4};   tr[4]  = {5'd4, 5'd12};  tr[5]  = {5'd4, 5'd5};
        tr[6]  = {5'd5, 5'd6};   tr[7]  = {5'd6, 5'd7};   tr[8]  = {5'd7, 5'd8};
        tr[9]  = {5'd8, 5'd5};   tr[10] = {5'd8, 5'd9};   tr[11] = {5'd8, 5'd12};
        tr[12] = {5'd9, 5'd10};  tr[13] = {5'd10, 5'd11}; tr[14] = {5'd11, 5'd12};
        tr[15] = {5'd12, 5'd13}; tr[16] = {5'd13, 5'd14}; tr[17] = {5'd14, 5'd15};
        tr[18] = {5'd15, 5'd16}; tr[19] = {5'd16, 5'd0};
        tr[20] = {5'd16, 5'd1};   // DONE -> LOAD_INIT (start back-to-back)
        miss = 0; extra = 0;
        for (t = 0; t < 21; t = t + 1)
            if (cov[tr[t]] == 0) begin miss = miss + 1; $display("COV MISS %0d->%0d", tr[t][9:5], tr[t][4:0]); end
        for (a = 0; a < 32; a = a + 1) for (b = 0; b < 32; b = b + 1) if (cov[a*32+b] != 0) begin
            known = 0;
            for (t = 0; t < 21; t = t + 1) if (tr[t] == a*32+b) known = 1;
            if (!known) begin extra = extra + 1; errs = errs + 1; $display("ERROR: unexpected FSM transition %0d->%0d", a, b); end
        end
        $display("FSM transition coverage: %0d/21 (unexpected: %0d)", 21 - miss, extra);
    end
endtask

integer nk = 0, nrst = 0, nlat = 0;
initial begin
    #23 rst_n = 1;
    @(negedge clk); mon_on = 1;
    fd = $fopen("top_vec.txt", "r");
    if (fd == 0) begin $display("ERROR: cannot open top_vec.txt"); $finish; end
    while ($fscanf(fd, "%h %h %h %h %h %h\n", L, vkey, vnonce, term0, ad, exp_tag) == 6) begin
        max_stall = (nvec < NCLEAN) ? 0 : 3;
        garbage   = (nvec >= NCLEAN);
        gap       = (nvec < NCLEAN) ? 0 : ($unsigned($random(seed)) % 3);
        idle_cycles(gap);
        rst_at = -1;
        if (nvec >= NCLEAN && ($unsigned($random(seed)) % 50) == 0) rst_at = 1 + ($unsigned($random(seed)) % 40);
        run_one(rst_at);
        if (aborted) begin                 // reset hit mid-run: redo the vector
            nrst = nrst + 1;
            run_one(-1);
        end
        lat = cyc - c0;
        if (tag !== exp_tag) begin
            errs = errs + 1;
            if (errs < 20) $display("FAIL vec %0d L=%0d term0=%0d: got %h exp %h", nvec, L, term0, tag, exp_tag);
        end
        k = (L == 0) ? 0 : ((L + 15) / 16 + term0);
        if (hs - hs0 !== k) begin errs = errs + 1; $display("FAIL vec %0d: %0d AD beats consumed, exp %0d", nvec, hs - hs0, k); end
        if (nvec < NCLEAN) begin
            // start-sampling edge -> DONE cycle
            exp_lat = 33 + 12 * ((L + 15) / 16) + ((L != 0 && L % 16 == 0) ? 11 : 0);
            if (lat != exp_lat) begin errs = errs + 1; $display("FAIL latency L=%0d: %0d, exp %0d", L, lat, exp_lat); end
            else nlat = nlat + 1;
            $display("%s L=%0d tag=%h cycles=%0d", (nvec < 33) ? "KAT " : "user", L, tag, lat);
            if (nvec < 33) nk = nk + 1;
        end
        nvec = nvec + 1;
    end
    $fclose(fd);

    // ------------------------------------------------ interface probes (info only)
    garbage = 0; max_stall = 0;
    // (a) 1-cycle start pulse in the DONE cycle (busy==0 there)
    L = 0; vkey = 0; vnonce = 0; term0 = 0;
    run_one(-1);                     // returns at the negedge of the DONE cycle
    start = 1; ad_empty = 1; @(negedge clk); start = 0;
    repeat (3) @(negedge clk);
    $display("CHECK start pulse during DONE: %s", busy ? "accepted" : "DROPPED");
    if (!busy) begin errs = errs + 1; $display("ERROR: start pulse during DONE dropped"); end
    else begin
        while (!done) @(negedge clk);
        if (tag !== 128'h6c89186ef2bd2c0e62101d3d28342429) begin
            errs = errs + 1; $display("ERROR: back-to-back run tag %h", tag);
        end
    end
    repeat (3) @(negedge clk);
    // (b) empty AD sent as a single 0-byte last beat with ad_empty=0
    @(negedge clk); key = 0; nonce = 0; ad_empty = 0; start = 1;
    @(negedge clk); start = 0;
    send_beat(128'h0, 5'd0, 1'b1);
    while (!done) @(negedge clk);
    $display("PROBE empty AD as 0-byte beat: tag=%h (spec AD-empty tag = 6c89186ef2bd2c0e62101d3d28342429)", tag);
    cov_report;
    $display("SUMMARY vectors=%0d (official KAT=%0d) latency_ok=%0d/%0d resets_mid_run=%0d errors=%0d",
             nvec, nk, nlat, NCLEAN, nrst, errs);
    $display("RESULT: %s", (errs == 0 && nvec > NCLEAN) ? "PASS" : "FAIL");
    $finish;
end

initial begin #200_000_000; $display("GLOBAL TIMEOUT"); $finish; end
endmodule
