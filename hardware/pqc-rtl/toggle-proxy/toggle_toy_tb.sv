// toggle_toy_tb.sv
//
// Ajaa YHDEN testitapauksen (annettu plusargilla) jompaakumpaa
// moduulia (`toy_leaky_compare` tai `toy_constant_compare`, valittu
// `+MODULE=leaky` / `+MODULE=const` plusargilla) vasten, dumpaten
// VCD:n jatkokasittelya varten. Erillinen ajo per tapaus pitaa VCD-
// tiedostot pienina ja erillisina.

`timescale 1ns/1ps

module toggle_toy_tb;

  logic clk, reset, start, done_leaky, done_const, match_leaky, match_const;
  logic [255:0] a_in, b_in;
  logic [4:0] idx_out;
  logic cmp_stage_out;

  always #5 clk = ~clk;

  toy_leaky_compare dut_leaky (
    .clk(clk), .reset(reset), .start(start),
    .a_in(a_in), .b_in(b_in),
    .done(done_leaky), .match_out(match_leaky),
    .idx_out(idx_out), .cmp_stage_out(cmp_stage_out)
  );

  toy_constant_compare dut_const (
    .clk(clk), .reset(reset), .start(start),
    .a_in(a_in), .b_in(b_in),
    .done(done_const), .match_out(match_const)
  );

  string vcd_name;
  int mismatch_pos; // -1 = ei eroa, 0-31 = tavun sijainti joka eroaa

  initial begin
    clk = 0; reset = 1; start = 0;
    a_in = 256'h0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20;
    b_in = a_in;

    if (!$value$plusargs("mismatch_pos=%d", mismatch_pos)) mismatch_pos = -1;
    if (mismatch_pos >= 0) b_in[mismatch_pos*8 +: 8] = a_in[mismatch_pos*8 +: 8] ^ 8'hFF;

    if (!$value$plusargs("vcd_name=%s", vcd_name)) vcd_name = "toggle_toy.vcd";
    $dumpfile(vcd_name);
    $dumpvars(0, toggle_toy_tb);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk); start <= 1'b1;
    @(posedge clk); start <= 1'b0;

    begin
      logic seen_leaky, seen_const;
      seen_leaky = 1'b0; seen_const = 1'b0;
      while (!(seen_leaky && seen_const)) begin
        @(posedge clk);
        if (done_leaky) seen_leaky = 1'b1;
        if (done_const) seen_const = 1'b1;
      end
    end
    @(posedge clk);

    $display("mismatch_pos=%0d match_leaky=%b match_const=%b", mismatch_pos, match_leaky, match_const);
    $finish;
  end

endmodule
