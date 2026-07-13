// pqc_amatrix_tb.sv
//
// M3 Issue #15, Kerros 2 (osa 1): A-matriisin generointi, k=2. Ajaa
// pqc_samplentt.sv:aa (Issue #15) NELJASTI (i,j molemmat 0..1),
// vertaa golden-mallin koko matriisiin. EI uutta RTL:aa - vain
// integraatio-orkestrointi jo validoidun moduulin ympärille.

`timescale 1ns/1ps

module pqc_amatrix_tb;

  localparam int XOF_BYTES = 1008;
  localparam int K = 2;

  logic clk, reset, start, done, error_exhausted;
  logic [255:0] rho;
  logic [7:0] byte_j, byte_i;
  logic [16*256-1:0] a_hat;
  logic [15:0] accepted_count, rejected_count, xof_bytes_consumed;

  pqc_samplentt #(.XOF_BYTES(XOF_BYTES)) dut (
    .clk(clk), .reset(reset), .start(start),
    .rho(rho), .byte_j(byte_j), .byte_i(byte_i),
    .a_hat(a_hat), .accepted_count(accepted_count), .rejected_count(rejected_count),
    .xof_bytes_consumed(xof_bytes_consumed), .done(done), .error_exhausted(error_exhausted)
  );

  always #5 clk = ~clk;

  logic [16*256-1:0] A_matrix [0:K-1][0:K-1];
  logic [16*256-1:0] A_expect [0:K-1][0:K-1];

  int fh, scan_ok, error_count;
  int iv, jv;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; start = 0; rho = '0; byte_j = 0; byte_i = 0;

    fh = $fopen("vectors/amatrix_k2_vectors.txt", "r");
    scan_ok = $fscanf(fh, "%h\n", rho);
    for (int n = 0; n < K*K; n++) begin
      logic [16*256-1:0] tmp_val;
      scan_ok = $fscanf(fh, "%d %d\n", iv, jv);
      scan_ok = $fscanf(fh, "%h\n", tmp_val);
      A_expect[iv][jv] = tmp_val;
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // A[i][j] = SampleNTT(rho||j||i) - FIPS 203 Algoritmi 13 rivi 5
    // (LOPULLINEN teksti, Liite C.2:ssa vahvistettu korjaus luonnoksen
    // i/j-vaihtoon nahden).
    for (int i = 0; i < K; i++) begin
      for (int j = 0; j < K; j++) begin
        byte_j = j[7:0];
        byte_i = i[7:0];
        reset = 1; @(posedge clk); reset = 0; @(posedge clk);
        start <= 1'b1; @(posedge clk); start <= 1'b0;
        while (!done) @(posedge clk);
        #1;
        A_matrix[i][j] = a_hat;
      end
    end

    for (int i = 0; i < K; i++) begin
      for (int j = 0; j < K; j++) begin
        if (A_matrix[i][j] !== A_expect[i][j]) begin
          $display("FAIL A[%0d][%0d]: poikkeaa golden-mallista", i, j);
          error_count++;
        end else begin
          $display("OK A[%0d][%0d]: tasmaa golden-malliin", i, j);
        end
      end
    end

    // Varmistus: A[0][1] != A[1][0] (matriisi ei symmetrinen)
    if (A_matrix[0][1] === A_matrix[1][0]) begin
      $display("FAIL: A[0][1] == A[1][0] - indeksointi vaikuttaa vaaralta!");
      error_count++;
    end else begin
      $display("OK: A[0][1] != A[1][0] - matriisi ei symmetrinen, indeksointi oikein");
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: A-matriisi (k=%0d, %0d alkiota) tasmaa golden-malliin", K, K*K);
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
