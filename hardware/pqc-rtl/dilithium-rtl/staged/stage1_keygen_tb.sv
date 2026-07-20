// M5-DILITHIUM-001: VAIHEISTETTU functional-flow, Vaihe 1/3: KeyGen.
//
// zeta (kiintea testisiemen tai $value$plusargs) -> RTL KeyGen ->
//   ek.txt      (pakattu julkinen avain, hex)
//   sk_state.txt (rho, K_key, tr, s1/s2/t0 Zq-muodossa - Sign:n oma
//                 tarvitsema esitys, EI pakattu dk-formaatti, jotta
//                 valtetaan tarpeeton pack/unpack-kierros tassa
//                 vaiheiden valilla)
//
// Ajetaan ITSENAISENA prosessina - muisti vapautuu kun tama paattyy,
// ennen kuin Sign (Vaihe 2) edes alkaa.

`timescale 1ns/1ps

module stage1_keygen_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int CW = 23;

  logic clk, reset, start, done;
  logic [255:0] zeta_in;
  logic [8*(32+K*320)-1:0] ek_out;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out;

  always #5 clk = ~clk;

  pqc_dilithium_keygen_top #(.K(K), .L(L)) dut (
    .clk(clk), .reset(reset), .start(start),
    .zeta_in(zeta_in), .done(done), .ek_out(ek_out), .dk_out(dk_out)
  );

  // === tr = SHAKE256(ek,64), tarvitaan Sign:lle ===
  logic tr_start, tr_done;
  logic [8*136*15-1:0] tr_msg_in;
  logic [511:0] tr_out;
  pqc_shake256 #(.MAX_BLOCKS(15), .MAX_OUT_BYTES(64)) tr_dut (
    .clk(clk), .reset(reset), .start(tr_start),
    .msg_in(tr_msg_in), .msg_len_bytes(16'd1952), .out_len_bytes(16'd64),
    .out_data(tr_out), .done(tr_done)
  );

  int ekfh, skfh;
  string zeta_hex;

  initial begin
    clk = 0; reset = 1; start = 0; tr_start = 0;

    // Siemen: komentoriviltä ($value$plusargs) tai oletusarvo
    if (!$value$plusargs("zeta=%h", zeta_in)) begin
      zeta_in = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
    end

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk); start <= 1'b1;
    @(posedge clk); start <= 1'b0;
    while (!done) @(posedge clk);
    $display("[%0t] KeyGen valmis", $time);

    tr_msg_in = '0;
    tr_msg_in[8*(32+K*320)-1:0] = ek_out;
    @(posedge clk); tr_start <= 1'b1;
    @(posedge clk); tr_start <= 1'b0;
    while (!tr_done) @(posedge clk);
    $display("[%0t] tr laskettu", $time);

    ekfh = $fopen("dilithium-rtl/staged/ek.txt", "w");
    $fdisplay(ekfh, "%h", ek_out);
    $fclose(ekfh);

    skfh = $fopen("dilithium-rtl/staged/sk_state.txt", "w");
    $fdisplay(skfh, "%h", dut.rho);
    $fdisplay(skfh, "%h", dut.K_key);
    $fdisplay(skfh, "%h", tr_out);
    $fdisplay(skfh, "%h", dut.s1_flat);
    $fdisplay(skfh, "%h", dut.s2_flat);
    $fdisplay(skfh, "%h", dut.t0_flat);
    $fclose(skfh);

    $display("PASS: Vaihe 1 (KeyGen) valmis - ek.txt ja sk_state.txt kirjoitettu");
    $finish;
  end

endmodule
