// pqc_rvv_cluster_2lane.sv
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL.
// Todistaa: (1) Montgomery-perhosen bittitarkkuuden Python-golden-mallia
// vastaan, (2) round-robin-pankkikonfliktin ratkaisun kahden lanen valilla,
// (3) [M2 Vaihe 1] per-butterfly-zeta-indeksoinnin: idx viety ulos
// lane_fsm:sta, kumpikin lane kayttaa OMAA idx-arvoaan indeksoidakseen
// jaettua tw_window-taulukkoa - ei enaa kiinteaa tw_window[0]:aa.
// Ei todista: piirin ajoitusta, pinta-alaa, synteesikelpoisuutta.
//
// SKOOPIN RAJAUS (tietoinen): yksi NTT-taso, COUNT butterflya per lane.
// Molemmat lanet pakotettu bankkiin 0 konfliktin pakottamiseksi.
// Lane0 ja lane1 kayttavat SAMAA tw_window-taulukkoa samalla idx:lla -
// tama ei viela mallinna oikeaa 256-pisteen NTT:n globaalia butterfly-
// asemointia (jossa eri lanet kasittelisivat eri butterfly-alueita eri
// zetoilla) - se on M2 Vaihe 2:n (koko Cooley-Tukey) laajuus, ei talla.
// Ei toteuta: monivaiheista NTT-aikataulutinta eika useampaa muistipankkia
// (M2 Vaihe 3:n laajuus, ei talla).

