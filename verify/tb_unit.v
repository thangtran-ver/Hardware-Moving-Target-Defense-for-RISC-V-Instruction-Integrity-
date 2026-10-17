`timescale 1ns/1ps
// Unit tests: S-box (exhaustive), linear layer, round (all constants),
// p8 / p12 (random states + latency + start-while-busy robustness).
module tb_unit;
reg clk = 0, rst_n = 0;
always #5 clk = ~clk;

integer fd, errs = 0, n, i;
reg [63:0] x0, x1, x2, x3, x4, e0, e1, e2, e3, e4;
reg [7:0]  c;

// ---------------- S-box ----------------
wire [63:0] sy0, sy1, sy2, sy3, sy4;
ascon_sbox u_sbox(.x0(x0),.x1(x1),.x2(x2),.x3(x3),.x4(x4),.y0(sy0),.y1(sy1),.y2(sy2),.y3(sy3),.y4(sy4));
// ---------------- linear layer ----------------
wire [63:0] ly0, ly1, ly2, ly3, ly4;
ascon_xor_diffusion u_lin(.x0(x0),.x1(x1),.x2(x2),.x3(x3),.x4(x4),.x0_new(ly0),.x1_new(ly1),.x2_new(ly2),.x3_new(ly3),.x4_new(ly4));
// ---------------- round ----------------
wire [63:0] ry0, ry1, ry2, ry3, ry4;
ascon_round u_rnd(.x0(x0),.x1(x1),.x2(x2),.x3(x3),.x4(x4),.constant(c),.y0(ry0),.y1(ry1),.y2(ry2),.y3(ry3),.y4(ry4));
// ---------------- p8 / p12 ----------------
reg p8s = 0, p12s = 0;
reg [63:0] px0, px1, px2, px3, px4;
wire [63:0] a0, a1, a2, a3, a4, b0, b1, b2, b3, b4;
wire p8b, p8d, p12b, p12d;
ascon_p8  u_p8 (.clk(clk),.rst_n(rst_n),.start(p8s), .x0(px0),.x1(px1),.x2(px2),.x3(px3),.x4(px4),.y0(a0),.y1(a1),.y2(a2),.y3(a3),.y4(a4),.busy(p8b),.done(p8d));
ascon_p12 u_p12(.clk(clk),.rst_n(rst_n),.start(p12s),.x0(px0),.x1(px1),.x2(px2),.x3(px3),.x4(px4),.y0(b0),.y1(b1),.y2(b2),.y3(b3),.y4(b4),.busy(p12b),.done(p12d));

integer lat, cnt, nb, lat8 = -1, lat12 = -1, done_w;

task chk5(input [8*8-1:0] nm, input [63:0] g0, g1, g2, g3, g4);
  if ({g0,g1,g2,g3,g4} !== {e0,e1,e2,e3,e4}) begin
    errs = errs + 1;
    if (errs < 10) $display("FAIL %0s vec %0d: got %h %h %h %h %h exp %h %h %h %h %h", nm, n, g0,g1,g2,g3,g4, e0,e1,e2,e3,e4);
  end
endtask

// run one permutation; optionally inject a bogus start while busy
task run_perm(input is12, input inject);
  begin
    {px0,px1,px2,px3,px4} = {x0,x1,x2,x3,x4};
    if (is12) p12s = 1; else p8s = 1;
    @(posedge clk); #1 p12s = 0; p8s = 0;
    // garbage on inputs while busy must not matter
    {px0,px1,px2,px3,px4} = {5{64'hDEADBEEFCAFEF00D}};
    lat = 1; cnt = 0;
    while (!(is12 ? p12d : p8d)) begin
      if (inject && cnt == 3) begin if (is12) p12s = 1; else p8s = 1; end
      else begin p12s = 0; p8s = 0; end
      @(posedge clk); #1 lat = lat + 1; cnt = cnt + 1;
      if (lat > 40) begin $display("TIMEOUT"); $finish; end
    end
    p12s = 0; p8s = 0;
    if (is12) begin chk5("p12", b0,b1,b2,b3,b4); if (lat12 < 0) lat12 = lat; else if (lat != lat12) begin errs=errs+1; $display("p12 latency changed %0d", lat); end end
    else      begin chk5("p8",  a0,a1,a2,a3,a4); if (lat8  < 0) lat8  = lat; else if (lat != lat8)  begin errs=errs+1; $display("p8 latency changed %0d", lat); end end
    // done must be a single-cycle pulse, busy low afterwards
    @(posedge clk); #1;
    if ((is12 ? p12d : p8d) !== 1'b0 || (is12 ? p12b : p8b) !== 1'b0) begin errs = errs + 1; $display("done/busy not a 1-cycle pulse"); end
  end
endtask

initial begin
  x0=0;x1=0;x2=0;x3=0;x4=0;c=0;
  #12 rst_n = 1;

  fd = $fopen("sbox_vec.txt","r"); n = 0;
  while ($fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",x0,x1,x2,x3,x4,e0,e1,e2,e3,e4) == 10) begin
    #1 chk5("sbox", sy0,sy1,sy2,sy3,sy4); n = n + 1; end
  $fclose(fd); $display("sbox  : %0d vectors (32 inputs x 64 bit positions)", n);

  fd = $fopen("lin_vec.txt","r"); n = 0;
  while ($fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",x0,x1,x2,x3,x4,e0,e1,e2,e3,e4) == 10) begin
    #1 chk5("lin", ly0,ly1,ly2,ly3,ly4); n = n + 1; end
  $fclose(fd); $display("linear: %0d vectors", n);

  fd = $fopen("round_vec.txt","r"); n = 0;
  while ($fscanf(fd,"%h %h %h %h %h %h %h %h %h %h %h\n",x0,x1,x2,x3,x4,c,e0,e1,e2,e3,e4) == 11) begin
    #1 chk5("round", ry0,ry1,ry2,ry3,ry4); n = n + 1; end
  $fclose(fd); $display("round : %0d vectors", n);

  @(posedge clk); #1;
  fd = $fopen("p8_vec.txt","r"); n = 0;
  while ($fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",x0,x1,x2,x3,x4,e0,e1,e2,e3,e4) == 10) begin
    run_perm(0, (n % 3) == 1); n = n + 1; end
  $fclose(fd); $display("p8    : %0d vectors, start->done latency = %0d clk", n, lat8);

  fd = $fopen("p12_vec.txt","r"); n = 0;
  while ($fscanf(fd,"%h %h %h %h %h %h %h %h %h %h\n",x0,x1,x2,x3,x4,e0,e1,e2,e3,e4) == 10) begin
    run_perm(1, (n % 3) == 1); n = n + 1; end
  $fclose(fd); $display("p12   : %0d vectors, start->done latency = %0d clk", n, lat12);

  $display("UNIT errors = %0d", errs);
  $finish;
end
endmodule
