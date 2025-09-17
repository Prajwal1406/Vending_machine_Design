module vending_top (
    input  wire clk_fsm,
    input  wire clk_apb,
    input  wire rstn,

    input  wire        currency_valid_async,
    input  wire [7:0]  currency_value_async,
    input  wire        item_select_valid_async,
    input  wire [9:0]  item_select_async,

    input  wire [14:0] paddr,
    input  wire        psel,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    input  wire        cfg_mode,
    output wire [31:0] prdata,
    output wire        pready,

    output wire        item_dispense_valid,
    output wire [9:0]  item_dispense,
    output wire [7:0]  currency_change
);

    wire currency_valid_sync;
    wire [7:0] currency_value_sync;
    wire item_select_valid_sync;
    wire [9:0] item_select_sync;

    wire        fsm_mem_read_en;
    wire [9:0]  fsm_mem_read_addr;
    wire [15:0] fsm_mem_item_cost;
    wire [7:0]  fsm_mem_item_available;
    wire        fsm_mem_data_valid;
    wire        fsm_mem_update_en;
    wire [9:0]  fsm_mem_update_addr;

    wire        cfg_mem_apb_en;
    wire        cfg_mem_apb_we;
    wire [9:0]  cfg_mem_apb_addr;
    wire [31:0] cfg_mem_apb_wdata;
    wire [31:0] cfg_mem_apb_rdata;
    wire        cfg_mem_apb_ready;


    input_cdc u_input_cdc (
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

    main_fsm u_fsm (
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

    item_memory #(
        .MAX_ITEMS(1024),
        .ADDR_WIDTH(10)
    ) u_item_memory (
        .clk_fsm(clk_fsm),
        .rstn(rstn),
        .fsm_read_en(fsm_mem_read_en),
        .fsm_read_addr(fsm_mem_read_addr),
        .fsm_item_cost(fsm_mem_item_cost),
        .fsm_item_available(fsm_mem_item_available),
        .fsm_data_valid(fsm_mem_data_valid),
        .fsm_update_en(fsm_mem_update_en),
        .fsm_update_addr(fsm_mem_update_addr),
        .clk_apb(clk_apb),
        .apb_en(cfg_mem_apb_en),
        .apb_we(cfg_mem_apb_we),
        .apb_addr(cfg_mem_apb_addr),
        .apb_wdata(cfg_mem_apb_wdata),
        .apb_rdata(cfg_mem_apb_rdata),
        .apb_ready(cfg_mem_apb_ready)
    );

    cfg_block u_cfg (
        .pclk(clk_apb),
        .prstn(rstn),
        .paddr(paddr),
        .psel(psel),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .cfg_mode(cfg_mode),
        .mem_apb_en(cfg_mem_apb_en),
        .mem_apb_we(cfg_mem_apb_we),
        .mem_apb_addr(cfg_mem_apb_addr),
        .mem_apb_wdata(cfg_mem_apb_wdata),
        .mem_apb_rdata(cfg_mem_apb_rdata),
        .mem_apb_ready(cfg_mem_apb_ready)
    );
    
endmodule
