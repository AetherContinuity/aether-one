// pqc_dilithium_rej_bounded_poly.sv
//
// M5-DILITHIUM-001 DK3: RejBoundedPoly (ExpandS:n oma polynomin-oma
// nayttestys, FIPS 204 Algoritmi 31), ETA=4 (ML-DSA-65). Kayttaa
// SHAKE256:ta (ERI kuin ExpandA:n SHAKE128).
//
// dilithium-py:n oma kaava: seed = rho_prime || bytes([i],2,little)
// XOF = SHAKE256(seed). Jokaisesta tavusta puretaan KAKSI
// neljannestavua (alempi ensin, sitten ylempi): j=tavu, c0=j%16,
// c1=j//16. Kummallekin: jos nelijas < 9 (ETA=4), kerroin = 4-j
// (arvot 4,3,2,1,0,-1,-2,-3,-4 j=0..8:lle), muuten HYLATAAN.
//
// Ulostulo: RAA'AT ETUMERKILLISET arvot (-4..4), EI Zq-muunnettuja -
// TASMALLEEN kuten dilithium-py:n oma coeffs-lista. Zq-muunnos
// (jos/kun tarvitaan NTT:hen) tehdaan KAYTTOPAIKASSA, ei tassa
// moduulissa - pitaa taman moduulin ulostulon SUORAAN vertailu-
// kelpoisena kirjaston omaan tulokseen.

`timescale 1ns/1ps

module pqc_dilithium_rej_bounded_poly #(
    parameter int ETA = 4,
    parameter int XOF_BYTES = 408  // 3 SHAKE256-lohkoa, reilu turvamarginaali (~228 tavua odotettu keskimaarin)
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [511:0] rho_prime_in,   // 64 tavua (H-funktion oma SHA3-512-ulostulo tuotannossa)
    input  logic [15:0] i_in,

    output logic done,
    output logic error_exhausted,
    output logic [256*8-1:0] coeffs_out_flat  // 256 * 8-bittinen etumerkillinen arvo (-4..4)
);

  logic shake_start, shake_done;
  logic [8*136*3-1:0] shake_msg_in;
  logic [8*XOF_BYTES-1:0] shake_out;
  pqc_shake256 #(.MAX_BLOCKS(3), .MAX_OUT_BYTES(XOF_BYTES)) shake_dut (
    .clk(clk), .reset(reset), .start(shake_start),
    .msg_in(shake_msg_in), .msg_len_bytes(16'd66), .out_len_bytes(XOF_BYTES[15:0]),
    .out_data(shake_out), .done(shake_done)
  );

  logic signed [7:0] coeffs [0:255];
  logic [8:0] byte_idx;
  logic [8:0] accepted;
  logic half_sel;  // 0=alempi nelijas ensin, 1=ylempi

  typedef enum logic [2:0] { S_IDLE, S_START_SHAKE, S_WAIT_SHAKE, S_SAMPLE, S_DONE, S_EXHAUSTED } state_e;
  state_e state;

  wire [7:0] cur_byte = shake_out[byte_idx*8 +: 8];
  wire [3:0] nibble = half_sel ? cur_byte[7:4] : cur_byte[3:0];

  always_ff @(posedge clk) begin
    shake_start <= 1'b0;
    done <= 1'b0;

    if (reset) begin
      state <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: if (start) begin
          shake_msg_in <= '0;
          shake_msg_in[511:0] <= rho_prime_in;
          shake_msg_in[527:512] <= i_in;
          state <= S_START_SHAKE;
        end

        S_START_SHAKE: begin
          shake_start <= 1'b1;
          state <= S_WAIT_SHAKE;
        end

        S_WAIT_SHAKE: if (shake_done) begin
          byte_idx <= 9'd0;
          accepted <= 9'd0;
          half_sel <= 1'b0;
          state <= S_SAMPLE;
        end

        S_SAMPLE: begin
          if (nibble < 9) begin
            coeffs[accepted[7:0]] <= 8'(ETA) - {4'b0, nibble};
            if (accepted == 9'd255) state <= S_DONE;
            else accepted <= accepted + 9'd1;
          end
          if (half_sel == 1'b1) begin
            // molemmat nelijakset kasitelty tasta tavusta, siirry seuraavaan
            if (byte_idx == XOF_BYTES-1) begin
              if (accepted != 9'd255) state <= S_EXHAUSTED;
            end else begin
              byte_idx <= byte_idx + 9'd1;
              half_sel <= 1'b0;
            end
          end else begin
            half_sel <= 1'b1;
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
