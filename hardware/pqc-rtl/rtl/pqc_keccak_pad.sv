// pqc_keccak_pad.sv
//
// M3 Issue #11, Vaihe A: pad10*1 + domain-suffiksi, RTL:ssa. Testataan
// TAYSIN IRRALLAAN permutaatiosta (kayttajan oma ehdotus).
//
// MAX_BLOCKS=2 riittaa taman vaiheen kolmelle kriittiselle
// reunatapaukselle (tyhja viesti, rate-1 tavua, tasan rate tavua) -
// laajennetaan tarvittaessa myohemmin (Issue #15, ML-KEM-integraatio,
// jossa pidemmat syotteet, esim. PRF, saattavat tarvita useampia
// lohkoja).
//
// Portit pakattuina vektoreina (Issue #7:n korjattu periaate).

`timescale 1ns/1ps

module pqc_keccak_pad #(
    parameter int RATE_BYTES     = 136,
    parameter int MAX_BLOCKS     = 2,
    parameter int DOMAIN_SUFFIX  = 8'h06
)(
    input  logic [8*RATE_BYTES*MAX_BLOCKS-1:0] msg_in,
    input  logic [15:0] msg_len_bytes,           // todellinen viestin pituus tavuina
    output logic [8*RATE_BYTES*MAX_BLOCKS-1:0] padded_out,
    output logic [7:0] num_blocks                // montako RATE_BYTES-lohkoa merkityksellisia
);

  localparam int TOTAL_BYTES = RATE_BYTES * MAX_BLOCKS;

  always_comb begin
    int total_len_before_pad;
    int last_byte_idx;

    total_len_before_pad = msg_len_bytes + 1;  // +1 domain-suffiksitavu
    num_blocks = 8'((total_len_before_pad + RATE_BYTES - 1) / RATE_BYTES);
    // M4-MLKEM-ORCH-001 (2026-07-19): int'(...)-nimettya tyyppimuunnosta
    // korvattu 32'(...)-leveyskonversiolla - Yosysin read_verilog -sv
    // -etuosa ei tue nimettya tyyppimuunnosta tassa kontekstissa
    // ("unexpected TOK_INT"), mutta leveyskonversio antaa TASMALLEEN
    // saman arvon/kayttaytymisen. Todennettu: kaikki neljä olemassa
    // olevaa testitapausta (tyhja, rate-1, tasan rate,
    // msg_len_bytes-reagointi) pysyvat PASS-tilassa muutoksen
    // jalkeen - ei regressiota.
    last_byte_idx = 32'(num_blocks) * RATE_BYTES - 1;

    for (int i = 0; i < TOTAL_BYTES; i++) begin
      logic [7:0] byte_val;
      if (i < 32'(msg_len_bytes)) begin
        byte_val = msg_in[i*8 +: 8];
      end else if (i == 32'(msg_len_bytes)) begin
        byte_val = DOMAIN_SUFFIX[7:0];
      end else begin
        byte_val = 8'h00;
      end

      if (i == last_byte_idx) begin
        byte_val = byte_val ^ 8'h80;
      end

      padded_out[i*8 +: 8] = byte_val;
    end
  end

endmodule
