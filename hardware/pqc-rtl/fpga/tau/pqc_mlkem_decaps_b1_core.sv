// pqc_mlkem_decaps_b1_core.sv
//
// M4-DECAPS-ORCH-001 Phase B1: K-PKE.Encrypt:n alkuosa - A-matriisin
// muodostus (SampleNTT) ja deterministinen kohinageneraatio
// (PRF+SamplePolyCBD) r':sta. EI VIELA matriisikertolaskuja/NTT:ta -
// VAIN syotteen muodostus todennetaan tassa vaiheessa (kayttajan
// oma, tarkoituksellinen rajaus riskien hallitsemiseksi).
//
// SEKVENSSI (vastaa tb/pqc_mlkem_decaps_b_tb.sv:n alkuosaa):
// 1. ByteDecode(12) ek:sta -> t_hat[i] (EI VIELA kaytetty tassa
//    vaiheessa, mutta puretaan yhdessa rho:n kanssa koska ne
//    tulevat samasta ek-syotteesta)
// 2. rho = ek:n viimeiset 32 tavua
// 3. SampleNTT(rho,i,j) KxK kertaa -> A[i][j]
// 4. PRF+SamplePolyCBD(r',N) ETA1:lla, N=0,1 -> y_vec[0], y_vec[1]
// 5. PRF+SamplePolyCBD(r',N) ETA2:lla, N=2,3 -> e1_vec[0], e1_vec[1]
// 6. PRF+SamplePolyCBD(r',N) ETA2:lla, N=4 -> e2_poly
//
// TAMA ON TUTKIMUSPROTOTYYPPI, OSA 1/4 Phase B:sta (kayttajan oma
// B1-B4-jako). Uudelleenkayttaa M4-MLKEM-ORCH-001:n (KeyGen)
// todistettua SampleNTT+CBD-silmukkarakennetta.

