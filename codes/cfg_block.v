// cfg_block.v — key parts only (replace or merge into your file)
module cfg_block #(
    parameter MAX_ITEMS = 1024
)(
    input  wire        pclk,
    input  wire        prstn,
    input  wire [14:0] paddr,
    input  wire        psel,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pready,

    // Main FSM Interface (APB-side control from cdc_wrapper)
    input  wire        cfg_mode,
    input  wire        cfg_item_read_req,   // from cdc_wrapper (APB domain)
    input  wire        cfg_item_update_req, // from cdc_wrapper (APB domain)
    input  wire [9:0]  cfg_item_id,         // APB-side id
    output reg  [15:0] item_cost,           // registered on APB side
    output reg  [7:0]  item_available,      // registered on APB side

    // CDC helper
    output reg         data_valid_apb
);

    reg [31:0] Item_cfg [0:MAX_ITEMS-1];
    reg [9:0]  no_of_items_reg;
    reg [1:0]  apb_state;
    localparam APB_IDLE   = 2'b00;
    localparam APB_ACCESS = 2'b10;

    // APB state machine (write/read via APB master)
    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            apb_state      <= APB_IDLE;
            pready         <= 1'b0;
            prdata         <= 32'b0;
            no_of_items_reg<= 10'b0;
        end else begin
            data_valid_apb <= 1'b0; // default low
            case (apb_state)
                APB_IDLE: begin
                    pready <= 1'b0;
                    if (psel) begin
                        apb_state <= APB_ACCESS;
                    end
                end
                APB_ACCESS: begin
                    pready <= 1'b1; // ready for one cycle
                    if (psel) begin
                        if (pwrite) begin
                            if (paddr == 15'h0000) begin
                                no_of_items_reg <= pwdata[9:0];
                            end else begin
                                Item_cfg[paddr >> 2] <= pwdata;
                            end
                        end else begin
                            if (paddr == 15'h0000) begin
                                prdata <= {22'b0, no_of_items_reg};
                            end else begin
                                prdata <= Item_cfg[paddr >> 2];
                                // If you want APB reads to also show a data_valid pulse:
                                data_valid_apb <= 1'b1;
                            end
                        end
                    end
                    apb_state <= APB_IDLE;
                end
            endcase
        end
    end

    // Provide APB-side registered item fields when FSM asks (cfg_item_read_req)
    // This is the addition — when APB-domain wrapper requests the current cfg_item_id,
    // we latch the fields and pulse data_valid_apb.
    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            item_cost       <= 16'b0;
            item_available  <= 8'b0;
            // data_valid_apb <= 1'b0; // already handled above
        end else begin
            // default: no new data_valid unless set by APB ACCESS or read request
            if (cfg_item_read_req) begin
                item_cost      <= Item_cfg[cfg_item_id][15:0];
                item_available <= Item_cfg[cfg_item_id][23:16];
                data_valid_apb <= 1'b1; // pulse to notify CDC wrapper that APB data are stable
            end
            // FSM updates (operation mode) — update memory
            if (!cfg_mode) begin
                if (cfg_item_update_req) begin
                    Item_cfg[cfg_item_id][31:24] <= Item_cfg[cfg_item_id][31:24] + 1;
                    Item_cfg[cfg_item_id][23:16] <= Item_cfg[cfg_item_id][23:16] - 1;
                end
            end
        end
    end

endmodule
