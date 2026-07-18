// M5-DILITHIUM-001 DK5-testi: bit_pack_w todennus dilithium-py:n
// omaa tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_w_tb;

  localparam int K = 6;

  logic [K*256*4-1:0] w_prime_in_flat;
  logic [8*K*128-1:0] w_prime_packed_out;

  pqc_dilithium_pack_w #(.K(K)) dut (
    .w_prime_in_flat(w_prime_in_flat), .w_prime_packed_out(w_prime_packed_out)
  );

  int fh, scan_ok;
  logic [K*256*4-1:0] w_val;
  logic [8*K*128-1:0] expect_out;

  initial begin
    fh = $fopen("dilithium-rtl/pack_w_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", w_val);
    scan_ok = $fscanf(fh, "%h\n", expect_out);
    $fclose(fh);

    w_prime_in_flat = w_val;
    #1;

    if (w_prime_packed_out === expect_out) begin
      $display("PASS: bit_pack_w (768 tavua) tasmaa taydellisesti dilithium-py:n tulokseen");
    end else begin
      $display("FAIL: bit_pack_w EI tasmaa");
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
