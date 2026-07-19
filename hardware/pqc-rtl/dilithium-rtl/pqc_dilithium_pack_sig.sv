// pqc_dilithium_pack_sig.sv
//
// M5-DILITHIUM-001 DK6 S8: koko allekirjoituksen pakkaus.
// sig = c_tilde(48) || bit_pack_z(z) (L*640=3200) || pack_h(h) (OMEGA+K=61)
// Yhteensa 48+3200+61=3309 tavua (ML-DSA-65).

`timescale 1ns/1ps

module pqc_dilithium_pack_sig #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24,
    parameter int OMEGA = 55,
    parameter int K = 6,
    parameter int L = 5
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [383:0] c_tilde_in,
    input  logic [L*256*ZW-1:0] z_in_flat,
    input  logic [K*256-1:0] h_in_flat,

    output logic done,
    output logic [8*(48+L*640+OMEGA+K)-1:0] sig_out
);

  // --- bit_pack_z(z) - taysin kombinatorinen ---
  logic [L*256*20-1:0] z_packed;
  pqc_dilithium_pack_z_vector #(.GAMMA1(GAMMA1), .ZW(ZW), .L(L)) packz_dut (
    .z_in_flat(z_in_flat), .packed_out(z_packed)
  );

  // --- pack_h(h) - sekventiaalinen ---
  logic packh_start, packh_done;
  logic [8*(OMEGA+K)-1:0] h_packed;
  pqc_dilithium_pack_h #(.OMEGA(OMEGA), .K(K)) packh_dut (
    .clk(clk), .reset(reset), .start(packh_start),
    .h_in_flat(h_in_flat), .done(packh_done), .h_bytes_out(h_packed)
  );

  typedef enum logic [1:0] { S_IDLE, S_START_PACKH, S_WAIT_PACKH, S_DONE } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    packh_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) state <= S_START_PACKH;
        S_START_PACKH: begin packh_start <= 1'b1; state <= S_WAIT_PACKH; end
        S_WAIT_PACKH: if (packh_done) state <= S_DONE;
        S_DONE: begin done <= 1'b1; state <= S_IDLE; end
        default: state <= S_IDLE;
      endcase
    end
  end

  // pack_bytes-konventio: c_tilde ALIMMAT tavut, sitten z, sitten h
  assign sig_out = {h_packed, z_packed, c_tilde_in};

endmodule
