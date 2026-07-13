// pqc_keccak_f1600.sv
//
// M3 Issue #10: Keccak-p[1600,24] permutaatioydin, iteratiivinen
// (Vaihtoehto B, KECCAK_DESIGN_NOTE.md 3.4) - yksi kierros per sykli,
// laskuri 0..23.
//
// Tila sisaisesti 5x5-taulukkona 64-bittisia laneja (EI porttina -
// portit ovat pakattuja 1600-bittisia vektoreita, Issue #7:n korjattu
// periaate). Lane-indeksointi i=x+5y vastaa golden-mallin
// bytes_to_state/state_to_bytes-konventiota (ks. keccak_golden.py).
//
// RHO_OFFSETS ja RC ladataan ROM:eista (m2-golden/keccak_rho_rom.memh,
// keccak_rc_rom.memh), generoitu SUORAAN golden-mallista - ei kasin
// transkriboitu, valttaen transkriptiovirheen riskin kokonaan.

`timescale 1ns/1ps

module pqc_keccak_f1600 (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [1599:0] state_in,
    output logic [1599:0] state_out,
    output logic done
);

  typedef enum logic [1:0] {S_IDLE, S_ROUND, S_DONE} state_e;
  state_e fsm_state;

  logic [63:0] A [0:4][0:4];   // tila: A[x][y]
  logic [5:0]  round_idx;

  logic [5:0] rho_rom [0:24];
  logic [63:0] rc_rom [0:23];
  initial $readmemh("m2-golden/keccak_rho_rom.memh", rho_rom);
  initial $readmemh("m2-golden/keccak_rc_rom.memh", rc_rom);

  // --- Yhden kierroksen kombinatorinen laskenta (theta,rho,pi,chi,iota) ---
  logic [63:0] C [0:4];
  logic [63:0] D [0:4];
  logic [63:0] A_theta [0:4][0:4];
  logic [63:0] B [0:4][0:4];
  logic [63:0] A_next [0:4][0:4];

  function automatic [63:0] rotl64(input [63:0] x, input int n);
    int nn;
    begin
      nn = n % 64;
      rotl64 = (x << nn) | (x >> (64 - nn));
    end
  endfunction

  always_comb begin
    // theta
    for (int x = 0; x < 5; x++) begin
      C[x] = A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4];
    end
    for (int x = 0; x < 5; x++) begin
      D[x] = C[(x+4)%5] ^ rotl64(C[(x+1)%5], 1);
    end
    for (int x = 0; x < 5; x++) begin
      for (int y = 0; y < 5; y++) begin
        A_theta[x][y] = A[x][y] ^ D[x];
      end
    end

    // rho + pi (yhdistetty): B[y][(2x+3y)%5] = rotl(A_theta[x][y], offset(x,y))
    for (int x = 0; x < 5; x++) begin
      for (int y = 0; y < 5; y++) begin
        B[y][(2*x+3*y)%5] = rotl64(A_theta[x][y], rho_rom[x+5*y]);
      end
    end

    // chi
    for (int x = 0; x < 5; x++) begin
      for (int y = 0; y < 5; y++) begin
        A_next[x][y] = B[x][y] ^ ((~B[(x+1)%5][y]) & B[(x+2)%5][y]);
      end
    end

    // iota (vain lane 0,0, kierroksen mukainen vakio)
    A_next[0][0] = A_next[0][0] ^ rc_rom[round_idx];
  end

  // --- FSM ---
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      fsm_state <= S_IDLE;
      done      <= 1'b0;
      round_idx <= 6'd0;
    end else begin
      case (fsm_state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            for (int i = 0; i < 25; i++) begin
              A[i%5][i/5] <= state_in[i*64 +: 64];
            end
            round_idx <= 6'd0;
            fsm_state <= S_ROUND;
          end
        end

        S_ROUND: begin
          for (int x = 0; x < 5; x++) begin
            for (int y = 0; y < 5; y++) begin
              A[x][y] <= A_next[x][y];
            end
          end
          if (round_idx == 6'd23) begin
            fsm_state <= S_DONE;
          end else begin
            round_idx <= round_idx + 6'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          fsm_state <= S_IDLE;
        end

        default: fsm_state <= S_IDLE;
      endcase
    end
  end

  always_comb begin
    for (int i = 0; i < 25; i++) begin
      state_out[i*64 +: 64] = A[i%5][i/5];
    end
  end

endmodule
