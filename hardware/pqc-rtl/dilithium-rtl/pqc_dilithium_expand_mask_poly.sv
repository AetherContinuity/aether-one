// pqc_dilithium_expand_mask_poly.sv
//
// M5-DILITHIUM-001 DK6 S1: ExpandMask (SampleMask), yksi polynomi
// (FIPS 204 Algoritmi 34). GAMMA1=2^19 (ML-DSA-65).
//
// dilithium-py:n oma kaava:
//   seed = rho_prime(64) || (kappa+i, 2 tavua pikkuendian)
//   xof_bytes = SHAKE256(seed, 640 tavua)
//   altered = tiukka 20-bittinen purku xof_bytes:sta (EI hylkaysta)
//   y[c] = GAMMA1 - altered[c]
//
// TAMA ON SAMA "vakio miinus arvo" -kaava kuin jo todistetussa
// pqc_dilithium_unpack_z.sv:ssa - UUDELLEENKAYTETAAN sita suoraan,
// vain XOF-generointi on UUSI.

`timescale 1ns/1ps

module pqc_dilithium_expand_mask_poly #(
    parameter int GAMMA1 = 524288,
    parameter int ZW = 24
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [511:0] rho_prime_in,   // 64 tavua
    input  logic [15:0] kappa_plus_i_in,  // kappa+i, 2 tavua pikkuendian

    output logic done,
    output logic [256*ZW-1:0] y_out_flat
);

  logic shake_start, shake_done;
  logic [8*136*5-1:0] shake_msg_in;  // 66 tavua syote, riittaa 1 lohkoon (136 tavua/lohko)
  logic [8*640-1:0] shake_out;       // 640 tavua ulostuloa -> 5 SHAKE256-lohkoa
  pqc_shake256 #(.MAX_BLOCKS(5), .MAX_OUT_BYTES(640)) shake_dut (
    .clk(clk), .reset(reset), .start(shake_start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'd66), .out_len_bytes(16'd640),
    .out_data(shake_out), .done(shake_done)
  );

  pqc_dilithium_unpack_z #(.GAMMA1(GAMMA1), .ZW(ZW)) unpack_dut (
    .packed_in(shake_out[256*20-1:0]), .z_out_flat(y_out_flat)
  );

  typedef enum logic [1:0] { S_IDLE, S_START_SHAKE, S_WAIT_SHAKE, S_DONE } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    shake_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          shake_msg_in <= '0;
          shake_msg_in[511:0] <= rho_prime_in;
          shake_msg_in[527:512] <= kappa_plus_i_in;
          state <= S_START_SHAKE;
        end

        S_START_SHAKE: begin
          shake_start <= 1'b1;
          state <= S_WAIT_SHAKE;
        end

        S_WAIT_SHAKE: if (shake_done) state <= S_DONE;

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
