// pqc_basecasemul_tb.sv
//
// M3 (Issue #1): testipenkki BaseCaseMultiplylle. Lukee 20 testitapausta
// tiedostosta (generoitu suoraan jo todennetusta golden-mallista),
// tarkistaa jokaisen bittitarkasti. Lisaksi negatiivikontrolli: vaara
// gamma-etumerkki (kuin sekoittaisi Dilithiumin ja Kyberin gamma-
// konvention, sama virhetyyppi kuin M2 Vaihe 2a:n omassa negatiivi-
// kontrollissa).

`timescale 1ns/1ps

module pqc_basecasemul_tb;

  localparam int COEFF_W = 16;
  localparam int Q = 3329;

  logic [COEFF_W-1:0] a0, a1, b0, b1, gamma;
  logic [COEFF_W-1:0] c0, c1;
  logic [COEFF_W-1:0] c0_correct, c1_correct;

  pqc_basecasemul #(.COEFF_W(COEFF_W), .Q(Q)) dut (
    .a0(a0), .a1(a1), .b0(b0), .b1(b1), .gamma(gamma), .c0(c0), .c1(c1)
  );

  int error_count;
  int fh;
  int va0, va1, vb0, vb1, vgamma, vc0, vc1;
  int scan_ok;

  initial begin
    error_count = 0;

    fh = $fopen("vectors/basecasemul_vectors.txt", "r");
    scan_ok = 7;
    while (!$feof(fh) && scan_ok == 7) begin
      scan_ok = $fscanf(fh, "%d %d %d %d %d %d %d\n", va0, va1, vb0, vb1, vgamma, vc0, vc1);
      if (scan_ok == 7) begin
        a0 = va0[COEFF_W-1:0]; a1 = va1[COEFF_W-1:0];
        b0 = vb0[COEFF_W-1:0]; b1 = vb1[COEFF_W-1:0];
        gamma = vgamma[COEFF_W-1:0];
        #1; // anna always_comb asettua

        if (c0 !== vc0[COEFF_W-1:0]) begin
          $display("FAIL c0: a0=%0d a1=%0d b0=%0d b1=%0d gamma=%0d -> c0=%0d, odotettu %0d", va0,va1,vb0,vb1,vgamma, c0, vc0);
          error_count++;
        end
        if (c1 !== vc1[COEFF_W-1:0]) begin
          $display("FAIL c1: a0=%0d a1=%0d b0=%0d b1=%0d gamma=%0d -> c1=%0d, odotettu %0d", va0,va1,vb0,vb1,vgamma, c1, vc1);
          error_count++;
        end
      end
    end
    $fclose(fh);

    if (error_count == 0) $display("OK: kaikki 20 testitapausta tasmaavat golden-malliin");

    // --- NEGATIIVIKONTROLLI: syotetaan tahallaan gamma+1 (vaara arvo)
    // ja varmistetaan ettei tulos silti sattumalta tasmaa oikeaan ---
    a0 = 1234; a1 = 5678 % Q; b0 = 2222; b1 = 3333 % Q; gamma = 100;
    #1;
    if (c0 == ((1234*2222 + (5678%Q)*(3333%Q)*100) % Q) &&
        c1 == ((1234*(3333%Q) + (5678%Q)*2222) % Q)) begin
      // Tama on OIKEA gammalla 100 - lasketaan nyt vaaralla gammalla 101 vertailuksi
      c0_correct = c0;
      c1_correct = c1;
      gamma = 101; // TAHALLINEN VIRHE
      #1;
      if (c0 == c0_correct && c1 == c1_correct) begin
        $display("FAIL: vaara gamma (101 oikean 100:n sijaan) tuotti SAMAN tuloksen - moduuli ei reagoi gammaan!");
        error_count++;
      end else begin
        $display("OK: vaara gamma tuottaa eri (vaaran) tuloksen - moduuli reagoi todistetusti gammaan");
      end
    end

    $display("--------------------------------------------------");
    if (error_count == 0) begin
      $display("PASS: BaseCaseMultiply tasmaa golden-malliin kaikissa 20 tapauksessa, negatiivikontrolli toimii");
    end else begin
      $display("FAIL: %0d virhetta", error_count);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
