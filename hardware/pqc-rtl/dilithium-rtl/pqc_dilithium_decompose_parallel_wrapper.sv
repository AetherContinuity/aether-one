// pqc_dilithium_decompose_parallel_wrapper.sv
//
// Synteesikoetta varten (2026-07-20): instantioi N kappaletta
// pqc_dilithium_decompose.sv:ta RINNAKKAIN (EI ajallisesti jaettuna),
// mallintaen samaa rakennetta kuin verify_core.sv/sign_hint_core.sv
// kayttavat OIKEASTI (K*256=1536 rinnakkaista instanssia). Tarkoitus:
// saada OIKEA, MITATTU datapiste skaalauskayralle (solut vs. N),
// EI vain lineaarinen ekstrapolointi yhdesta instanssista.

module pqc_dilithium_decompose_parallel_wrapper #(
    parameter int N = 256,
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int ALPHA = 523776
)(
    input  logic [N*CW-1:0] r_in_flat,
    output logic [N*4-1:0] r1_out_flat,
    output logic [N*CW-1:0] r0_out_flat
);

  genvar gi;
  generate
    for (gi = 0; gi < N; gi++) begin : g_decomp
      pqc_dilithium_decompose #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) dut (
        .r_in(r_in_flat[gi*CW +: CW]),
        .r1_out(r1_out_flat[gi*4 +: 4]),
        .r0_out(r0_out_flat[gi*CW +: CW])
      );
    end
  endgenerate

endmodule
