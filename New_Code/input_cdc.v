module pulse_sync #(
    parameter ADDR_WIDTH = 10// log2(MAX_ITEMS)
)(
    input  wire clk_dst,
    input  wire rstn,
    input  wire async_pulse,   // from input block (10-50 MHz, async)
    output reg  sync_pulse     // 1-cycle pulse in clk_dst domain
);

    reg sync1;
    reg sync2;

    always @(posedge clk_dst or negedge rstn) begin
        if (!rstn) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync_pulse <= 1'b0;
        end else begin
            sync1 <= async_pulse;
            sync2 <= sync1;
            sync_pulse <= sync1 & ~sync2;
        end
    end

endmodule


module input_cdc #(
	parameter MAX_NOTE_VAL = 100,
  	parameter MAX_ITEMS = 1024
) (
    input  wire clk_fsm,
    input  wire rstn,

    // Async inputs (from input block, any freq)
    input  wire        currency_valid_async,
    input  wire [$clog2(MAX_NOTE_VAL):0]  currency_value_async,
    input  wire        item_select_valid_async,
    input  wire [$clog2(MAX_ITEMS)-1:0]  item_select_async,

    // Synchronized outputs (FSM domain)
    output reg         currency_valid_sync,
    output reg [$clog2(MAX_NOTE_VAL):0]   currency_value_sync,
    output reg         item_select_valid_sync,
    output reg [$clog2(MAX_ITEMS)-1:0]   item_select_sync
);

    wire currency_pulse, item_pulse;

    // Synchronize valid pulses
    pulse_sync u1 (.clk_dst(clk_fsm), .rstn(rstn),
                   .async_pulse(currency_valid_async),
                   .sync_pulse(currency_pulse));

    pulse_sync u2 (.clk_dst(clk_fsm), .rstn(rstn),
                   .async_pulse(item_select_valid_async),
                   .sync_pulse(item_pulse));

    // Capture data safely on pulse
    always @(posedge clk_fsm or negedge rstn) begin
        if (!rstn) begin
            currency_valid_sync   <= 0;
            currency_value_sync   <= 8'b0;
            item_select_valid_sync <= 0;
            item_select_sync      <= 10'b0;
        end else begin
            currency_valid_sync   <= currency_pulse;
            item_select_valid_sync <= item_pulse;

            if (currency_pulse)
                currency_value_sync <= currency_value_async;

            if (item_pulse)
                item_select_sync <= item_select_async;
        end
    end

endmodule
