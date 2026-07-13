// pqc_prf_samplepolycbd.sv
//
// M3 Issue #15, Kerros 1 (Entropy/seed): PRF_eta(sigma,N) ->
// SamplePolyCBD_eta. Puhdas kokoonpano jo validoiduista moduuleista
// (pqc_shake256, Issue #14; pqc_samplepolycbd, Issue #15) - EI uutta
// aritmetiikkaa.
//
// PRF_eta(s,b) := SHAKE256(s||b, 8*64*eta), FIPS 203 kaava (4.3).
// s=32 tavua (sigma tai r), b=1 tavu (N-laskuri).

`timescale 1ns/1ps

module pqc_prf_samplepolycbd #(
    parameter int ETA = 2
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [255:0] seed_s,   // sigma tai r (32 tavua)
    input  logic [7:0] counter_n,  // N-laskuri (1 tavu)
    output logic [16*256-1:0] f_out,
    output logic done
);

  localparam int SHAKE_MAX_BLOCKS = 1;  // 33-tavuinen syote mahtuu 1 SHAKE256-lohkoon (rate=136)
  localparam int OUT_BYTES = 64 * ETA;

  logic [8*136*SHAKE_MAX_BLOCKS-1:0] shake_msg_in;
  logic [8*OUT_BYTES-1:0] shake_out;
  logic shake_done;

  assign shake_msg_in = {{(136*SHAKE_MAX_BLOCKS-33){8'h00}}, counter_n, seed_s};

  pqc_shake256 #(.MAX_BLOCKS(SHAKE_MAX_BLOCKS), .MAX_OUT_BYTES(OUT_BYTES)) shake_dut (
    .clk(clk), .reset(reset), .start(start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'd33), .out_len_bytes(OUT_BYTES[15:0]),
    .out_data(shake_out), .done(shake_done)
  );

  pqc_samplepolycbd #(.ETA(ETA)) cbd_dut (
    .B_in(shake_out), .f_out(f_out)
  );

  assign done = shake_done;

endmodule
