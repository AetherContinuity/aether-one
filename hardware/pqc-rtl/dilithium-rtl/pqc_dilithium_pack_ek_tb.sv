// M5-DILITHIUM-001 DK4-testi: ek-pakkaus todennus dilithium-py:n
// omaa _pack_pk()-tulosta vasten.

`timescale 1ns/1ps

module pqc_dilithium_pack_ek_tb;

  localparam int K = 6;

  logic [255:0] rho_in;
  logic [K*256*10-1:0] t1_in_flat;
  logic [8*(32+K*320)-1:0] ek_out;

  pqc_dilithium_pack_ek #(.K(K)) dut (
    .rho_in(rho_in), .t1_in_flat(t1_in_flat), .ek_out(ek_out)
  );

  int fh, scan_ok;
  logic [255:0] rho_val;
  logic [K*256*10-1:0] t1_val;
  logic [8*(32+K*320)-1:0] ek_expect;

  initial begin
    fh = $fopen("dilithium-rtl/pack_ek_test_vector.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho_val);
    scan_ok = $fscanf(fh, "%h\n", t1_val);
    scan_ok = $fscanf(fh, "%h\n", ek_expect);
    $fclose(fh);

    rho_in = rho_val; t1_in_flat = t1_val;
    #1;

    if (ek_out === ek_expect) begin
      $display("PASS: ek-pakkaus (%0d tavua) tasmaa taydellisesti dilithium-py:n _pack_pk()-tulokseen", (32+K*320));
    end else begin
      int diffs;
      diffs = 0;
      for (int b = 0; b < 32+K*320; b++) begin
        if (ek_out[b*8+:8] !== ek_expect[b*8+:8]) diffs++;
      end
      $display("FAIL: %0d/%0d tavua eroaa", diffs, 32+K*320);
      $fatal(1);
    end

    $display("--------------------------------------------------");
    $finish;
  end

endmodule
