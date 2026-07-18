// pqc_dilithium_ntt_core_bringup.sv
//
// M5-DILITHIUM-001 DK1: pqc_dilithium_ntt_core.sv:n bring-up-
// rajapintainen versio synteesia/P&R:aa varten - TAYSIN sama
// laskentalogiikka, mutta 5888-bittisten rinnakkaisporttien
// (coeffs_in/coeffs_out) SIJAAN sana-kerrallaan lataus/luku, sama
// konventio kuin ML-KEM:n pqc_ntt_stage_banked.sv:n FPGA_BRINGUP.
//
// Peruste: ensimmainen synteesiyritys (pqc_dilithium_ntt_core.sv
// sellaisenaan) EPAONNISTUI P&R:ssa - vaati ~11780 TRELLIS_IO-solmua
// (256*23-bittiset portit), mika ylittaa minka tahansa oikean piirin
// I/O-maaran massiivisesti. Tama versio korjaa TAMAN, EI muuta
// laskentalogiikkaa millaan tavalla (sama butterfly, sama skedulu).

`timescale 1ns/1ps

module pqc_dilithium_ntt_core_bringup #(
    parameter int Q = 8380417,
    parameter int CW = 23
)(
    input  logic clk,
    input  logic reset,

    input  logic start,

    // Sana-kerrallaan lataus (ENNEN start:ia): 256 sanaa, osoite 0..255
    input  logic load_valid,
    input  logic [7:0] load_addr,
    input  logic [CW-1:0] load_data,

    // Sana-kerrallaan luku (done:n JALKEEN): 256 sanaa
    input  logic read_en,
    input  logic [7:0] read_addr,
    output logic read_valid,
    output logic [CW-1:0] read_data,

    output logic done
);

  logic [CW-1:0] mem [0:255];

  logic [39:0] sched_rom [0:254];
  initial $readmemh("dilithium-rtl/dilithium_ntt_forward_schedule.memh", sched_rom);

  logic [7:0] sched_idx;
  logic [2:0] log2_l;
  logic [22:0] zeta;
  logic [7:0] group_start;
  logic [7:0] l_val;
  logic [7:0] j_idx;
  logic [7:0] j_count;

  logic [CW-1:0] bf_a_in, bf_b_in, bf_a_out, bf_b_out;
  pqc_dilithium_ntt_butterfly #(.Q(Q), .CW(CW)) bf_dut (
    .a_in(bf_a_in), .b_in(bf_b_in), .zeta_in(zeta),
    .a_out(bf_a_out), .b_out(bf_b_out)
  );

  typedef enum logic [3:0] {
    S_IDLE, S_SCHED_SETUP, S_NEXT_J_WAIT, S_READ_AB, S_COMPUTE, S_WRITE_AB, S_NEXT_GROUP, S_DONE
  } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    done <= 1'b0;

    // Sana-kerrallaan lataus toimii RESET-tilassa/S_IDLE:ssa milloin
    // tahansa ennen start:ia - erillinen taman paalogiikan tilakoneesta
    if (load_valid) mem[load_addr] <= load_data;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          j_count <= 8'd0;
          sched_idx <= 8'd0;
          state <= S_SCHED_SETUP;
        end

        S_SCHED_SETUP: begin
          begin
            logic [39:0] entry;
            entry = sched_rom[sched_idx];
            log2_l      <= entry[33:31];
            zeta        <= entry[30:8];
            group_start <= entry[7:0];
          end
          state <= S_NEXT_J_WAIT;
        end

        S_NEXT_J_WAIT: begin
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
            j_count <= 8'd0;
            if (sched_idx == 8'd254) begin
              state <= S_DONE;
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

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  assign read_valid = read_en;
  assign read_data = mem[read_addr];

endmodule
