// pqc_dilithium_sample_in_ball.sv
//
// M5-DILITHIUM-001 DK5: SampleInBall (FIPS 204 Algoritmi 29), TAU=49
// (ML-DSA-65). Muodostaa harvan, ternaarisen polynomin c_tilde:sta
// (48 tavua ML-DSA-65:lle) - TAU kappaletta +-1-arvoja, loput 0.
//
// dilithium-py:n oma kaava (Fisher-Yates-tyylinen sekoitus):
//   xof = SHAKE256(c_tilde)
//   sign_int = xof.read(8) tulkittuna 64-bittisena pikkuendian-
//   kokonaislukuna (bittivirtana etumerkeille)
//   coeffs[0..255] = 0
//   for i in 256-TAU..255:
//     j = rejection_sample(i, xof)  (lue tavu, hylkaa jos > i)
//     coeffs[i] = coeffs[j]
//     coeffs[j] = 1 - 2*(sign_int & 1)
//     sign_int >>= 1
//
// TAMA ON GENUINE SEKVENTIAALINEN, TILALLINEN ALGORITMI (Fisher-
// Yates-sekoitus) - EI rinnakkaistettavissa kuten aiemmat naytteen-
// ottomoduulit. XOF-puskuri: 136 tavua (1 SHAKE256-lohko) - reilu
// turvamarginaali (8 etumerkkitavua + ~58 odotettua naytetavua
// hylkaykset huomioiden).

`timescale 1ns/1ps

module pqc_dilithium_sample_in_ball #(
    parameter int TAU = 49,
    parameter int XOF_BYTES = 136
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [383:0] c_tilde_in,   // 48 tavua (ML-DSA-65)

    output logic done,
    output logic error_exhausted,
    output logic [256*8-1:0] coeffs_out_flat  // 256 * 8-bittinen etumerkillinen (-1,0,1)
);

  logic shake_start, shake_done;
  logic [8*136-1:0] shake_msg_in;
  logic [8*XOF_BYTES-1:0] shake_out;
  pqc_shake256 #(.MAX_BLOCKS(1), .MAX_OUT_BYTES(XOF_BYTES)) shake_dut (
    .clk(clk), .reset(reset), .start(shake_start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'd48), .out_len_bytes(XOF_BYTES[15:0]),
    .out_data(shake_out), .done(shake_done)
  );

  logic signed [7:0] coeffs [0:255];
  logic [63:0] sign_reg;
  logic [8:0] byte_idx;    // 0..XOF_BYTES-1
  logic [8:0] i_ctr;       // 256-TAU..255
  logic [7:0] cur_byte;

  typedef enum logic [2:0] { S_IDLE, S_START_SHAKE, S_WAIT_SHAKE, S_INIT_COEFFS, S_SAMPLE_J, S_SWAP, S_DONE, S_EXHAUSTED } state_e;
  state_e state;

  logic [8:0] init_idx;

  assign cur_byte = shake_out[byte_idx*8 +: 8];

  always_ff @(posedge clk) begin
    shake_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          shake_msg_in <= '0;
          shake_msg_in[383:0] <= c_tilde_in;
          state <= S_START_SHAKE;
        end

        S_START_SHAKE: begin
          shake_start <= 1'b1;
          state <= S_WAIT_SHAKE;
        end

        S_WAIT_SHAKE: if (shake_done) begin
          sign_reg <= shake_out[63:0];
          byte_idx <= 9'd8;  // ensimmaiset 8 tavua kaytetty etumerkkeihin
          init_idx <= 9'd0;
          state <= S_INIT_COEFFS;
        end

        S_INIT_COEFFS: begin
          coeffs[init_idx[7:0]] <= 8'sd0;
          if (init_idx == 9'd255) begin
            i_ctr <= 9'(256 - TAU);
            state <= S_SAMPLE_J;
          end else init_idx <= init_idx + 9'd1;
        end

        S_SAMPLE_J: begin
          if (cur_byte <= i_ctr[7:0]) begin
            state <= S_SWAP;
          end else begin
            if (byte_idx == XOF_BYTES-1) state <= S_EXHAUSTED;
            else byte_idx <= byte_idx + 9'd1;
          end
        end

        S_SWAP: begin
          coeffs[i_ctr[7:0]] <= coeffs[cur_byte];
          coeffs[cur_byte] <= sign_reg[0] ? -8'sd1 : 8'sd1;
          sign_reg <= sign_reg >> 1;
          if (byte_idx == XOF_BYTES-1) begin
            // ei enaa tavuja jaljella - jos tama oli viimeinen tarvittu i,
            // OK, muuten seuraavalla i:lla loppuu tavut valittomasti
          end else byte_idx <= byte_idx + 9'd1;
          if (i_ctr == 9'd255) begin
            state <= S_DONE;
          end else begin
            i_ctr <= i_ctr + 9'd1;
            state <= S_SAMPLE_J;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          state <= S_IDLE;
        end

        S_EXHAUSTED: begin
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
      assign coeffs_out_flat[gi*8 +: 8] = coeffs[gi];
    end
  endgenerate

endmodule
