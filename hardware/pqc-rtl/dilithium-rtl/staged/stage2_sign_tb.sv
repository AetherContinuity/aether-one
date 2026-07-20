// M5-DILITHIUM-001: VAIHEISTETTU functional-flow, Vaihe 2/3: Sign.
//
// sk_state.txt (Vaihe 1:sta) + msg + rnd -> RTL Sign + pack_sig ->
//   sig.txt (pakattu 3309-tavuinen allekirjoitus, hex)
//
// HUOM: s1_flat/s2_flat sk_state.txt:ssa ovat 8-bittisia etumerkillisia
// arvoja (ExpandS:n oma raaka ulostulomuoto) - muunnetaan tassa Zq-
// edustajamuotoon ENNEN Sign:n kayttoa (sama muunnos kuin
// full_chain_tb.sv:ssa).
//
// Ajetaan ITSENAISENA prosessina - EI riipu Vaihe 1:n omasta
// simulaatioprosessista, vain sen TIEDOSTOTULOSTEESTA.

`timescale 1ns/1ps

module stage2_sign_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int CW = 23;
  localparam int ZW = 24;
  localparam int OMEGA = 55;
  localparam int MSG_BYTES = 8;
  localparam int Q = 8380417;

  logic clk, reset, start, done;
  logic [255:0] rho_in, k_key_in, rnd_in;
  logic [511:0] tr_in;
  logic [L*256*8-1:0] s1_raw;
  logic [K*256*8-1:0] s2_raw;
  logic [L*256*CW-1:0] s1_zq;
  logic [K*256*CW-1:0] s2_zq;
  logic [K*256*CW-1:0] t0_in_flat;
  logic [8*MSG_BYTES-1:0] m_in;
  logic [L*256*ZW-1:0] z_out_flat;
  logic [K*256-1:0] h_out_flat;
  logic [383:0] c_tilde_out;
  logic [15:0] kappa_final_out;
  logic [7:0] iter_count_out;

  always #5 clk = ~clk;

  // s1/s2: 8-bittinen etumerkillinen -> Zq (kombinatorinen)
  genvar gsi;
  generate
    for (gsi = 0; gsi < L*256; gsi++) begin : g_s1_conv
      wire signed [7:0] raw = s1_raw[gsi*8 +: 8];
      assign s1_zq[gsi*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
    end
    for (gsi = 0; gsi < K*256; gsi++) begin : g_s2_conv
      wire signed [7:0] raw = s2_raw[gsi*8 +: 8];
      assign s2_zq[gsi*CW +: CW] = (raw < 0) ? (Q + raw) : raw;
    end
  endgenerate

  pqc_dilithium_sign_top2 #(.K(K), .L(L), .MSG_BYTES(MSG_BYTES)) sign_dut (
    .clk(clk), .reset(reset), .start(start),
    .rho_in(rho_in), .k_key_in(k_key_in), .tr_in(tr_in),
    .s1_in_flat(s1_zq), .s2_in_flat(s2_zq), .t0_in_flat(t0_in_flat),
    .m_in(m_in), .rnd_in(rnd_in),
    .done(done), .z_out_flat(z_out_flat), .h_out_flat(h_out_flat),
    .c_tilde_out(c_tilde_out), .kappa_final_out(kappa_final_out), .iter_count_out(iter_count_out)
  );

  // z on Zq-muodossa - keskitetaan ennen pakkausta (ks. korjaus
  // sign_nist_acvp_tb.sv:ssa / full_chain_tb.sv:ssa)
  logic [L*256*ZW-1:0] z_centered;
  genvar gzi;
  generate
    for (gzi = 0; gzi < L*256; gzi++) begin : g_z_center
      wire [ZW-1:0] z_raw = z_out_flat[gzi*ZW +: ZW];
      assign z_centered[gzi*ZW +: ZW] = (z_raw > (Q-1)/2) ? (z_raw - Q) : z_raw;
    end
  endgenerate

  logic packsig_start, packsig_done;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_out;
  pqc_dilithium_pack_sig #(.OMEGA(OMEGA), .K(K), .L(L)) packsig_dut (
    .clk(clk), .reset(reset), .start(packsig_start),
    .c_tilde_in(c_tilde_out), .z_in_flat(z_centered), .h_in_flat(h_out_flat),
    .done(packsig_done), .sig_out(sig_out)
  );

  int skfh, sigfh;

  initial begin
    clk = 0; reset = 1; start = 0; packsig_start = 0;

    skfh = $fopen("dilithium-rtl/staged/sk_state.txt", "r");
    void'($fscanf(skfh, "%h\n", rho_in));
    void'($fscanf(skfh, "%h\n", k_key_in));
    void'($fscanf(skfh, "%h\n", tr_in));
    void'($fscanf(skfh, "%h\n", s1_raw));
    void'($fscanf(skfh, "%h\n", s2_raw));
    void'($fscanf(skfh, "%h\n", t0_in_flat));
    $fclose(skfh);

    if (!$value$plusargs("msg=%h", m_in)) begin
      m_in = {8'h41,8'h42,8'h43,8'h44,8'h45,8'h46,8'h00,8'h00}; // 0x00||0x00||"ABCDEF" (m_prime, ctx tyhja)
    end
    if (!$value$plusargs("rnd=%h", rnd_in)) begin
      rnd_in = 256'h0; // deterministinen (rnd=0)
    end

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk); start <= 1'b1;
    @(posedge clk); start <= 1'b0;
    while (!done) @(posedge clk);
    $display("[%0t] Sign valmis, kappa=%0d, iteraatioita=%0d", $time, kappa_final_out, iter_count_out);

    @(posedge clk); packsig_start <= 1'b1;
    @(posedge clk); packsig_start <= 1'b0;
    while (!packsig_done) @(posedge clk);
    @(posedge clk);

    sigfh = $fopen("dilithium-rtl/staged/sig.txt", "w");
    $fdisplay(sigfh, "%h", sig_out);
    $fclose(sigfh);

    $display("PASS: Vaihe 2 (Sign) valmis - sig.txt kirjoitettu");
    $finish;
  end

endmodule
