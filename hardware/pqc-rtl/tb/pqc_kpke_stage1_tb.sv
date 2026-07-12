// pqc_kpke_stage1_tb.sv
//
// M3 Issue #8, Vaihe 1: ciphertextin purku. c1[0], c1[1] (kumpikin
// ByteEncode_10(Compress_10(u'[i]))) ja c2 (ByteEncode_4(Compress_4(v'))),
// puretaan ByteDecode_du/dv + Decompress_du/dv:n kautta, verrataan
// golden-mallin omaan u'/v'-arvoon (JO HAVIOLLISESTI purettu, ei
// alkuperainen naytearvo - ks. kpke_decrypt_golden.py:n oma kommentti).

`timescale 1ns/1ps

module pqc_kpke_stage1_tb;

  localparam int DU = 10;
  localparam int DV = 4;
  localparam int COEFF_W = 16;

  // --- u'[0], u'[1]: ByteDecode_10 + Decompress_10 ---
  logic [256*DU-1:0] c1_0, c1_1;
  logic [256*DU-1:0] compressed_u0, compressed_u1;
  logic [256*COEFF_W-1:0] u_prime_0, u_prime_1;

  pqc_bytedecode_dparam #(.D(DU)) dec_u0 (.b_in(c1_0), .f_out(compressed_u0));
  pqc_bytedecode_dparam #(.D(DU)) dec_u1 (.b_in(c1_1), .f_out(compressed_u1));
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) decomp_u0 (.y_packed(compressed_u0), .x_packed(u_prime_0));
  pqc_batch_decompress #(.D(DU), .COEFF_W(COEFF_W)) decomp_u1 (.y_packed(compressed_u1), .x_packed(u_prime_1));

  // --- v': ByteDecode_4 + Decompress_4 ---
  logic [256*DV-1:0] c2;
  logic [256*DV-1:0] compressed_v;
  logic [256*COEFF_W-1:0] v_prime;

  pqc_bytedecode_dparam #(.D(DV)) dec_v (.b_in(c2), .f_out(compressed_v));
  pqc_batch_decompress #(.D(DV), .COEFF_W(COEFF_W)) decomp_v (.y_packed(compressed_v), .x_packed(v_prime));

  logic [256*COEFF_W-1:0] u_prime_0_expect, u_prime_1_expect, v_prime_expect;

  int error_count, fh, scan_ok;

  initial begin
    error_count = 0;
    fh = $fopen("vectors/kpke_stage1_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", c1_0);
    scan_ok = $fscanf(fh, "%h\n", c1_1);
    scan_ok = $fscanf(fh, "%h\n", c2);
    scan_ok = $fscanf(fh, "%h\n", u_prime_0_expect);
    scan_ok = $fscanf(fh, "%h\n", u_prime_1_expect);
    scan_ok = $fscanf(fh, "%h\n", v_prime_expect);
    $fclose(fh);

    #1;

    if (u_prime_0 !== u_prime_0_expect) begin
      $display("FAIL u_prime[0]: %h, odotettu %h", u_prime_0, u_prime_0_expect);
      error_count++;
    end else $display("OK u_prime[0] tasmaa golden-malliin");

    if (u_prime_1 !== u_prime_1_expect) begin
      $display("FAIL u_prime[1]: %h, odotettu %h", u_prime_1, u_prime_1_expect);
      error_count++;
    end else $display("OK u_prime[1] tasmaa golden-malliin");

    if (v_prime !== v_prime_expect) begin
      $display("FAIL v_prime: %h, odotettu %h", v_prime, v_prime_expect);
      error_count++;
    end else $display("OK v_prime tasmaa golden-malliin");

    // Negatiivikontrolli: muutetaan yksi c1_0-tavu, varmistetaan etta u_prime_0 muuttuu
    begin
      logic [256*COEFF_W-1:0] u0_before;
      u0_before = u_prime_0;
      c1_0[7:0] = c1_0[7:0] + 8'd1;
      #1;
      if (u_prime_0 === u0_before) begin
        $display("FAIL: c1_0:n muutos ei vaikuttanut u_prime_0:aan!");
        error_count++;
      end else $display("OK: c1_0:n muutos vaikuttaa u_prime_0:aan - moduuli reagoi todistetusti");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: Vaihe 1 (ciphertextin purku) tasmaa golden-malliin");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
