// M4-TAU-001: pqc_tau_audit_log -testi. Vertaa RTL:n tuottamaa
// hash-ketjua Python-referenssiin (audit_log_golden.txt), ja
// varmistaa lukurajapinnan (deferred reconciliation) toimivan.

`timescale 1ns/1ps

module pqc_tau_audit_log_tb;

  logic clk, reset;
  logic write_valid, write_busy, write_done;
  logic [255:0] decision_hash;
  logic [7:0] write_seq;
  logic [255:0] write_chain_hash;
  logic [7:0] read_seq;
  logic [255:0] read_chain_hash, read_decision_hash;
  logic read_entry_valid;
  logic [7:0] log_count;
  logic log_full;

  always #5 clk = ~clk;

  pqc_tau_audit_log #(.LOG_DEPTH(64)) dut (
    .clk(clk), .reset(reset),
    .write_valid(write_valid), .decision_hash(decision_hash),
    .write_busy(write_busy), .write_done(write_done),
    .write_seq(write_seq), .write_chain_hash(write_chain_hash),
    .read_seq(read_seq), .read_chain_hash(read_chain_hash),
    .read_decision_hash(read_decision_hash), .read_entry_valid(read_entry_valid),
    .log_count(log_count), .log_full(log_full)
  );

  logic [255:0] golden_decision_hash [0:2];
  logic [255:0] golden_chain_hash [0:2];
  int fh, scan_ok;
  string dh_hex, ch_hex;
  int error_count;

  initial begin
    error_count = 0;
    clk = 0; reset = 1; write_valid = 0; decision_hash = 0; read_seq = 0;

    // Lue Python-golden-referenssi
    fh = $fopen("fpga/tau/audit_log_golden.txt", "r");
    for (int i = 0; i < 3; i++) begin
      int seq_dummy;
      scan_ok = $fscanf(fh, "%d %h %h\n", seq_dummy, golden_decision_hash[i], golden_chain_hash[i]);
    end
    $fclose(fh);

    repeat (3) @(posedge clk);
    reset = 0;
    @(posedge clk);

    // --- Kirjoita kolme merkintaa peräkkäin ---
    for (int i = 0; i < 3; i++) begin
      decision_hash <= golden_decision_hash[i];
      write_valid <= 1'b1;
      @(posedge clk);
      write_valid <= 1'b0;
      // Odota write_done
      while (!write_done) @(posedge clk);

      if (write_chain_hash !== golden_chain_hash[i]) begin
        $display("FAIL: seq=%0d chain_hash EI TASMAA. RTL=%h golden=%h", i, write_chain_hash, golden_chain_hash[i]);
        error_count++;
      end else begin
        $display("OK: seq=%0d chain_hash tasmaa golden-referenssiin (%h)", i, write_chain_hash);
      end
      @(posedge clk);
    end

    // --- Testaa lukurajapinta (deferred reconciliation) ---
    for (int i = 0; i < 3; i++) begin
      read_seq = i[7:0];
      #1;
      if (!read_entry_valid) begin
        $display("FAIL: seq=%0d ei loydy lukurajapinnasta", i);
        error_count++;
      end else if (read_chain_hash !== golden_chain_hash[i] || read_decision_hash !== golden_decision_hash[i]) begin
        $display("FAIL: seq=%0d lukurajapinnan data ei tasmaa", i);
        error_count++;
      end else begin
        $display("OK: seq=%0d luettavissa oikein lukurajapinnasta (deferred reconciliation)", i);
      end
    end

    if (log_count !== 8'd3) begin
      $display("FAIL: log_count=%0d, odotettu 3", log_count);
      error_count++;
    end

    $display("--------------------------------------------------");
    if (error_count == 0) $display("PASS: TAU-audit-loki - hash-ketjutus + lukurajapinta toimivat oikein");
    else begin $display("FAIL: %0d virhetta", error_count); $fatal(1); end
    $display("--------------------------------------------------");
    $finish;
  end

endmodule
