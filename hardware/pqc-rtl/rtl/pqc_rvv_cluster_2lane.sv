// pqc_rvv_cluster_2lane.sv
//
// KAYTTAYTYMISMALLI (behavioral), EI synteesikelpoinen RTL.
// Todistaa: (1) Montgomery-perhosen bittitarkkuuden Python-golden-mallia
// vastaan, (2) round-robin-pankkikonfliktin ratkaisun kahden lanen valilla.
// Ei todista: piirin ajoitusta, pinta-alaa, synteesikelpoisuutta.
//
// SKOOPIN RAJAUS (tietoinen): yksi NTT-taso, COUNT butterflya per lane,
// KAIKKI saman lanen butterflyt kayttavat samaa zeta-arvoa (tw_window[0]).
// Molemmat lanet pakotettu bankkiin 0 konfliktin pakottamiseksi.
// Ei toteuta: monivaiheista NTT-aikataulutinta eika per-butterfly-zeta-
// indeksointia (M2-tyon laajuus, ei talla).

`timescale 1ns/1ps

module lane_fsm #(
    parameter int COEFF_W = 16,
    parameter int SPAD_AW = 15,
    parameter int Q       = 3329,
    parameter int QINV    = 62209
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [SPAD_AW-1:0] base_addr,
    input  logic [7:0] stride,
    input  logic [7:0] count,

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
    output logic done
);

  localparam logic [2:0]
    S_IDLE      = 3'd0,
    S_REQ_READ  = 3'd1,
    S_COMPUTE   = 3'd2,
    S_REQ_WRITE = 3'd3,
    S_DONE      = 3'd4;

  logic [7:0] idx;
  logic [COEFF_W-1:0] a_reg, b_reg;
  logic [COEFF_W-1:0] ap_reg, bp_reg;

  assign mem_addr_a  = base_addr + idx * stride;
  assign mem_addr_b  = mem_addr_a + 1;
  assign mem_wdata_a = ap_reg;
  assign mem_wdata_b = bp_reg;

  function automatic [COEFF_W-1:0] montgomery_reduce(input int unsigned a);
    int unsigned u, t;
    begin
      u = (a & 16'hFFFF) * QINV;
      u = u & 16'hFFFF;
      t = (a + u * Q) >> 16;
      if (t >= Q) t = t - Q;
      montgomery_reduce = t[COEFF_W-1:0];
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
            a_reg <= mem_rdata_a;
            b_reg <= mem_rdata_b;
            req   <= 1'b0;
            state <= S_COMPUTE;
          end
        end

        S_COMPUTE: begin
          ap_reg   <= mod_add(a_reg, montgomery_reduce(b_reg * zeta_in));
          bp_reg   <= mod_sub(a_reg, montgomery_reduce(b_reg * zeta_in));
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

        S_DONE: done <= 1'b1;

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule


module pqc_rvv_cluster_2lane #(
    parameter int COEFF_W   = 16,
    parameter int SPAD_AW   = 15,
    parameter int BANK_AW   = 13,
    parameter int NUM_BANKS = 4,
    parameter int NUM_LANES = 2,
    parameter int TW_WINDOW = 16
)(
    input  logic clk,
    input  logic reset,

    input  logic start,
    input  logic [7:0] stage_id,
    input  logic [SPAD_AW-1:0] base_addr_lane0,
    input  logic [SPAD_AW-1:0] base_addr_lane1,
    input  logic [7:0] stride,
    input  logic [7:0] count,

    input  logic tw_in_valid,
    input  logic [$clog2(TW_WINDOW)-1:0] tw_in_idx,
    input  logic [COEFF_W-1:0] tw_in_data,

    output logic cluster_done,
    output logic cluster_error
);

  // Testipenkki lukee/kirjoittaa tata hierarkkisesti: dut.banked_mem[bank][addr]
  logic [COEFF_W-1:0] banked_mem [0:NUM_BANKS-1][0:(1<<BANK_AW)-1];

  logic [COEFF_W-1:0] tw_window [0:TW_WINDOW-1];
  always_ff @(posedge clk) begin
    if (tw_in_valid) tw_window[tw_in_idx] <= tw_in_data;
  end

  logic [SPAD_AW-1:0] addr_a0, addr_b0, addr_a1, addr_b1;
  logic [COEFF_W-1:0] rdata_a0, rdata_b0, rdata_a1, rdata_b1;
  logic [COEFF_W-1:0] wdata_a0, wdata_b0, wdata_a1, wdata_b1;
  logic req0, req1, is_write0, is_write1, grant0, grant1;
  logic [2:0] state0_w, state1_w;
  logic done0, done1;

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) lane0 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane0), .stride(stride), .count(count),
    .mem_addr_a(addr_a0), .mem_addr_b(addr_b0),
    .mem_rdata_a(rdata_a0), .mem_rdata_b(rdata_b0),
    .mem_wdata_a(wdata_a0), .mem_wdata_b(wdata_b0),
    .zeta_in(tw_window[0]),
    .req(req0), .is_write(is_write0), .grant(grant0),
    .state(state0_w), .done(done0)
  );

  lane_fsm #(.COEFF_W(COEFF_W), .SPAD_AW(SPAD_AW)) lane1 (
    .clk(clk), .reset(reset), .start(start),
    .base_addr(base_addr_lane1), .stride(stride), .count(count),
    .mem_addr_a(addr_a1), .mem_addr_b(addr_b1),
    .mem_rdata_a(rdata_a1), .mem_rdata_b(rdata_b1),
    .mem_wdata_a(wdata_a1), .mem_wdata_b(wdata_b1),
    .zeta_in(tw_window[0]),
    .req(req1), .is_write(is_write1), .grant(grant1),
    .state(state1_w), .done(done1)
  );

  // ---- Round-robin arbiter bankille 0 ----
  logic rr_priority_lane;
  always_comb begin
    grant0 = 1'b0;
    grant1 = 1'b0;
    if (req0 && req1) begin
      if (rr_priority_lane == 1'b0) grant0 = 1'b1;
      else                          grant1 = 1'b1;
    end else if (req0) begin
      grant0 = 1'b1;
    end else if (req1) begin
      grant1 = 1'b1;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) rr_priority_lane <= 1'b0;
    else if (req0 && req1) rr_priority_lane <= ~rr_priority_lane;
  end

  assign rdata_a0 = banked_mem[0][addr_a0];
  assign rdata_b0 = banked_mem[0][addr_b0];
  assign rdata_a1 = banked_mem[0][addr_a1];
  assign rdata_b1 = banked_mem[0][addr_b1];

  always_ff @(posedge clk) begin
    if (grant0 && is_write0) begin
      banked_mem[0][addr_a0] <= wdata_a0;
      banked_mem[0][addr_b0] <= wdata_b0;
    end
    if (grant1 && is_write1) begin
      banked_mem[0][addr_a1] <= wdata_a1;
      banked_mem[0][addr_b1] <= wdata_b1;
    end
  end

  // ---- Testipenkin odottamat nakyvyyssignaalit ----
  logic [1:0] req_rd   [0:NUM_BANKS-1];
  logic [1:0] grant_rd [0:NUM_BANKS-1];
  logic [1:0] stall_rd;
  assign req_rd[0]   = {req1, req0};
  assign req_rd[1]   = 2'b00;
  assign req_rd[2]   = 2'b00;
  assign req_rd[3]   = 2'b00;
  assign grant_rd[0] = {grant1, grant0};
  assign grant_rd[1] = 2'b00;
  assign grant_rd[2] = 2'b00;
  assign grant_rd[3] = 2'b00;
  assign stall_rd    = {req1 && !grant1, req0 && !grant0};

  assign cluster_done  = done0 && done1;
  assign cluster_error = 1'b0;

endmodule
