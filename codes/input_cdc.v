module pulse_sync (
    input  wire clk_dst,
    input  wire rstn,
    input  wire async_pulse,   // from input block (10-50 MHz, async)
    output reg  sync_pulse     // 1-cycle pulse in clk_dst domain
);

    reg [1:0] sync_ff;

    always @(posedge clk_dst or negedge rstn) begin
        if (!rstn) begin
            sync_ff   <= 2'b0;
            sync_pulse <= 1'b0;
        end else begin
            sync_ff   <= {sync_ff[0], async_pulse};
            sync_pulse <= sync_ff[0] & ~sync_ff[1]; // detect rising edge
        end
    end

endmodule

module input_cdc (
    input  wire clk_fsm,
    input  wire rstn,

    // Async inputs (from input block, any freq)
    input  wire        currency_valid_async,
    input  wire [7:0]  currency_value_async,
    input  wire        item_select_valid_async,
    input  wire [9:0]  item_select_async,

    // Synchronized outputs (FSM domain)
    output reg         currency_valid_sync,
    output reg [7:0]   currency_value_sync,
    output reg         item_select_valid_sync,
    output reg [9:0]   item_select_sync
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
