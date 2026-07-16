module pqc_ntt_wrapper_1stage (
    input  logic clk, reset, start,
    input  logic [7:0] count, pair_dist,
    input  logic mode,
    input  logic [8:0] base_addr_lane0, base_addr_lane1,
    input  logic [15:0] zeta_lane0, zeta_lane1,
    input  logic load_valid,
    input  logic [7:0] load_addr,
    input  logic [15:0] load_data,
    input  logic read_en,
    input  logic [7:0] read_addr,
    output logic stage_done_reg,
    output logic bank_conflict_sticky,
    output logic [15:0] read_data_reg,
    output logic read_valid_reg
);
  logic stage_done, bank_conflict_detected;
  logic [15:0] read_data;
  logic read_valid;

  pqc_ntt_stage_banked_1stage #(.NTT_READ_LATENCY(1), .FPGA_BRINGUP(1)) core (
    .clk(clk), .reset(reset), .start(start), .count(count),
    .pair_dist(pair_dist), .mode(mode),
    .base_addr_lane0(base_addr_lane0), .base_addr_lane1(base_addr_lane1),
    .zeta_lane0(zeta_lane0), .zeta_lane1(zeta_lane1),
    .stage_done(stage_done), .bank_conflict_detected(bank_conflict_detected),
    .load_valid(load_valid), .load_addr(load_addr), .load_data(load_data),
    .read_en(read_en), .read_addr(read_addr), .read_valid(read_valid), .read_data(read_data)
  );

  always_ff @(posedge clk) begin
    stage_done_reg <= stage_done;
    bank_conflict_sticky <= bank_conflict_sticky | bank_conflict_detected;
    read_data_reg <= read_data;
    read_valid_reg <= read_valid;
  end
endmodule
