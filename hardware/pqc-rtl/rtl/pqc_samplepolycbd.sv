// pqc_samplepolycbd.sv
//
// M3 Issue #15: SamplePolyCBD_eta (FIPS 203 Algoritmi 8). EI
// hylkaysta, EI silmukkaa tarvita - taysin kombinatorinen datapolku
// (kayttajan oma ohje: valta tarpeeton FSM kun rinnakkainen/
// yksinkertainen datapolku riittaa).
//
// B_in:n bittijarjestys tasmaa suoraan BytesToBits-konvention (bitti
// n = tavu(n/8):n bitti (n mod 8), LSB-ensin) - sama havainto kuin
// ByteEncode/Decode-tyossa (Issue #7): pakatun vektorin oma bitti-
// indeksointi VASTAA jo BytesToBits:n ulostuloa, erillista muunnosta
// ei tarvita.

`timescale 1ns/1ps

module pqc_samplepolycbd #(
    parameter int ETA = 2,
    parameter int Q   = 3329
)(
    input  logic [8*64*ETA-1:0] B_in,
    output logic [16*256-1:0] f_out
);

  always_comb begin
    for (int i = 0; i < 256; i++) begin
      logic [3:0] x, y;
      logic [15:0] diff;
      x = '0;
      y = '0;
      for (int j = 0; j < ETA; j++) begin
        x = x + {3'b0, B_in[2*i*ETA + j]};
      end
      for (int j = 0; j < ETA; j++) begin
        y = y + {3'b0, B_in[2*i*ETA + ETA + j]};
      end
      // f[i] = (x - y) mod Q - x,y pieni (0..eta<=3), joten x-y valilla [-3,3]
      diff = {12'b0, x} - {12'b0, y};
      if (diff[15]) begin  // negatiivinen (kaksikomplementti) -> lisaa Q
        f_out[i*16 +: 16] = diff + Q[15:0];
      end else begin
        f_out[i*16 +: 16] = diff;
      end
    end
  end

endmodule
