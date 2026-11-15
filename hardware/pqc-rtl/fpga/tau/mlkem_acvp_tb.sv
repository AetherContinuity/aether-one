// mlkem_acvp_tb.sv
//
// Synteesikelpoiset ML-KEM-ytimet (pqc_mlkem_keygen_core,
// pqc_mlkem_encaps_top, pqc_mlkem_decaps_top) vs. NIST ACVP, mika
// tahansa K. Parametrit asetetaan kaannoksessa:
//   iverilog ... -P mlkem_acvp_tb.K=3 -P mlkem_acvp_tb.OP=1
// OP: 0 = KeyGen, 1 = Encaps, 2 = Decaps.
// Vektoritiedosto: +VEC=<polku>, muoto m2-golden/gen_mlkem_acvp_vectors.py.
//
// Jokainen tapaus ajetaan resetin jalkeen. Tulostaa yhden rivin per
// tapaus ja lopuksi "PASS: ..." vain, jos kaikki tasmaavat.

`timescale 1ns/1ps

module mlkem_acvp_tb;

  parameter int K  = 2;
  parameter int OP = 0;

  localparam int DU = (K == 4) ? 11 : 10;
  localparam int DV = (K == 4) ? 5 : 4;
  localparam int EK_BYTES = 384*K + 32;
  localparam int DK_BYTES = 768*K + 96;
  localparam int C_BYTES  = 32*(DU*K + DV);
  localparam int MAX_CYCLES = 400000;

  logic clk = 0, reset = 1;
  always #5 clk = ~clk;

  logic kg_start, kg_done;
  logic [255:0] kg_d, kg_z;
  logic [8*EK_BYTES-1:0] kg_ek;
  logic [8*DK_BYTES-1:0] kg_dk;
  logic [255:0] dbg_rho, dbg_sigma;
  logic [256*16-1:0] dbg_A00;
  logic [4:0] dbg_state;

  logic en_start, en_done;
  logic [8*EK_BYTES-1:0] en_ek;
  logic [255:0] en_m, en_K;
  logic [8*C_BYTES-1:0] en_c;

  logic de_start, de_done, de_match;
  logic [8*C_BYTES-1:0] de_c;
  logic [8*DK_BYTES-1:0] de_dk;
  logic [255:0] de_K;

  if (OP == 0) begin : g_kg
    pqc_mlkem_keygen_core #(.K(K)) dut (
      .clk(clk), .reset(reset), .start(kg_start), .d_seed(kg_d), .z_seed(kg_z),
      .done(kg_done), .ek_out(kg_ek), .dk_out(kg_dk),
      .debug_rho(dbg_rho), .debug_sigma(dbg_sigma), .debug_A00(dbg_A00), .debug_state(dbg_state));
  end else if (OP == 1) begin : g_en
    pqc_mlkem_encaps_top #(.K(K)) dut (
      .clk(clk), .reset(reset), .start(en_start), .ek_in(en_ek), .m_in(en_m),
      .done(en_done), .K_out(en_K), .c_out(en_c));
  end else begin : g_de
    pqc_mlkem_decaps_top #(.K(K)) dut (
      .clk(clk), .reset(reset), .start(de_start), .c_in(de_c), .dk_in(de_dk),
      .done(de_done), .K_final_out(de_K), .match_out(de_match));
  end

  string vec_path, opname;
  int fh, n, tc, rej, fails, cyc;
  logic [8*EK_BYTES-1:0] x_ek;
  logic [8*DK_BYTES-1:0] x_dk;
  logic [8*C_BYTES-1:0]  x_c;
  logic [255:0] x_d, x_z, x_m, x_K;
  logic ok, fin;

  initial begin
    kg_start = 0; en_start = 0; de_start = 0;
    opname = (OP == 0) ? "KeyGen" : (OP == 1) ? "Encaps" : "Decaps";
    if (!$value$plusargs("VEC=%s", vec_path)) begin
      $display("FAIL: +VEC=<polku> puuttuu"); $fatal(1);
    end
    fh = $fopen(vec_path, "r");
    if (fh == 0) begin $display("FAIL: %0s ei auennut", vec_path); $fatal(1); end
    if ($fscanf(fh, "%d\n", n) != 1 || n < 1) begin
      $display("FAIL: tapausmaara puuttuu"); $fatal(1);
    end
    fails = 0;

    for (int i = 0; i < n; i++) begin
      rej = 0;
      if (OP == 2) void'($fscanf(fh, "%d %d\n", tc, rej));
      else         void'($fscanf(fh, "%d\n", tc));
      if (OP == 0) begin
        void'($fscanf(fh, "%h\n", x_d)); void'($fscanf(fh, "%h\n", x_z));
        void'($fscanf(fh, "%h\n", x_ek)); void'($fscanf(fh, "%h\n", x_dk));
        kg_d = x_d; kg_z = x_z;
      end else if (OP == 1) begin
        void'($fscanf(fh, "%h\n", x_ek)); void'($fscanf(fh, "%h\n", x_m));
        void'($fscanf(fh, "%h\n", x_K)); void'($fscanf(fh, "%h\n", x_c));
        en_ek = x_ek; en_m = x_m;
      end else begin
        void'($fscanf(fh, "%h\n", x_dk)); void'($fscanf(fh, "%h\n", x_c));
        void'($fscanf(fh, "%h\n", x_K));
        de_dk = x_dk; de_c = x_c;
      end

      reset = 1;
      repeat (3) @(posedge clk);
      reset = 0;
      @(posedge clk);
      kg_start <= (OP == 0); en_start <= (OP == 1); de_start <= (OP == 2);
      @(posedge clk);
      kg_start <= 0; en_start <= 0; de_start <= 0;

      cyc = 0; fin = 0;
      while (!fin && cyc < MAX_CYCLES) begin
        @(posedge clk); cyc++;
        fin = (OP == 0) ? kg_done : (OP == 1) ? en_done : de_done;
      end

      if (!fin) ok = 0;
      else if (OP == 0) ok = (kg_ek === x_ek) && (kg_dk === x_dk);
      else if (OP == 1) ok = (en_K === x_K) && (en_c === x_c);
      else ok = (de_K === x_K) && (de_match === (rej == 0));

      $display("%0s K=%0d tcId=%0d %0s%0s syklit=%0d", opname, K, tc,
               ok ? "ok" : "EI TASMAA",
               (OP == 2) ? (rej ? " (hylkays)" : " (valid)") : "", cyc);
      if (!ok) fails++;
    end
    $fclose(fh);

    if (fails == 0)
      $display("PASS: %0s K=%0d, %0d/%0d NIST ACVP -tapausta", opname, K, n, n);
    else
      $display("FAIL: %0s K=%0d, %0d/%0d tapausta ei tasmaa", opname, K, fails, n);
    $finish;
  end

endmodule
