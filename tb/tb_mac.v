`timescale 1ns/1ps
module tb_mac;
reg clk=0, rst_n=0; always #5 clk=~clk;
reg kn_we=0; reg [127:0] key_d, nonce_d;
wire [63:0] K0,K1,N0,N1;
ascon_key_nonce_reg ukn(.clk(clk),.rst_n(rst_n),.we(kn_we),.key_d(key_d),.nonce_d(nonce_d),.K0(K0),.K1(K1),.N0(N0),.N1(N1));
wire [319:0] STAGE, NEXT, D_INIT, D_POST, D_FINAL, P8_OUT, P12_OUT;
wire [63:0] S0=STAGE[319:256],S1=STAGE[255:192],S2=STAGE[191:128],S3=STAGE[127:64],S4=STAGE[63:0];
ascon_initial_state uinit(.K0(K0),.K1(K1),.N0(N0),.N1(N1),.D_INIT(D_INIT));
ascon_post_init upost(.S0(S0),.S1(S1),.S2(S2),.S3(S3),.S4(S4),.K0(K0),.K1(K1),.D_POST(D_POST));
ascon_final_pre ufin(.S0(S0),.S1(S1),.S2(S2),.S3(S3),.S4(S4),.K0(K0),.K1(K1),.D_FINAL(D_FINAL));
reg bwe=0; reg [127:0] bdata; reg [4:0] bn; reg blast; reg [1:0] pad_sel;
wire [127:0] blk; wire [4:0] nbq; wire lq;
ascon_ad_buffer_padding ubuf(.clk(clk),.rst_n(rst_n),.data_d(bdata),.nbytes_d(bn),.last_d(blast),.we(bwe),.pad_sel(pad_sel),.block_out(blk),.nbytes_q(nbq),.last_q(lq));
wire [63:0] a0,a1,a2,a3,a4;
ascon_ad_absorb uabs(.AD_BLOCK(blk),.S0(S0),.S1(S1),.S2(S2),.S3(S3),.S4(S4),.S0_new(a0),.S1_new(a1),.S2_new(a2),.S3_new(a3),.S4_new(a4));
reg p8s=0,p12s=0; wire p8b,p8d,p12b,p12d;
wire [63:0] q0,q1,q2,q3,q4,r0,r1,r2,r3,r4;
ascon_p8  up8 (.clk(clk),.rst_n(rst_n),.start(p8s), .x0(S0),.x1(S1),.x2(S2),.x3(S3),.x4(S4),.y0(q0),.y1(q1),.y2(q2),.y3(q3),.y4(q4),.busy(p8b),.done(p8d));
ascon_p12 up12(.clk(clk),.rst_n(rst_n),.start(p12s),.x0(S0),.x1(S1),.x2(S2),.x3(S3),.x4(S4),.y0(r0),.y1(r1),.y2(r2),.y3(r3),.y4(r4),.busy(p12b),.done(p12d));
reg [2:0] sel; reg swe=0;
ascon_state_mux umux(.sel(sel),.D_INIT(D_INIT),.D_POST(D_POST),.D_AD({a0,a1,a2,a3,a4}),.D_FINAL(D_FINAL),.P8_OUT({q0,q1,q2,q3,q4}),.P12_OUT({r0,r1,r2,r3,r4}),.NEXT_STAGE(NEXT));
ascon_state_reg ureg(.clk(clk),.rst_n(rst_n),.we(swe),.NEXT_STAGE(NEXT),.STAGE(STAGE));
integer cyc=0; always @(posedge clk) cyc<=cyc+1;
task load(input [2:0] s); begin sel=s; swe=1; @(posedge clk); #1 swe=0; end endtask
task run12; begin p12s=1; @(posedge clk); #1 p12s=0; while(!p12d) begin @(posedge clk); #1; end load(3'b101); end endtask
task run8;  begin p8s=1;  @(posedge clk); #1 p8s=0;  while(!p8d)  begin @(posedge clk); #1; end load(3'b100); end endtask
reg [383:0] ad; reg [7:0] L; reg [127:0] exp_tag, tag; integer fd, n, rem, off, errs=0, c0;
initial begin
  key_d=128'h000102030405060708090a0b0c0d0e0f; nonce_d=128'h101112131415161718191a1b1c1d1e1f;
  #12 rst_n=1; @(posedge clk); #1 kn_we=1; @(posedge clk); #1 kn_we=0;
  fd=$fopen("vec.txt","r");
  while($fscanf(fd,"%h %h %h\n",L,ad,exp_tag)==3) begin
    c0=cyc;
    load(3'b000); run12; load(3'b001);
    rem=L; off=0;
    if (L!=0) begin
      while (rem>=16) begin // full blocks
        bdata=ad[383-off*8 -: 128]; bn=16; blast=0; bwe=1; @(posedge clk); #1 bwe=0;
        pad_sel=2'b00; load(3'b010); run8; rem=rem-16; off=off+16;
      end
      if (rem>0) begin bdata=ad[383-off*8 -: 128]; bn=rem; blast=1; bwe=1; @(posedge clk); #1 bwe=0; pad_sel=2'b01; end
      else pad_sel=2'b10;
      load(3'b010); run8;
    end
    load(3'b011); run12;
    tag={S3^K0,S4^K1};
    if (tag!==exp_tag) begin errs=errs+1; $display("FAIL L=%0d got %h exp %h",L,tag,exp_tag); end
    else $display("PASS L=%0d tag=%h  (%0d cycles)",L,tag,cyc-c0);
  end
  $display("errors=%0d",errs); $finish;
end
endmodule
