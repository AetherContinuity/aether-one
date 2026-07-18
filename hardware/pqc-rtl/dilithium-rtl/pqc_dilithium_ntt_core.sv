// pqc_dilithium_ntt_core.sv
//
// M5-DILITHIUM-001 DK1: koko 256-kertoimisen NTT:n orkestrointi,
// ML-DSA:n Q=8380417. Kayttaa jo todistettua butterfly-moduulia
// (pqc_dilithium_ntt_butterfly.sv) ja skedulu-ROMia (255 riviä,
// generoitu SUORAAN dilithium-py:n omasta to_ntt()-silmukasta).
//
// TAMA ON ENSIMMAINEN, YKSINKERTAISIN VERSIO (korrektius edella,
// optimointi myohemmin - sama periaate kuin ML-KEM:n oma NTT-tyo):
// yksinkertainen rekisteripohjainen 256*23-bittinen muisti (EI viela
// BRAM-pankitusta), yksi butterfly-operaatio kerrallaan, useita
// syklia per butterfly (lue a, lue b, laske, kirjoita a, kirjoita b).

`timescale 1ns/1ps

module pqc_dilithium_ntt_core #(
    parameter int Q = 8380417,
    parameter int CW = 23
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
  initial $readmemh("dilithium-rtl/dilithium_ntt_forward_schedule.memh", sched_rom);

  logic [7:0] sched_idx;      // 0..254 (255 ryhmaa)
  logic [2:0] log2_l;
  logic [22:0] zeta;
  logic [7:0] group_start;
  logic [7:0] l_val;          // 2^log2_l
  logic [7:0] j_idx;          // start..start+l-1
  logic [7:0] j_count;        // kuinka monta butterflyta tehty tassa ryhmassa

  logic [CW-1:0] bf_a_in, bf_b_in, bf_a_out, bf_b_out;
  pqc_dilithium_ntt_butterfly #(.Q(Q), .CW(CW)) bf_dut (
    .a_in(bf_a_in), .b_in(bf_b_in), .zeta_in(zeta),
    .a_out(bf_a_out), .b_out(bf_b_out)
  );

  typedef enum logic [3:0] {
    S_IDLE, S_LOAD, S_SCHED_SETUP, S_READ_AB, S_COMPUTE, S_WRITE_AB, S_NEXT_J, S_NEXT_GROUP, S_DONE
  } state_e;
  state_e state;

  logic [8:0] load_idx;

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
          state <= S_NEXT_J;  // j_idx alustetaan seuraavassa tilassa group_start:sta
        end

        S_NEXT_J: begin
          // Ensimmainen kerta tassa ryhmassa: j_idx=group_start, j_count=0
          if (j_count == 8'd0) begin
            j_idx <= group_start;
            l_val <= (8'd1 << log2_l);
          end
          state <= S_READ_AB;
        end

        S_READ_AB: state <= S_COMPUTE;

        S_COMPUTE: begin
          bf_a_in <= mem[j_idx];
          bf_b_in <= mem[j_idx + l_val];
          state <= S_WRITE_AB;
        end

        S_WRITE_AB: begin
          mem[j_idx] <= bf_a_out;
          mem[j_idx + l_val] <= bf_b_out;
          if (j_count + 8'd1 == l_val) begin
            // Ryhma valmis
            j_count <= 8'd0;
            state <= S_NEXT_GROUP;
          end else begin
            j_count <= j_count + 8'd1;
            j_idx <= j_idx + 8'd1;
            state <= S_READ_AB;
          end
        end

        S_NEXT_GROUP: begin
          if (sched_idx == 8'd254) begin
            load_idx <= 9'd0;
            state <= S_DONE;
          end else begin
            sched_idx <= sched_idx + 8'd1;
            state <= S_SCHED_SETUP;
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
