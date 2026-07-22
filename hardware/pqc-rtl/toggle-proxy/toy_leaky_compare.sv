// toy_leaky_compare.sv
//
// TUNNETUSTI VUOTAVA leikkitoteutus toggle-count-proxy-mittarin
// validointia varten (M3-MLKEM-002-suunnitelman oma vaatimus: mittari
// TAYTYY validoida tunnetulla vuodolla ENNEN kuin sen tulosta
// Decapsille voidaan tulkita luotettavaksi).
//
// 32-tavuinen tavukohtainen vertailu VARHAISELLA KESKEYTYKSELLA -
// pysahtyy heti ensimmaisen eroavan tavun kohdalla (klassinen
// memcmp/strcmp-tyylinen aikaikkuna-/kytkentavuoto). TAMAN TAYTYY
// nayttaa SELVA kytkentaeromaara varhaisen ja myohaisen/olemattoman
// eron valilla, JOTTA toggle-count-proxy voidaan todeta toimivaksi.

`timescale 1ns/1ps

module toy_leaky_compare (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [255:0] a_in,   // 32 tavua
    input  logic [255:0] b_in,   // 32 tavua
    output logic done,
    output logic match_out,

    // Debug-ulostulot toggle-mittausta varten
    output logic [4:0] idx_out,
    output logic cmp_stage_out
);

  typedef enum logic [1:0] {S_IDLE, S_COMPARE, S_DONE} state_e;
  state_e state;
  logic [4:0] idx;
  logic cmp_result;

  assign idx_out = idx;
  assign cmp_stage_out = cmp_result;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= S_IDLE;
      done <= 1'b0;
      match_out <= 1'b0;
      idx <= 5'd0;
      cmp_result <= 1'b0;
    end else begin
      done <= 1'b0;
      case (state)
        S_IDLE: if (start) begin
          idx <= 5'd0;
          state <= S_COMPARE;
        end

        S_COMPARE: begin
          cmp_result <= (a_in[idx*8 +: 8] == b_in[idx*8 +: 8]);
          if (a_in[idx*8 +: 8] != b_in[idx*8 +: 8]) begin
            // VARHAINEN KESKEYTYS - tama on VUOTO: syklimaara JA
            // kytkentamaara riippuvat SIITA missa kohtaa ensimmainen
            // ero loytyy.
            match_out <= 1'b0;
            state <= S_DONE;
          end else if (idx == 5'd31) begin
            match_out <= 1'b1;
            state <= S_DONE;
          end else begin
            idx <= idx + 5'd1;
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

endmodule