`timescale 1ns/1ps

module pqc_mlkem_decaps_b1_core #(
    parameter int COEFF_W = 16,
    parameter int K = 2,
    parameter int ETA1 = 3,
    parameter int ETA2 = 2
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [8*800-1:0] ek_in,   // ek (800 tavua: K*384 t_hat + 32 rho)
    input  logic [255:0] r_prime_in,

    output logic done,
    output logic [4*256*COEFF_W-1:0] A_out_flat,        // A[0][0],A[0][1],A[1][0],A[1][1] jarjestyksessa
    output logic [K*256*COEFF_W-1:0] y_vec_out_flat,
    output logic [K*256*COEFF_W-1:0] e1_vec_out_flat,
    output logic [256*COEFF_W-1:0] e2_poly_out
);

  logic samplentt_start, samplentt_done, samplentt_err;
  logic [255:0] samplentt_rho;
  logic [7:0] samplentt_j, samplentt_i;
  logic [256*COEFF_W-1:0] samplentt_out;
  logic [15:0] sn_acc, sn_rej, sn_xof;
  pqc_samplentt #(.XOF_BYTES(1008)) samplentt_dut (
    .clk(clk), .reset(reset), .start(samplentt_start),
    .rho(samplentt_rho), .byte_j(samplentt_j), .byte_i(samplentt_i),
    .a_hat(samplentt_out), .accepted_count(sn_acc), .rejected_count(sn_rej),
    .xof_bytes_consumed(sn_xof), .done(samplentt_done), .error_exhausted(samplentt_err)
  );

  logic cbd1_start, cbd1_done;
  logic [255:0] cbd1_seed;
  logic [7:0] cbd1_n;
  logic [256*COEFF_W-1:0] cbd1_out;
  pqc_prf_samplepolycbd #(.ETA(ETA1)) cbd1_dut (
    .clk(clk), .reset(reset), .start(cbd1_start),
    .seed_s(cbd1_seed), .counter_n(cbd1_n), .f_out(cbd1_out), .done(cbd1_done)
  );

  logic cbd2_start, cbd2_done;
  logic [255:0] cbd2_seed;
  logic [7:0] cbd2_n;
  logic [256*COEFF_W-1:0] cbd2_out;
  pqc_prf_samplepolycbd #(.ETA(ETA2)) cbd2_dut (
    .clk(clk), .reset(reset), .start(cbd2_start),
    .seed_s(cbd2_seed), .counter_n(cbd2_n), .f_out(cbd2_out), .done(cbd2_done)
  );

  logic [256*12-1:0] bdec12_in [0:1];
  logic [256*12-1:0] bdec12_out_raw [0:1];
  pqc_bytedecode_dparam #(.D(12)) bdec12_0 (.b_in(bdec12_in[0]), .f_out(bdec12_out_raw[0]));
  pqc_bytedecode_dparam #(.D(12)) bdec12_1 (.b_in(bdec12_in[1]), .f_out(bdec12_out_raw[1]));

  logic [256*COEFF_W-1:0] t_hat [0:K-1];
  logic [255:0] rho;
  logic [1:0] i_ctr, j_ctr;
  logic [2:0] n_ctr;  // 0..2K (K=2: 0,1=y_vec; 2,3=e1_vec; 4=e2_poly)

  // Sisaiset (unpacked, EI portteja - turvallinen Icarus Verilogissa)
  logic [256*COEFF_W-1:0] A [0:K-1][0:K-1];
  logic [256*COEFF_W-1:0] y_vec [0:K-1];
  logic [256*COEFF_W-1:0] e1_vec [0:K-1];

  typedef enum logic [3:0] {
    S_IDLE, S_DECODE_T, S_START_SNTT, S_WAIT_SNTT, S_SNTT_NEXT,
    S_START_CBD1, S_WAIT_CBD1, S_START_CBD2, S_WAIT_CBD2, S_CBD_NEXT, S_DONE
  } state_e;
  state_e state;

  always_ff @(posedge clk) begin
    samplentt_start <= 1'b0;
    cbd1_start <= 1'b0;
    cbd2_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            bdec12_in[0] <= ek_in[(0*384)*8 +: 384*8];
            bdec12_in[1] <= ek_in[(1*384)*8 +: 384*8];
            rho <= ek_in[(384*K)*8 +: 32*8];
            state <= S_DECODE_T;
          end
        end

        S_DECODE_T: begin
          for (int cc = 0; cc < 256; cc++) begin
            t_hat[0][cc*COEFF_W +: COEFF_W] <= {4'b0, bdec12_out_raw[0][cc*12 +: 12]};
            t_hat[1][cc*COEFF_W +: COEFF_W] <= {4'b0, bdec12_out_raw[1][cc*12 +: 12]};
          end
          i_ctr <= 2'd0; j_ctr <= 2'd0;
          state <= S_START_SNTT;
        end

        S_START_SNTT: begin
          samplentt_rho <= rho; samplentt_i <= {6'b0,i_ctr}; samplentt_j <= {6'b0,j_ctr};
          samplentt_start <= 1'b1;
          state <= S_WAIT_SNTT;
        end

        S_WAIT_SNTT: begin
          if (samplentt_done) begin
            A[i_ctr][j_ctr] <= samplentt_out;
            state <= S_SNTT_NEXT;
          end
        end

        S_SNTT_NEXT: begin
          if (j_ctr == K-1) begin
            j_ctr <= 2'd0;
            if (i_ctr == K-1) begin
              i_ctr <= 2'd0; n_ctr <= 3'd0;
              state <= S_START_CBD1;
            end else begin
              i_ctr <= i_ctr + 2'd1;
              state <= S_START_SNTT;
            end
          end else begin
            j_ctr <= j_ctr + 2'd1;
            state <= S_START_SNTT;
          end
        end

        // --- y_vec: PRF+CBD(ETA1), N=0..K-1 ---
        S_START_CBD1: begin
          cbd1_seed <= r_prime_in; cbd1_n <= {5'b0,n_ctr};
          cbd1_start <= 1'b1;
          state <= S_WAIT_CBD1;
        end

        S_WAIT_CBD1: begin
          if (cbd1_done) begin
            y_vec[n_ctr[0]] <= cbd1_out;
            if (n_ctr == K-1) begin
              n_ctr <= n_ctr + 3'd1;
              state <= S_START_CBD2;
            end else begin
              n_ctr <= n_ctr + 3'd1;
              state <= S_START_CBD1;
            end
          end
        end

        // --- e1_vec (N=K..2K-1) ja e2_poly (N=2K): PRF+CBD(ETA2) ---
        S_START_CBD2: begin
          cbd2_seed <= r_prime_in; cbd2_n <= {5'b0,n_ctr};
          cbd2_start <= 1'b1;
          state <= S_WAIT_CBD2;
        end

        S_WAIT_CBD2: begin
          if (cbd2_done) begin
            if (n_ctr == 2*K) begin
              e2_poly_out <= cbd2_out;
              state <= S_DONE;
            end else begin
              e1_vec[n_ctr - K] <= cbd2_out;
              n_ctr <= n_ctr + 3'd1;
              state <= S_START_CBD2;
            end
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

  // --- Litistys: sisaiset unpacked-taulukot -> paketoidut ulostuloportit ---
  assign A_out_flat = {A[1][1], A[1][0], A[0][1], A[0][0]};
  assign y_vec_out_flat = {y_vec[1], y_vec[0]};
  assign e1_vec_out_flat = {e1_vec[1], e1_vec[0]};

endmodule
