// Synteesikoetta varten: N kappaletta pqc_dilithium_make_hint.sv:ta
// rinnakkain (mallintaa sign_hint_core.sv:n omaa K*256=1536-skaalaa).

module pqc_dilithium_make_hint_parallel_wrapper #(
    parameter int N = 256,
    parameter int Q = 8380417,
    parameter int CW = 23,
    parameter int ALPHA = 523776
)(
    input  logic [N*CW-1:0] z_in_flat,
    input  logic [N*CW-1:0] r_in_flat,
    output logic [N-1:0] h_out_flat
);

  genvar gi;
  generate
    for (gi = 0; gi < N; gi++) begin : g_mh
      pqc_dilithium_make_hint #(.Q(Q), .CW(CW), .ALPHA(ALPHA)) dut (
        .z_in(z_in_flat[gi*CW +: CW]),
        .r_in(r_in_flat[gi*CW +: CW]),
        .h_out(h_out_flat[gi])
      );
    end
  endgenerate

endmodule
