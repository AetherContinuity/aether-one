// pqc_dilithium_pack_h.sv
//
// M5-DILITHIUM-001 DK6 S8: _pack_h - hintien pakkaus tiheasta
// 0/1-taulukosta harvaan esitykseen (positiolista + offsetit).
// OMEGA=55, K=6 (ML-DSA-65), h_bytes=OMEGA+K=61 tavua.
// KAANTEINEN operaatio jo todistetulle pqc_dilithium_unpack_h.sv:lle.
//
// dilithium-py:n oma kaava:
//   non_zero_positions[p] = [i for i,c in enumerate(coeffs) if c==1]
//   packed = non_zero_positions[0] || non_zero_positions[1] || ...
//   offsets[p] = len(packed) TAMAN polynomin jalkeen (kumulatiivinen)
//   padding: taydennetaan packed OMEGA-pituiseksi nollilla
//   return packed || offsets

`timescale 1ns/1ps

module pqc_dilithium_pack_h #(
    parameter int OMEGA = 55,
    parameter int K = 6
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [K*256-1:0] h_in_flat,   // tiheana 0/1

    output logic done,
    output logic [8*(OMEGA+K)-1:0] h_bytes_out
);

  logic [7:0] packed_mem [0:OMEGA-1];
  logic [7:0] offsets_mem [0:K-1];

  typedef enum logic [2:0] { S_IDLE, S_INIT_PACKED, S_SCAN, S_STORE_OFFSET, S_PAD, S_DONE } state_e;
  state_e state;

  logic [2:0] row_ctr;
  logic [8:0] coeff_ctr;
  logic [7:0] write_ptr;   // seuraava vapaa paikka packed_mem:ssa
  logic [8:0] init_ctr;

  always_ff @(posedge clk) begin
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          init_ctr <= 9'd0;
          state <= S_INIT_PACKED;
        end

        S_INIT_PACKED: begin
          packed_mem[init_ctr[6:0]] <= 8'd0;
          if (init_ctr == OMEGA-1) begin
            row_ctr <= 3'd0;
            coeff_ctr <= 9'd0;
            write_ptr <= 8'd0;
            state <= S_SCAN;
          end else init_ctr <= init_ctr + 9'd1;
        end

        S_SCAN: begin
          if (h_in_flat[row_ctr*256+coeff_ctr]) begin
            packed_mem[write_ptr] <= coeff_ctr[7:0];
            write_ptr <= write_ptr + 8'd1;
          end
          if (coeff_ctr == 9'd255) begin
            offsets_mem[row_ctr] <= write_ptr + (h_in_flat[row_ctr*256+coeff_ctr] ? 8'd1 : 8'd0);
            coeff_ctr <= 9'd0;
            if (row_ctr == K-1) begin
              state <= S_DONE;
            end else begin
              row_ctr <= row_ctr + 3'd1;
              state <= S_SCAN;
            end
          end else begin
            coeff_ctr <= coeff_ctr + 9'd1;
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

  genvar gi;
  generate
    for (gi = 0; gi < OMEGA; gi++) begin : g_packed
      assign h_bytes_out[gi*8 +: 8] = packed_mem[gi];
    end
    for (gi = 0; gi < K; gi++) begin : g_offset
      assign h_bytes_out[(OMEGA+gi)*8 +: 8] = offsets_mem[gi];
    end
  endgenerate

endmodule
