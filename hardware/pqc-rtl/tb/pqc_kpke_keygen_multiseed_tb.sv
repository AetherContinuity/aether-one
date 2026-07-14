// pqc_mlkem_keygen_tb.sv
//
// M3 Issue #15 (viimeinen osa): ML-KEM.KeyGen_internal (FIPS 203
// Algoritmi 16). Kutsuu jo validoitua K-PKE.KeyGen-logiikkaa (samat
// moduulit kuin pqc_kpke_roundtrip_tb.sv:n oma KeyGen-vaihe), lisaa
// H(ek)=SHA3-256(ek) ja kokoaa dk = dkPKE||ek||H(ek)||z. EI uutta
// kryptografista logiikkaa - puhdasta orkestrointia.

`timescale 1ns/1ps

module pqc_kpke_keygen_multiseed_tb;

  localparam int COEFF_W = 16;
  localparam int SPAD_AW = 9;
  localparam int K = 2;
  localparam int ETA1 = 3;

  logic clk, reset;
  always #5 clk = ~clk;

  // --- NTT-ajuri ---
  logic ntt_start, stage_done, bank_conflict_detected;
  logic [7:0] count, pair_dist;
  logic mode;
  logic [SPAD_AW-1:0] base_addr_lane0, base_addr_lane1;
  logic [COEFF_W-1:0] zeta_lane0, zeta_lane1;

  pqc_ntt_stage_banked #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) ntt_dut (
    .clk(clk), .reset(reset), .start(ntt_start), .count(count),
    .pair_dist(pair_dist), .mode(mode),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected)
  );

  logic [1:0] bank_rom_tb  [0:255];
  logic [5:0] local_rom_tb [0:255];

  function automatic void write_bank(input [1:0] b, input [5:0] l, input [COEFF_W-1:0] val);
    case (b)
      2'd0: ntt_dut.bank0[l] = val;
      2'd1: ntt_dut.bank1[l] = val;
      2'd2: ntt_dut.bank2[l] = val;
      default: ntt_dut.bank3[l] = val;
    endcase
  endfunction

  function automatic [COEFF_W-1:0] read_bank_tb(input [1:0] b, input [5:0] l);
    case (b)
      2'd0: read_bank_tb = ntt_dut.bank0[l];
      2'd1: read_bank_tb = ntt_dut.bank1[l];
      2'd2: read_bank_tb = ntt_dut.bank2[l];
      default: read_bank_tb = ntt_dut.bank3[l];
    endcase
  endfunction

  task automatic run_one_level(input int length, input int base0, input int zeta0_int,
                                 input int base1, input int zeta1_int, input int count_val);
    int c;
    begin
      pair_dist       <= 8'(length);
      base_addr_lane0 <= 9'(base0);
      base_addr_lane1 <= 9'(base1);
      zeta_lane0      <= zeta0_int[15:0];
      zeta_lane1      <= zeta1_int[15:0];
      count           <= 8'(count_val);
      @(posedge clk);
      ntt_start <= 1'b1;
      @(posedge clk);
      ntt_start <= 1'b0;
      c = 0;
      while (!stage_done && c < 3000) begin @(posedge clk); c++; end
    end
  endtask

  task automatic run_forward_ntt(input logic [256*COEFF_W-1:0] poly_in,
                                   output logic [256*COEFF_W-1:0] poly_out);
    int fh2, length, base0, zeta0, base1, zeta1, scan_ok2;
    begin
      for (int i = 0; i < 256; i++) write_bank(bank_rom_tb[i], local_rom_tb[i], poly_in[i*COEFF_W +: COEFF_W]);
      mode <= 1'b0;
      fh2 = $fopen("vectors/full_level6_zeta.txt", "r");
      scan_ok2 = $fscanf(fh2, "%d\n", zeta0);
      $fclose(fh2);
      run_one_level(128, 0, zeta0, 64, zeta0, 64);
      fh2 = $fopen("vectors/full_schedule.txt", "r");
      scan_ok2 = 5;
      while (!$feof(fh2) && scan_ok2 == 5) begin
        scan_ok2 = $fscanf(fh2, "%d %d %d %d %d\n", length, base0, zeta0, base1, zeta1);
        if (scan_ok2 == 5) run_one_level(length, base0, zeta0, base1, zeta1, length);
      end
      $fclose(fh2);
      for (int i = 0; i < 256; i++) poly_out[i*COEFF_W +: COEFF_W] = read_bank_tb(bank_rom_tb[i], local_rom_tb[i]);
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
  endtask

  // --- SHA3-512 (G) ja SHA3-256 (H) ---
  logic sha512_start, sha512_done;
  logic [8*72-1:0] sha512_msg_in;
  logic [511:0] sha512_out;
  pqc_sha3_512 #(.MAX_BLOCKS(1)) sha512_dut (
    .clk(clk), .reset(reset), .start(sha512_start),
    .msg_in(sha512_msg_in), .msg_len_bytes(16'd33),
    .digest_out(sha512_out), .done(sha512_done)
  );

  logic sha256_start, sha256_done;
  logic [8*136*6-1:0] sha256_msg_in;
  logic [255:0] sha256_out;
  pqc_sha3_256 #(.MAX_BLOCKS(6)) sha256_dut (
    .clk(clk), .reset(reset), .start(sha256_start),
    .msg_in(sha256_msg_in), .msg_len_bytes(16'd800),
    .digest_out(sha256_out), .done(sha256_done)
  );

  // --- SampleNTT (A) ---
  logic samplentt_start, samplentt_done, samplentt_err;
  logic [255:0] samplentt_rho;
  logic [7:0] samplentt_j, samplentt_i;
  logic [16*256-1:0] samplentt_out;
  logic [15:0] sn_acc, sn_rej, sn_xof;
  pqc_samplentt #(.XOF_BYTES(1008)) samplentt_dut (
    .clk(clk), .reset(reset), .start(samplentt_start),
    .rho(samplentt_rho), .byte_j(samplentt_j), .byte_i(samplentt_i),
    .a_hat(samplentt_out), .accepted_count(sn_acc), .rejected_count(sn_rej),
    .xof_bytes_consumed(sn_xof), .done(samplentt_done), .error_exhausted(samplentt_err)
  );

  // --- PRF+SamplePolyCBD (eta1) ---
  logic cbd1_start, cbd1_done;
  logic [255:0] cbd1_seed;
  logic [7:0] cbd1_n;
  logic [16*256-1:0] cbd1_out;
  pqc_prf_samplepolycbd #(.ETA(ETA1)) cbd1_dut (
    .clk(clk), .reset(reset), .start(cbd1_start),
    .seed_s(cbd1_seed), .counter_n(cbd1_n), .f_out(cbd1_out), .done(cbd1_done)
  );

  logic [256*COEFF_W-1:0] mntt_f, mntt_g, mntt_h;
  pqc_multiplyntts #(.COEFF_W(COEFF_W)) mntt_dut (.f_hat(mntt_f), .g_hat(mntt_g), .h_hat(mntt_h));
  logic [256*COEFF_W-1:0] padd_a, padd_b, padd_sum;
  pqc_polyadd #(.COEFF_W(COEFF_W)) padd_dut (.a_in(padd_a), .b_in(padd_b), .sum_out(padd_sum));

  logic [256*12-1:0] benc12_in [0:1];
  logic [256*12-1:0] benc12_out [0:1];
  pqc_byteencode_dparam #(.D(12)) benc12_0 (.f_in(benc12_in[0]), .b_out(benc12_out[0]));
  pqc_byteencode_dparam #(.D(12)) benc12_1 (.f_in(benc12_in[1]), .b_out(benc12_out[1]));

  // --- Testivektorit (mlkem_frozen_vectors.json:sta) ---
  logic [255:0] d_seed, z_seed;
  logic [8*800-1:0] ek_expect;
  logic [8*1632-1:0] dk_expect;

  int fh, scan_ok, error_count;
  int n_trials;

  initial begin
    error_count = 0;
    clk = 0; reset = 1;
    ntt_start = 0; count = 0; pair_dist = 0; mode = 0;
    base_addr_lane0 = 0; base_addr_lane1 = 0; zeta_lane0 = 0; zeta_lane1 = 0;
    sha512_start = 0; sha256_start = 0; samplentt_start = 0; cbd1_start = 0;

    $readmemh("m2-golden/bank_rom_4banks.memh", bank_rom_tb);
    $readmemh("m2-golden/bank_local_4banks.memh", local_rom_tb);

    fh = $fopen("vectors/kpke_keygen_multiseed_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%d\n", n_trials);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (int trial = 0; trial < n_trials; trial++) begin
    scan_ok = $fscanf(fh, "%h\n", d_seed);
    scan_ok = $fscanf(fh, "%h\n", z_seed);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    scan_ok = $fscanf(fh, "%h\n", dk_expect);

    // --- K-PKE.KeyGen(d) -> ekPKE, dkPKE, ajettuna SAMASSA
    // simulaatiossa monta kertaa peraikkain (kayttajan oma ehdotus:
    // paljasta rekisterien jaanteet/reset-ongelmat/tilavuodot) ---
    begin
      logic [255:0] rho, sigma;
      logic [256*COEFF_W-1:0] A [0:K-1][0:K-1];
      logic [256*COEFF_W-1:0] s_vec [0:K-1], e_vec [0:K-1];
      logic [256*COEFF_W-1:0] s_hat [0:K-1], e_hat [0:K-1], t_hat [0:K-1];
      logic [8*800-1:0] ek_got;
      logic [8*1632-1:0] dk_got;
      logic [255:0] H_ek;

      sha512_msg_in = '0;
      sha512_msg_in[255:0] = d_seed;
      sha512_msg_in[263:256] = K[7:0];
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      sha512_start <= 1'b1; @(posedge clk); sha512_start <= 1'b0;
      while (!sha512_done) @(posedge clk);
      #1;
      rho = sha512_out[255:0];
      sigma = sha512_out[511:256];

      for (int i = 0; i < K; i++) begin
        for (int j = 0; j < K; j++) begin
          samplentt_rho = rho; samplentt_j = j[7:0]; samplentt_i = i[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          samplentt_start <= 1'b1; @(posedge clk); samplentt_start <= 1'b0;
          while (!samplentt_done) @(posedge clk);
          #1;
          A[i][j] = samplentt_out;
        end
      end

      begin
        int N;
        N = 0;
        for (int i = 0; i < K; i++) begin
          cbd1_seed = sigma; cbd1_n = N[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
          while (!cbd1_done) @(posedge clk);
          #1;
          s_vec[i] = cbd1_out;
          N++;
        end
        for (int i = 0; i < K; i++) begin
          cbd1_seed = sigma; cbd1_n = N[7:0];
          reset = 1; @(posedge clk); reset = 0; @(posedge clk);
          cbd1_start <= 1'b1; @(posedge clk); cbd1_start <= 1'b0;
          while (!cbd1_done) @(posedge clk);
          #1;
          e_vec[i] = cbd1_out;
          N++;
        end
      end

      for (int i = 0; i < K; i++) run_forward_ntt(s_vec[i], s_hat[i]);
      for (int i = 0; i < K; i++) run_forward_ntt(e_vec[i], e_hat[i]);

      for (int i = 0; i < K; i++) begin
        logic [256*COEFF_W-1:0] acc;
        acc = '0;
        for (int j = 0; j < K; j++) begin
          mntt_f = A[i][j]; mntt_g = s_hat[j];
          #1;
          padd_a = acc; padd_b = mntt_h;
          #1;
          acc = padd_sum;
        end
        padd_a = acc; padd_b = e_hat[i];
        #1;
        t_hat[i] = padd_sum;
      end

      ek_got = '0;
      for (int i = 0; i < K; i++) begin
        for (int c = 0; c < 256; c++) benc12_in[i][c*12 +: 12] = t_hat[i][c*COEFF_W +: COEFF_W];
        #1;
        ek_got[(i*384)*8 +: 384*8] = benc12_out[i];
      end
      ek_got[(2*384)*8 +: 32*8] = rho;

      dk_got = '0;
      dk_got[0 +: 384*K*8] = 0;  // dkPKE tayttyy alla
      for (int i = 0; i < K; i++) begin
        for (int c = 0; c < 256; c++) benc12_in[i][c*12 +: 12] = s_hat[i][c*COEFF_W +: COEFF_W];
        #1;
        dk_got[(i*384)*8 +: 384*8] = benc12_out[i];
      end

      // --- ML-KEM.KeyGen_internal: ek=ekPKE, dk=dkPKE||ek||H(ek)||z ---
      if (ek_got !== ek_expect) begin
        $display("FAIL ek: poikkeaa golden-mallista"); error_count++;
      end else $display("OK ek (=ekPKE): tasmaa golden-malliin");

      sha256_msg_in = '0;
      sha256_msg_in[8*800-1:0] = ek_got;
      reset = 1; @(posedge clk); reset = 0; @(posedge clk);
      sha256_start <= 1'b1; @(posedge clk); sha256_start <= 1'b0;
      while (!sha256_done) @(posedge clk);
      #1;
      H_ek = sha256_out;

      dk_got[(384*K)*8 +: 800*8] = ek_got;
      dk_got[(384*K+800)*8 +: 32*8] = H_ek;
      dk_got[(384*K+832)*8 +: 32*8] = z_seed;

      if (dk_got !== dk_expect) begin
        $display("FAIL trial %0d: dk poikkeaa golden-mallista", trial); error_count++;
      end else $display("OK trial %0d: ek+dk tasmaavat golden-malliin", trial);
    end

    reset = 1; @(posedge clk); reset = 0; @(posedge clk);
    end
    $fclose(fh);

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: K-PKE.KeyGen ajettu %0d kertaa PERAKKAIN samassa simulaatiossa, kaikki tasmaavat - EI tilavuotoja/rekisterijaanteita", n_trials);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
