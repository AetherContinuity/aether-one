// pqc_batch_compress.sv
//
// M3 Issue #8, Vaihe 4: kaare joka ajaa 256 pqc_compress-instanssia
// rinnakkain (Compress-suuntaan), D kiinteana kaannosaikaisena
// parametrina - sama periaate kuin pqc_batch_decompress.sv (Vaihe 1).
//
// Portit pakattuina vektoreina (Issue #7:n korjattu periaate).

`timescale 1ns/1ps

module pqc_batch_compress #(
    parameter int D       = 1,
    parameter int COEFF_W = 16,
    parameter int Q       = 3329
)(
    input  logic [256*COEFF_W-1:0] x_packed,   // 256 arvoa, COEFF_W bittia/arvo (Zq)
    output logic [256*D-1:0] y_packed          // 256 arvoa, D bittia/arvo (pakattu domain)
);

  genvar i;
  generate
    for (i = 0; i < 256; i = i + 1) begin : loop
      logic [COEFF_W-1:0] y_dummy_out;
      logic [COEFF_W-1:0] compress_wide;

      pqc_compress #(.COEFF_W(COEFF_W), .Q(Q)) inst (
        .d(D[3:0]),
        .x_in(x_packed[i*COEFF_W +: COEFF_W]), .compress_out(compress_wide),
        .y_in('0), .decompress_out(y_dummy_out)  // ei kaytossa tallä suunnalla
      );
      assign y_packed[i*D +: D] = compress_wide[D-1:0];
    end
  endgenerate

endmodule
