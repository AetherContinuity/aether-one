// pqc_batch_decompress.sv
//
// M3 Issue #8, Vaihe 1: kaarei joka ajaa 256 pqc_compress-instanssia
// rinnakkain (Decompress-suuntaan), D kiinteana kaannosaikaisena
// parametrina taman kaareen omalle kayttotarpeelle (ei muuta
// pqc_compress.sv:aa, joka sailyttaa oman ajonaikaisen d-porttinsa
// yleiskayttoista tarvetta varten).
//
// Portit pakattuina vektoreina (Issue #7:n korjattu periaate).

`timescale 1ns/1ps

module pqc_batch_decompress #(
    parameter int D       = 10,
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [256*D-1:0] y_packed,        // 256 arvoa, D bittia/arvo (pakattu domain)
    output logic [256*COEFF_W-1:0] x_packed   // 256 arvoa, COEFF_W bittia/arvo (Zq, purettu)
);

  genvar i;
  generate
    for (i = 0; i < 256; i = i + 1) begin : loop
      logic [COEFF_W-1:0] y_wide;
      logic [COEFF_W-1:0] x_dummy_out;
      assign y_wide = {{(COEFF_W-D){1'b0}}, y_packed[i*D +: D]};

      pqc_compress #(.COEFF_W(COEFF_W), .Q(Q)) inst (
        .d(D[3:0]),
        .x_in('0), .compress_out(x_dummy_out),  // ei kaytossa tallä suunnalla
        .y_in(y_wide),
        .decompress_out(x_packed[i*COEFF_W +: COEFF_W])
      );
    end
  endgenerate

endmodule
