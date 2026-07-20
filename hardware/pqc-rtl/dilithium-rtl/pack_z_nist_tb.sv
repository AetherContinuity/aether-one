// Testaa pack_z_vector suoraan NIST-skenaarion oikealla z-datalla
// (jo vahvistettu oikeaksi RTL:n omana z_reg-arvona).

`timescale 1ns/1ps

module pack_z_nist_tb;

  localparam int ZW = 24;
  localparam int L = 5;

  logic [L*256*ZW-1:0] z_in_flat;
  logic [L*256*20-1:0] packed_out;

  pqc_dilithium_pack_z_vector #(.ZW(ZW), .L(L)) dut (
    .z_in_flat(z_in_flat), .packed_out(packed_out)
  );

  int fh, scan_ok;
  logic [L*256*ZW-1:0] z_val;
  logic [8*L*640-1:0] expect_bytes;

  initial begin
    fh = $fopen("dilithium-rtl/pack_z_nist_debug.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", z_val);
    scan_ok = $fscanf(fh, "%h\n", expect_bytes);
    $fclose(fh);

    z_in_flat = z_val;
    #1;

    if (packed_out === expect_bytes[L*256*20-1:0]) begin
      $display("PASS: pack_z_vector tasmaa NIST-datalla");
    end else begin
      int diffs, first_diff_bit, first_diff_poly;
      diffs = 0; first_diff_bit = -1; first_diff_poly = -1;
      for (int i = 0; i < L*256*20; i++) begin
        if (packed_out[i] !== expect_bytes[i]) begin
          diffs++;
          if (first_diff_bit == -1) begin
            first_diff_bit = i;
            first_diff_poly = i / (256*20);
          end
        end
      end
      $display("FAIL: %0d/%0d bittia eroaa NIST-datalla", diffs, L*256*20);
      $display("Ensimmainen eroava bitti: %0d (polynomi %0d, sen sisainen bitti %0d)",
                first_diff_bit, first_diff_poly, first_diff_bit - first_diff_poly*256*20);
      // Nayta ensimmaisen eroavan polynomin ensimmaiset kertoimet
      for (int c = 0; c < 5; c++) begin
        $display("  poly%0d kerroin%0d: RTL=%h golden=%h",
                  first_diff_poly, c,
                  packed_out[first_diff_poly*256*20 + c*20 +: 20],
                  expect_bytes[first_diff_poly*256*20 + c*20 +: 20]);
      end
    end

    $finish;
  end

endmodule
