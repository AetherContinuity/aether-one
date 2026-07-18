// pqc_dilithium_unpack_h.sv
//
// M5-DILITHIUM-001 DK5: _unpack_h - hintien purku harvasta
// esityksesta (positiolista + offsetit) tiheaksi 0/1-taulukoksi
// jokaiselle K:sta polynomista. OMEGA=55, K=6 (ML-DSA-65),
// h_bytes=OMEGA+K=61 tavua.
//
// dilithium-py:n oma kaava:
//   offsets = [0] + h_bytes[-K:]           (K+1 offset-arvoa)
//   polynomille p (0..K-1):
//     non_zero_positions[p] = h_bytes[offsets[p]:offsets[p+1]]
//     coeffs[p][pos]=1 jokaiselle pos:lle non_zero_positions[p]:ssa
//
// TAMA ON GENUINE SEKVENTIAALINEN, VAIHTELEVAN PITUUDEN PURKU -
// EI validointeja (monotonisuustarkistukset jne) TASSA ENSIMMAISESSA
// versiossa - VAIN rakenteellinen purku, olettaen kelvollisen
// syotteen (validointi VOIDAAN lisata myohemmin tarvittaessa).

`timescale 1ns/1ps

module pqc_dilithium_unpack_h #(
    parameter int OMEGA = 55,
    parameter int K = 6
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*(OMEGA+K)-1:0] h_bytes_in,

    output logic done,
    output logic [K*256-1:0] h_out_flat  // K*256 * 1-bittinen (0/1) hint
);

  logic [7:0] h_bytes [0:OMEGA+K-1];
  logic [7:0] offsets [0:K];  // offsets[0]=0, offsets[1..K]=h_bytes[OMEGA..OMEGA+K-1]

  logic h_mem [0:K-1][0:255];

  typedef enum logic [2:0] { S_IDLE, S_LOAD, S_SETUP_OFFSETS, S_INIT_ZERO, S_DECODE, S_NEXT_POLY, S_DONE } state_e;
  state_e state;

  logic [7:0] load_idx;
  logic [2:0] p_ctr;      // 0..K-1
  logic [8:0] init_idx;   // 0..255
  logic [7:0] byte_idx;   // offsets[p]..offsets[p+1]-1

  always_ff @(posedge clk) begin
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          load_idx <= 8'd0;
          state <= S_LOAD;
        end

        S_LOAD: begin
          h_bytes[load_idx] <= h_bytes_in[load_idx*8 +: 8];
          if (load_idx == OMEGA+K-1) begin
            state <= S_SETUP_OFFSETS;
          end else load_idx <= load_idx + 8'd1;
        end

        S_SETUP_OFFSETS: begin
          offsets[0] <= 8'd0;
          for (int k = 0; k < K; k++) begin
            offsets[k+1] <= h_bytes[OMEGA+k];
          end
          p_ctr <= 3'd0;
          init_idx <= 9'd0;
          state <= S_INIT_ZERO;
        end

        S_INIT_ZERO: begin
          for (int pp = 0; pp < K; pp++) h_mem[pp][init_idx[7:0]] <= 1'b0;
          if (init_idx == 9'd255) begin
            p_ctr <= 3'd0;
            byte_idx <= offsets[0];
            state <= S_DECODE;
          end else init_idx <= init_idx + 9'd1;
        end

        S_DECODE: begin
          if (byte_idx < offsets[p_ctr+1]) begin
            h_mem[p_ctr][h_bytes[byte_idx]] <= 1'b1;
            byte_idx <= byte_idx + 8'd1;
          end else begin
            state <= S_NEXT_POLY;
          end
        end

        S_NEXT_POLY: begin
          if (p_ctr == K-1) begin
            state <= S_DONE;
          end else begin
            p_ctr <= p_ctr + 3'd1;
            byte_idx <= offsets[p_ctr+1];
            state <= S_DECODE;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  genvar gp, gc;
  generate
    for (gp = 0; gp < K; gp++) begin : g_poly
      for (gc = 0; gc < 256; gc++) begin : g_coeff
        assign h_out_flat[gp*256+gc] = h_mem[gp][gc];
      end
    end
  endgenerate

endmodule
