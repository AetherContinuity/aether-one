// SYNTH-001: pqc_dilithium_barrett_mulmod_pipe2:n toiminnallinen
// testi. Yksinkertainen syota->odota 2 syklia->tarkista-menetelma
// jokaiselle testiparille erikseen (valttaa ajoituksen kohdistus-
// virheet jotka jatkuvassa striimauksessa voisivat syntya).

`timescale 1ns/1ps

module barrett_pipe2_tb;

  localparam int Q = 8380417;
  localparam int CW = 23;
  localparam int NUM_TESTS = 100000;

  logic clk, reset;
  logic [CW-1:0] a_in, b_in;
  logic [CW-1:0] result_comb;
  logic [CW-1:0] result_pipe;

  always #5 clk = ~clk;

  pqc_dilithium_barrett_mulmod #(.Q(Q), .CW(CW)) dut_comb (
    .a_in(a_in), .b_in(b_in), .result_out(result_comb)
  );

  pqc_dilithium_barrett_mulmod_pipe2 #(.Q(Q), .CW(CW)) dut_pipe (
    .clk(clk), .reset(reset), .a_in(a_in), .b_in(b_in), .result_out(result_pipe)
  );

  int i, errors;
  logic [CW-1:0] a_val, b_val, expect_val;

  initial begin
    clk = 0; reset = 1; a_in = 0; b_in = 0;
    errors = 0;

    repeat (5) @(posedge clk);
    reset = 0;
    @(posedge clk);

    for (i = 0; i < NUM_TESTS; i++) begin
      a_val = $urandom() % Q;
      b_val = $urandom() % Q;

      a_in = a_val;
      b_in = b_val;
      #1; // anna kombinatorisen tuloksen asettua ENNEN reunaa
      expect_val = result_comb; // referenssiarvo TALLE syotteelle

      @(posedge clk); // syklin 1 reuna: pipe2 rekisteroi vaihe 1:n
      @(posedge clk); // syklin 2 reuna: pipe2 rekisteroi vaihe 2:n (ulostulo valmis)
      #1;

      if (result_pipe !== expect_val) begin
        errors++;
        if (errors <= 5) begin
          $display("FAIL testi %0d: a=%0d b=%0d result_pipe=%0d expect=%0d",
                    i, a_val, b_val, result_pipe, expect_val);
        end
      end
    end

    $display("--------------------------------------------------");
    if (errors == 0) begin
      $display("PASS: pqc_dilithium_barrett_mulmod_pipe2 tasmaa TAYDELLISESTI (%0d/%0d testia)", NUM_TESTS, NUM_TESTS);
    end else begin
      $display("FAIL: %0d/%0d testia epaonnistui", errors, NUM_TESTS);
      $fatal(1);
    end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