`timescale 1ns/1ps

module lane_fsm_addr_pipe #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 15,
    parameter int Q       = 3329,
    parameter int QINV    = 62209,
    parameter int READ_LATENCY = 0  // M4-FPGA-002D (2026-07-17): 0 =
        // nollaviiveinen (kombinatorinen) muisti, TASMALLEEN nykyinen
        // kaytos, oletus - EI vaikuta olemassa olevaan kayttoon
        // lainkaan. 1 = yksi ylimaarainen odotussykli grant:n
        // jalkeen ennen nayttestysta (BRAM-yhteensopiva rekisteroity
        // luku). Ks. M4_FPGA_BRAM_STUDY.md: lane_fsm todettiin
        // rakennetuksi nollaviiveisen muistin varaan simulaatiokokeella
        // ennen tata muutosta.
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [SPAD_AW-1:0] base_addr,
    input  logic [7:0] stride,
    input  logic [7:0] count,
    input  logic [7:0] pair_dist,  // M2 Vaihe 2c: ajonaikainen
        // paritusetaisyys (esim. 128/64/32/... eri NTT-tasoille).
        // MUUTETTU parametrista portiksi 2026-07-10 (ei enaa
        // oletusarvoa 2026-07-11): Verilator EI TUE oletusarvoja
        // moduulin porteille lainkaan (Unsupported: Default value on
        // module input) - synteesikelpoisuustarkistuksessa loydetty.
        // Kaikki instanssit (myos M1/M2 Vaihe 1) kytkevat pair_dist:n
        // nyt eksplisiittisesti.
    input  logic mode,  // M3 Issue #8 Vaihe 3: 0=FORWARD (NTT, Alg. 9),
        // 1=INVERSE (NTT^-1, Alg. 10). Butterfly-kaava eroaa aidosti,
        // ei vain silmukkajarjestys - ks. NTT_INVERSE_DESIGN_NOTE.md §2.
        // Kaikki olemassa olevat instanssit kytkevat mode=1'b0
        // (muuttumaton kayttaytyminen).

    output logic [SPAD_AW-1:0] mem_addr_a,
    output logic [SPAD_AW-1:0] mem_addr_b,
    input  logic [COEFF_W-1:0] mem_rdata_a,
    input  logic [COEFF_W-1:0] mem_rdata_b,
    output logic [COEFF_W-1:0] mem_wdata_a,
    output logic [COEFF_W-1:0] mem_wdata_b,
    input  logic [COEFF_W-1:0] zeta_in,

    output logic req,
    output logic is_write,
    input  logic grant,

    output logic [2:0] state,
    output logic done,
    output logic [7:0] idx_out
);

  localparam logic [2:0]
    S_IDLE      = 3'd0,
    S_REQ_READ  = 3'd1,
    S_WAIT_READ = 3'd5,  // M4-FPGA-002D: kaytossa VAIN jos READ_LATENCY=1
    S_WAIT_READ2 = 3'd7, // M4-FPGA-006B koe: toinen odotussykli, osoitteen
                         // rekisterointia varten ennen BRAM-lukua
    S_COMPUTE1  = 3'd6,  // M4-FPGA-006/007 koe: pipeline-vaihe 1 (kertolasku)
    S_COMPUTE   = 3'd2,
    S_REQ_WRITE = 3'd3,
    S_DONE      = 3'd4;

  logic [7:0] idx;
  assign idx_out = idx;
  logic [COEFF_W-1:0] a_reg, b_reg;
  logic [COEFF_W-1:0] ap_reg, bp_reg;
  logic [2*COEFF_W-1:0] mult_term;  // M4-FPGA-006/007: pipeline-vaiheen 1 rekisteri

  assign mem_addr_a  = base_addr + idx * stride;
  assign mem_addr_b  = mem_addr_a + pair_dist;
  assign mem_wdata_a = ap_reg;
  assign mem_wdata_b = bp_reg;

  // Tasmalleen pq-crystals/kyber ref/reduce.c:
  //   t = (int16_t)a*QINV;
  //   t = (a - (int32_t)t*KYBER_Q) >> 16;
  // KORJATTU 2026-07-10: alkuperainen versio kaytti VAARAA operaattoria
  // (yhteenlasku, etumerkiton tulkinta) - QINV=62209 oli aina oikea
  // Kyberin omalle referenssikaavalle, mutta kaava itse ei tasmannyt.
  // Todennettu tayden Kyber-referenssin ("QINV" GitHub) tekstia vasten
  // ennen korjausta, ei vain paateltyna.
  function automatic [COEFF_W-1:0] montgomery_reduce(input int unsigned a);
    logic signed [15:0] a_lo;
    logic signed [15:0] t16;
    logic signed [31:0] prod;
    logic signed [31:0] result;
    begin
      a_lo   = a[15:0];
      t16    = a_lo * $signed(16'(QINV));
      prod   = $signed(t16) * Q;
      result = ($signed({1'b0, a}) - prod) >>> 16;
      if (result < 0) result = result + Q;
      else if (result >= Q) result = result - Q;
      montgomery_reduce = result[COEFF_W-1:0];
    end
  endfunction

  function automatic [COEFF_W-1:0] mod_add(input int unsigned a, input int unsigned t);
    int unsigned s;
    begin
      s = a + t;
      if (s >= Q) s = s - Q;
      mod_add = s[COEFF_W-1:0];
    end
  endfunction

  function automatic [COEFF_W-1:0] mod_sub(input int unsigned a, input int unsigned t);
    int signed d;
    begin
      d = $signed({1'b0, a}) - $signed({1'b0, t});
      if (d < 0) d = d + Q;
      mod_sub = d[COEFF_W-1:0];
    end
  endfunction

  always_ff @(posedge clk) begin
    if (reset) begin
      state    <= S_IDLE;
      idx      <= 8'd0;
      req      <= 1'b0;
      is_write <= 1'b0;
      done     <= 1'b0;
    end else begin
      unique case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            idx      <= 8'd0;
            req      <= 1'b1;
            is_write <= 1'b0;
            state    <= S_REQ_READ;
          end
        end

        S_REQ_READ: begin
          if (grant) begin
            req <= 1'b0;
            if (READ_LATENCY == 0) begin
              // TASMALLEEN alkuperainen kaytos (nollaviiveinen muisti)
              a_reg <= mem_rdata_a;
              b_reg <= mem_rdata_b;
              state <= S_COMPUTE1;
            end else begin
              // M4-FPGA-002D: odota yksi ylimaarainen sykli ennen
              // nayttestysta (rekisteroidyn muistin tulos ei ole
              // viela valmis samalla reunalla kuin grant nousee)
              state <= S_WAIT_READ;
            end
          end
        end

        S_WAIT_READ: begin
          // M4-FPGA-006B koe: EI viela nayttestysta - odota TOINEN
          // sykli, jotta arbitroitu osoite (shared_raddr) ehtii
          // rekisteroitua ENNEN varsinaista BRAM-lukua.
          state <= S_WAIT_READ2;
        end

        S_WAIT_READ2: begin
          a_reg <= mem_rdata_a;
          b_reg <= mem_rdata_b;
          state <= S_COMPUTE1;
        end

        // M4-FPGA-006/007 koe (kayttajan oma, tarkasti rajattu ehdotus):
        // YKSI rekisterivaihe pisimman ketjun keskelle. Vaihe 1: laske
        // ENSIMMAINEN kertolasku (b*zeta FORWARD:lle, (b-a)*zeta
        // INVERSE:lle) ja REKISTEROI se - katkaisee kolmen kertolaskun
        // ketjun kahteen osaan (1 kertolasku + rekisteri + 2 kertolaskua
        // (Montgomery-redusointi) + lopullinen yhteen-/vahennyslasku).
        S_COMPUTE1: begin
          if (mode == 1'b0) begin
            mult_term <= b_reg * zeta_in;
          end else begin
            mult_term <= mod_sub(b_reg, a_reg) * zeta_in;
          end
          state <= S_COMPUTE;
        end

        S_COMPUTE: begin
          if (mode == 1'b0) begin
            // FORWARD (NTT, Algoritmi 9): t=zeta*b ENSIN, sama t
            // molemmissa ulostuloissa. mult_term = b_reg*zeta_in,
            // laskettu JO S_COMPUTE1:ssa (rekisteroity).
            ap_reg   <= mod_add(a_reg, montgomery_reduce(mult_term));
            bp_reg   <= mod_sub(a_reg, montgomery_reduce(mult_term));
          end else begin
            // INVERSE (NTT^-1, Algoritmi 10): EI zetaa a+b-ulostulossa;
            // zeta vasta (b-a):n jalkeen TOISESSA ulostulossa. Ks.
            // NTT_INVERSE_DESIGN_NOTE.md §2/§3. mult_term =
            // mod_sub(b_reg,a_reg)*zeta_in, laskettu JO S_COMPUTE1:ssa.
            ap_reg   <= mod_add(a_reg, b_reg);
            bp_reg   <= montgomery_reduce(mult_term);
          end
          req      <= 1'b1;
          is_write <= 1'b1;
          state    <= S_REQ_WRITE;
        end

        S_REQ_WRITE: begin
          if (grant) begin
            req <= 1'b0;
            if (idx == count - 8'd1) begin
              state <= S_DONE;
              done  <= 1'b1;
            end else begin
              idx      <= idx + 8'd1;
              req      <= 1'b1;
              is_write <= 1'b0;
              state    <= S_REQ_READ;
            end
          end
        end

        S_DONE: begin
          done  <= 1'b1;
          state <= S_IDLE;  // KORJATTU 2026-07-10: S_DONE oli pysyva
              // lopputila, ei koskaan palannut S_IDLE:hen - toinen
              // start-pulssi ei koskaan kaynnistanyt uutta ajoa. Ei
              // huomattu aiemmin koska M1/Vaihe1/2b kayttivat moduulia
              // vain kerran per simulaatio (ks. M2 Vaihe 2c-i, jossa
              // sama moduuli ajetaan kahdesti peräkkäin).
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule



