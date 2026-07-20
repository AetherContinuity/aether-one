// M5-DILITHIUM-001: KOKO RTL-KETJUN paasta-paahan-testi.
// RTL KeyGen -> RTL Sign -> RTL Verify, EI PYTHONIA VALISSA (paitsi
// alkusiemenen syottamiseen ja lopputuloksen riippumattomaan
// tarkistukseen).
//
// zeta -> [RTL KeyGen] -> ek, rho/K/s1/s2/t0 (sisaiset, hierarkkinen pääsy)
//   -> tr = SHAKE256(ek,64) [erillinen instanssi tassa testipenkissa]
//   -> [RTL Sign] -> z, h, c_tilde
//   -> [pack_sig] -> sig (3309 tavua)
//   -> [RTL Verify] (pk=ek, sig, sama m_prime) -> verify_ok (odotettu: 1)

`timescale 1ns/1ps

module full_chain_tb;

  localparam int K = 6;
  localparam int L = 5;
  localparam int CW = 23;
  localparam int ZW = 24;
  localparam int OMEGA = 55;
  localparam int MSG_BYTES = 10;  // 2-tavuinen etuliite (0x00,0x00) + 8-tavuinen raaka viesti

  logic clk, reset;
  always #5 clk = ~clk;

  // === RTL KeyGen ===
  logic kg_start, kg_done;
  logic [255:0] zeta_in;
  logic [8*(32+K*320)-1:0] ek_out;
  logic [8*(32+32+64+L*128+K*128+K*416)-1:0] dk_out;
  pqc_dilithium_keygen_top #(.K(K), .L(L)) kg_dut (
    .clk(clk), .reset(reset), .start(kg_start),
    .zeta_in(zeta_in), .done(kg_done), .ek_out(ek_out), .dk_out(dk_out)
  );

  // === tr = SHAKE256(ek,64) ===
  logic tr_start, tr_done;
  logic [8*136*15-1:0] tr_msg_in;
  logic [511:0] tr_out;
  pqc_shake256 #(.MAX_BLOCKS(15), .MAX_OUT_BYTES(64)) tr_dut (
    .clk(clk), .reset(reset), .start(tr_start),
    .msg_in(tr_msg_in), .msg_len_bytes(16'd1952), .out_len_bytes(16'd64),
    .out_data(tr_out), .done(tr_done)
  );

  // === s1/s2: 8-bittinen etumerkillinen -> Zq (kombinatorinen, rekisteroity) ===
  logic [L*256*8-1:0] s1_raw_reg;
  logic [K*256*8-1:0] s2_raw_reg;
  logic [L*256*CW-1:0] s1_zq;
  logic [K*256*CW-1:0] s2_zq;
  genvar gsi;
  generate
    for (gsi = 0; gsi < L*256; gsi++) begin : g_s1_conv
      wire signed [7:0] raw = s1_raw_reg[gsi*8 +: 8];
      assign s1_zq[gsi*CW +: CW] = (raw < 0) ? (8380417 + raw) : raw;
    end
    for (gsi = 0; gsi < K*256; gsi++) begin : g_s2_conv
      wire signed [7:0] raw = s2_raw_reg[gsi*8 +: 8];
      assign s2_zq[gsi*CW +: CW] = (raw < 0) ? (8380417 + raw) : raw;
    end
  endgenerate

  logic [255:0] rho_reg, k_key_reg;
  logic [K*256*CW-1:0] t0_reg;

  // === RTL Sign ===
  logic sign_start, sign_done;
  logic [8*MSG_BYTES-1:0] m_in;
  logic [255:0] rnd_in;
  logic [L*256*ZW-1:0] z_out_flat;
  logic [K*256-1:0] h_out_flat;
  logic [383:0] c_tilde_out;
  logic [15:0] kappa_final_out;
  logic [7:0] iter_count_out;
  pqc_dilithium_sign_top2 #(.K(K), .L(L), .MSG_BYTES(MSG_BYTES)) sign_dut (
    .clk(clk), .reset(reset), .start(sign_start),
    .rho_in(rho_reg), .k_key_in(k_key_reg), .tr_in(tr_out),
    .s1_in_flat(s1_zq), .s2_in_flat(s2_zq), .t0_in_flat(t0_reg),
    .m_in(m_in), .rnd_in(rnd_in),
    .done(sign_done), .z_out_flat(z_out_flat), .h_out_flat(h_out_flat),
    .c_tilde_out(c_tilde_out), .kappa_final_out(kappa_final_out), .iter_count_out(iter_count_out)
  );

  // sign_top2.sv:n oma z_out_flat on Zq-edustajamuodossa - pack_z
  // OLETTAA jo keskitetyn etumerkillisen arvon. PAKOLLINEN muunnos
  // (ks. sama korjaus sign_nist_acvp_tb.sv:ssa, loydetty NIST ACVP
  // sigGen-testivektorilla).
  logic [L*256*ZW-1:0] z_centered;
  localparam int SIGN_Q = 8380417;
  genvar gzci;
  generate
    for (gzci = 0; gzci < L*256; gzci++) begin : g_z_center
      wire [ZW-1:0] z_raw = z_out_flat[gzci*ZW +: ZW];
      assign z_centered[gzci*ZW +: ZW] = (z_raw > (SIGN_Q-1)/2) ? (z_raw - SIGN_Q) : z_raw;
    end
  endgenerate

  // === pack_sig ===
  logic packsig_start, packsig_done;
  logic [8*(48+L*640+OMEGA+K)-1:0] sig_out;
  pqc_dilithium_pack_sig #(.OMEGA(OMEGA), .K(K), .L(L)) packsig_dut (
    .clk(clk), .reset(reset), .start(packsig_start),
    .c_tilde_in(c_tilde_out), .z_in_flat(z_centered), .h_in_flat(h_out_flat),
    .done(packsig_done), .sig_out(sig_out)
  );

  // === RTL Verify ===
  logic verify_start, verify_done, verify_ok;
  pqc_dilithium_verify_top2 #(.K(K), .L(L), .OMEGA(OMEGA), .MSG_BYTES(MSG_BYTES)) verify_dut (
    .clk(clk), .reset(reset), .start(verify_start),
    .pk_in(ek_out), .sig_in(sig_out), .m_in(m_in),
    .done(verify_done), .verify_ok(verify_ok)
  );

  initial begin
    clk = 0; reset = 1;
    kg_start = 0; sign_start = 0; packsig_start = 0; verify_start = 0;
    zeta_in = 256'h0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20;
    rnd_in = 256'h0;
    // m_in = 0x00 || 0x00 || 8-tavuinen viesti (m_prime-formaatti, ctx=tyhja)
    m_in = {8'h41,8'h42,8'h43,8'h44,8'h45,8'h46,8'h47,8'h48, 8'h00,8'h00};

    repeat (3) @(posedge clk);
    reset = 0;

    // --- 1. KeyGen ---
    @(posedge clk); kg_start <= 1'b1;
    @(posedge clk); kg_start <= 1'b0;
    wait (kg_done);
    $display("[%0t] KeyGen valmis", $time);
    rho_reg = kg_dut.rho;
    k_key_reg = kg_dut.K_key;
    s1_raw_reg = kg_dut.s1_flat;
    s2_raw_reg = kg_dut.s2_flat;
    t0_reg = kg_dut.t0_flat;

    // --- 2. tr = H(ek,64) ---
    tr_msg_in = '0;
    tr_msg_in[8*(32+K*320)-1:0] = ek_out;
    @(posedge clk); tr_start <= 1'b1;
    @(posedge clk); tr_start <= 1'b0;
    wait (tr_done);
    $display("[%0t] tr laskettu", $time);

    // --- 3. Sign ---
    @(posedge clk); sign_start <= 1'b1;
    @(posedge clk); sign_start <= 1'b0;
    wait (sign_done);
    $display("[%0t] Sign valmis, kappa=%0d, iteraatioita=%0d", $time, kappa_final_out, iter_count_out);

    // --- 4. pack_sig ---
    @(posedge clk); packsig_start <= 1'b1;
    @(posedge clk); packsig_start <= 1'b0;
    wait (packsig_done);
    $display("[%0t] pack_sig valmis", $time);

    // --- 5. Verify ---
    @(posedge clk); verify_start <= 1'b1;
    @(posedge clk); verify_start <= 1'b0;
    wait (verify_done);
    $display("[%0t] Verify valmis, verify_ok=%0b (odotettu 1)", $time, verify_ok);

    $display("--------------------------------------------------");
    if (verify_ok) begin
      $display("PASS: KOKO RTL-KETJU (KeyGen->Sign->Verify) TOIMII PAASTA PAAHAN, EI PYTHONIA VALISSA");
    end else begin
      $display("FAIL: RTL-ketju epaonnistui - Verify hylkasi RTL:n oman Sign:n tuottaman allekirjoituksen");
      $fatal(1);
    end
    $display("--------------------------------------------------");

    $finish;
  end

endmodule
