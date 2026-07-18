// pqc_dilithium_rej_ntt_poly.sv
//
// M5-DILITHIUM-001 DK2: RejNTTPoly / ExpandA:n oma polynomin-oma
// nayttestys (FIPS 204 Algoritmi 30), yksi (i,j)-polynomi kerrallaan.
// Kayttaa suoraan jo todistettua pqc_shake128.sv-ydinta (sama SHAKE128
// kuin ML-KEM:n omassa SampleNTT:ssa).
//
// dilithium-py:n oma kaava: seed = rho || bytes([j, i]) (HUOM
// JARJESTYS: j ENSIN, sitten i - EI i,j! Tama on TASMALLEEN se
// tyyppinen indeksointi-yksityiskohta joka aiheutti sekaannuksen
// ML-KEM-Decapsin A-matriisin transpoosityossa - tarkistettu
// huolellisesti suoraan kirjaston lahdekoodista, ei oletettu.)
//
// XOF-tavuja: 3 tavua/naytemaara -> 1 kerroin (23-bittinen,
// pikkuendian, ylin bitti nollataan 0x7FFFFF-maskilla), hylataan jos
// >= Q. Hyvaksymisosuus ~99.9% (Q/2^23), joten 280 naytetta (840
// tavua) riittaa KAYTANNOSSA AINA 256 hyvaksytyn kertoimen saamiseksi
// - jos EI riita (aarimmaisen epatodennakoinen), moduuli EI koskaan
// pyyda lisaa taman ENSIMMAISEN version rajoissa (dokumentoitu
// rajaus, ei piilotettu).

`timescale 1ns/1ps

module pqc_dilithium_rej_ntt_poly #(
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int XOF_BYTES = 840  // 280 naytetta * 3 tavua
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [255:0] rho_in,
    input  logic [7:0] i_in,
    input  logic [7:0] j_in,

    output logic done,
    output logic error_exhausted,           // XOF-puskuri loppui ennen 256 hyvaksyttya (dokumentoitu, ei viela kasitelty)
    output logic [256*CW-1:0] coeffs_out
);

  logic shake_start, shake_done;
  logic [8*168*5-1:0] shake_msg_in;  // 5*168=840 tavua riittaa >= 34-tavuiselle syotteelle
  logic [8*XOF_BYTES-1:0] shake_out;
  pqc_shake128 #(.MAX_BLOCKS(5), .MAX_OUT_BYTES(XOF_BYTES)) shake_dut (
    .clk(clk), .reset(reset), .start(shake_start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'd34), .out_len_bytes(XOF_BYTES[15:0]),
    .out_data(shake_out), .done(shake_done)
  );

  logic [CW-1:0] coeffs [0:255];
  logic [9:0] byte_idx;    // 0..XOF_BYTES-1 (askel 3)
  logic [8:0] accepted;    // 0..256

  typedef enum logic [2:0] { S_IDLE, S_START_SHAKE, S_WAIT_SHAKE, S_SAMPLE, S_DONE, S_EXHAUSTED } state_e;
  state_e state;

  wire [22:0] candidate = {shake_out[(byte_idx+2)*8 +: 7], shake_out[(byte_idx+1)*8 +: 8], shake_out[byte_idx*8 +: 8]};

  always_ff @(posedge clk) begin
    shake_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          shake_msg_in <= '0;
          shake_msg_in[255:0] <= rho_in;
          shake_msg_in[263:256] <= j_in;   // HUOM: j ENSIN
          shake_msg_in[271:264] <= i_in;   // sitten i
          state <= S_START_SHAKE;
        end

        S_START_SHAKE: begin
          shake_start <= 1'b1;
          state <= S_WAIT_SHAKE;
        end

        S_WAIT_SHAKE: if (shake_done) begin
          byte_idx <= 10'd0;
          accepted <= 9'd0;
          state <= S_SAMPLE;
        end

        S_SAMPLE: begin
          if (candidate < Q) begin
            coeffs[accepted[7:0]] <= candidate[CW-1:0];
            if (accepted == 9'd255) begin
              state <= S_DONE;
            end else accepted <= accepted + 9'd1;
          end
          if (byte_idx + 10'd3 >= XOF_BYTES) begin
            if (accepted != 9'd255) state <= S_EXHAUSTED;
          end else byte_idx <= byte_idx + 10'd3;
        end

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        S_EXHAUSTED: begin
          // Dokumentoitu rajaus (ks. moduulin oma yla-kommentti):
          // taman ensimmaisen version XOF-puskuri EI riittanyt.
          // Aarimmaisen epatodennakoinen (~99.9% hyvaksymisosuus).
          done <= 1'b1;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  assign error_exhausted = (state == S_EXHAUSTED);

  genvar gi;
  generate
    for (gi = 0; gi < 256; gi++) begin : g_out
      assign coeffs_out[gi*CW +: CW] = coeffs[gi];
    end
  endgenerate

endmodule
