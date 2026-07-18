// pqc_dilithium_ntt_inverse_core.sv
//
// M5-DILITHIUM-001 DK1: koko 256-kertoimisen inverse-NTT:n
// orkestrointi. Sama rakenne kuin pqc_dilithium_ntt_core.sv (forward),
// mutta GS-butterfly + inverse-skedulu + LOPULLINEN skaalaus
// (kerroin * ntt_f mod Q, ntt_f = 256^-1 mod Q = 8347681).

`timescale 1ns/1ps

module pqc_dilithium_ntt_inverse_core #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter longint NTT_F = 8347681  // 256^-1 mod Q
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [256*CW-1:0] coeffs_in,

    output logic done,
    output logic [256*CW-1:0] coeffs_out
);

  logic [CW-1:0] mem [0:255];

  logic [39:0] sched_rom [0:254];
  initial $readmemh("dilithium-rtl/dilithium_ntt_inverse_schedule.memh", sched_rom);

  logic [7:0] sched_idx;
  logic [2:0] log2_l;
  logic [22:0] zeta;
  logic [7:0] group_start;
  logic [7:0] l_val;
  logic [7:0] j_idx;
  logic [7:0] j_count;

  logic [CW-1:0] bf_a_in, bf_b_in, bf_a_out, bf_b_out;
  pqc_dilithium_ntt_gs_butterfly #(.Q(Q), .CW(CW)) bf_dut (
    .a_in(bf_a_in), .b_in(bf_b_in), .zeta_in(zeta),
    .a_out(bf_a_out), .b_out(bf_b_out)
  );

  // Lopullinen skaalaus: jokainen kerroin * ntt_f mod Q
  logic [CW-1:0] scale_in, scale_out;
  pqc_dilithium_barrett_mulmod #(.Q(Q)) scale_dut (
    .a_in(scale_in), .b_in(NTT_F[CW-1:0]), .result_out(scale_out)
  );

  typedef enum logic [3:0] {
    S_IDLE, S_LOAD, S_SCHED_SETUP, S_READ_AB, S_COMPUTE, S_WRITE_AB,
    S_SCALE_SETUP, S_SCALE_WRITE, S_DONE
  } state_e;
  state_e state;

  logic [8:0] load_idx;
  logic [8:0] scale_idx;

  always_ff @(posedge clk) begin
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          load_idx <= 9'd0;
          j_count <= 8'd0;
          state <= S_LOAD;
        end

        S_LOAD: begin
          mem[load_idx[7:0]] <= coeffs_in[load_idx[7:0]*CW +: CW];
          if (load_idx == 9'd255) begin
            sched_idx <= 8'd0;
            state <= S_SCHED_SETUP;
          end else load_idx <= load_idx + 9'd1;
        end

        S_SCHED_SETUP: begin
          begin
            logic [39:0] entry;
            entry = sched_rom[sched_idx];
            log2_l      <= entry[33:31];
            zeta        <= entry[30:8];
            group_start <= entry[7:0];
          end
          if (j_count == 8'd0) begin
            // ensimmainen kerta - j_idx alustetaan S_READ_AB:n edella,
            // odotetaan seuraavaa sykliä kun log2_l/group_start ovat settled
          end
          state <= S_READ_AB;
        end

        S_READ_AB: begin
          if (j_count == 8'd0) begin
            j_idx <= group_start;
            l_val <= (8'd1 << log2_l);
          end
          state <= S_COMPUTE;
        end

        S_COMPUTE: begin
          bf_a_in <= mem[j_idx];
          bf_b_in <= mem[j_idx + l_val];
          state <= S_WRITE_AB;
        end

        S_WRITE_AB: begin
          mem[j_idx] <= bf_a_out;
          mem[j_idx + l_val] <= bf_b_out;
          if (j_count + 8'd1 == l_val) begin
            j_count <= 8'd0;
            if (sched_idx == 8'd254) begin
              scale_idx <= 9'd0;
              state <= S_SCALE_SETUP;
            end else begin
              sched_idx <= sched_idx + 8'd1;
              state <= S_SCHED_SETUP;
            end
          end else begin
            j_count <= j_count + 8'd1;
            j_idx <= j_idx + 8'd1;
            state <= S_READ_AB;
          end
        end

        // --- Lopullinen skaalaus: jokainen kerroin * ntt_f mod Q ---
        S_SCALE_SETUP: begin
          scale_in <= mem[scale_idx[7:0]];
          state <= S_SCALE_WRITE;
        end

        S_SCALE_WRITE: begin
          mem[scale_idx[7:0]] <= scale_out;
          if (scale_idx == 9'd255) begin
            state <= S_DONE;
          end else begin
            scale_idx <= scale_idx + 9'd1;
            state <= S_SCALE_SETUP;
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
    for (gi = 0; gi < 256; gi++) begin : g_out
      assign coeffs_out[gi*CW +: CW] = mem[gi];
    end
  endgenerate

endmodule
