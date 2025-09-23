module vending_top #(
    parameter MAX_ITEMS   = 1024,
    parameter MAX_NOTE_VAL = 100
)(
    input  wire clk_fsm,
    input  wire clk_apb,
    input  wire rstn,

    // Async user inputs
    input  wire        currency_valid_async,
    input  wire [$clog2(MAX_NOTE_VAL):0]  currency_value_async,
    input  wire        item_select_valid_async,
    input  wire [$clog2(MAX_ITEMS)-1:0]  item_select_async,

    // APB interface
    input  wire [14:0] paddr,
    input  wire        psel,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    input  wire        cfg_mode,
    output wire [31:0] prdata,
    output wire        pready,

    // FSM outputs
    output wire        item_dispense_valid,
    output wire [$clog2(MAX_ITEMS)-1:0]  item_dispense,
    output wire [7:0]  currency_change
);

    // Input CDC wires
    wire currency_valid_sync;
    wire [$clog2(MAX_NOTE_VAL):0] currency_value_sync;
    wire item_select_valid_sync;
    wire [$clog2(MAX_ITEMS)-1:0] item_select_sync;

    // FSM <-> Memory wires
    wire        fsm_mem_read_en;
    wire [$clog2(MAX_ITEMS)-1:0] fsm_mem_read_addr;
    wire [15:0] fsm_mem_item_cost;
    wire [7:0]  fsm_mem_item_available;
    wire        fsm_mem_data_valid;
    wire        fsm_mem_update_en;
    wire [$clog2(MAX_ITEMS)-1:0] fsm_mem_update_addr;

    // APB CDC <-> Memory wires
    wire        cfg_mem_read_en;
    wire [$clog2(MAX_ITEMS)-1:0] cfg_mem_read_addr;
    wire [31:0] cfg_mem_read_data;
    wire        cfg_mem_read_valid;
    wire        cfg_mem_write_en;
    wire [$clog2(MAX_ITEMS)-1:0] cfg_mem_write_addr;
    wire [31:0] cfg_mem_write_data;

    // Async input CDC
    input_cdc #(
        .MAX_ITEMS(MAX_ITEMS),
      	.MAX_NOTE_VAL(MAX_NOTE_VAL)
    )u_input_cdc (
        .clk_fsm(clk_fsm),
        .rstn(rstn),
        .currency_valid_async(currency_valid_async),
        .currency_value_async(currency_value_async),
        .item_select_valid_async(item_select_valid_async),
        .item_select_async(item_select_async),
        .currency_valid_sync(currency_valid_sync),
        .currency_value_sync(currency_value_sync),
        .item_select_valid_sync(item_select_valid_sync),
        .item_select_sync(item_select_sync)
    );

    // Main FSM
  main_fsm #(
   .MAX_ITEMS(MAX_ITEMS),
   .MAX_NOTE_VAL(MAX_NOTE_VAL)
  )u_fsm (
        .clk(clk_fsm),
        .rstn(rstn),
        .cfg_mode(cfg_mode),
        .sync_currency_valid(currency_valid_sync),
        .sync_currency_value(currency_value_sync),
        .sync_item_select_valid(item_select_valid_sync),
        .sync_item_select(item_select_sync),
        .mem_read_en(fsm_mem_read_en),
        .mem_read_addr(fsm_mem_read_addr),
        .mem_item_cost(fsm_mem_item_cost),
        .mem_item_available(fsm_mem_item_available),
        .mem_data_valid(fsm_mem_data_valid),
        .mem_update_en(fsm_mem_update_en),
        .mem_update_addr(fsm_mem_update_addr),
        .item_dispense_valid(item_dispense_valid),
        .item_dispense(item_dispense),
        .currency_change(currency_change)
    );

    // Item memory (single clock domain)
    item_memory #(
        .MAX_ITEMS(MAX_ITEMS),
        .ADDR_WIDTH($clog2(MAX_ITEMS))
    ) u_item_memory (
        .clk_fsm(clk_fsm),
        .rstn(rstn),

        // FSM interface
        .fsm_read_en(fsm_mem_read_en),
        .fsm_read_addr(fsm_mem_read_addr),
        .fsm_item_cost(fsm_mem_item_cost),
        .fsm_item_available(fsm_mem_item_available),
        .fsm_data_valid(fsm_mem_data_valid),
        .fsm_update_en(fsm_mem_update_en),
        .fsm_update_addr(fsm_mem_update_addr),

        // Config (APB CDC) interface
        .cfg_read_en(cfg_mem_read_en),
        .cfg_read_addr(cfg_mem_read_addr),
        .cfg_read_data(cfg_mem_read_data),
        .cfg_read_valid(cfg_mem_read_valid),
        .cfg_write_en(cfg_mem_write_en),
        .cfg_write_addr(cfg_mem_write_addr),
        .cfg_write_data(cfg_mem_write_data)
    );

    // APB CDC bridge
    apb_cdc #(
        .MAX_ITEMS(MAX_ITEMS),
        .ADDR_WIDTH($clog2(MAX_ITEMS))
    ) u_apb_cdc (
        // APB interface (clk_apb domain)
        .clk_apb(clk_apb),
        .rstn(rstn),
        .paddr(paddr),
        .psel(psel),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .cfg_mode(cfg_mode),
        .prdata(prdata),
        .pready(pready),

        // Memory interface (clk_fsm domain)
        .clk_fsm(clk_fsm),
        .cfg_read_en(cfg_mem_read_en),
        .cfg_read_addr(cfg_mem_read_addr),
        .cfg_read_data(cfg_mem_read_data),
        .cfg_read_valid(cfg_mem_read_valid),
        .cfg_write_en(cfg_mem_write_en),
        .cfg_write_addr(cfg_mem_write_addr),
        .cfg_write_data(cfg_mem_write_data)
    );

endmodule
