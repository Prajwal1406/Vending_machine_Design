module cfg_block #(
    parameter MAX_ITEMS = 1024
)(
    // APB Interface
    input wire pclk,
    input wire prstn,
    input wire [14:0] paddr,
    input wire psel,
    input wire pwrite,
    input wire [31:0] pwdata,
    output reg [31:0] prdata,
    output reg pready,
    
    // Main FSM Interface
    input wire cfg_mode, // From top-level
    input wire cfg_item_read_req,
    input wire cfg_item_update_req,
    input wire [9:0] cfg_item_id,
    output wire [15:0] item_cost,
    output wire [7:0] item_available
);

    // Internal Memory for Item Configuration
    reg [31:0] Item_cfg [0:MAX_ITEMS-1];
    
    // Register to store the number of valid items loaded
    reg [9:0] no_of_items_reg;
    
    // Split the Item_cfg fields for easy access
    assign item_cost = Item_cfg[cfg_item_id][15:0];
    assign item_available = Item_cfg[cfg_item_id][23:16];

    // APB State Machine
    reg [1:0] apb_state;
    localparam APB_IDLE = 2'b00;
    localparam APB_SETUP = 2'b01;
    localparam APB_ACCESS = 2'b10;
    
    // APB Logic
    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            apb_state <= APB_IDLE;
            pready <= 1'b0;
            prdata <= 32'b0;
        end else begin
            case(apb_state)
                APB_IDLE: begin
                    if (psel) begin
                        apb_state <= APB_ACCESS;
                        pready <= 1'b1;
                    end
                end
                APB_ACCESS: begin
                    if (psel) begin
                        // APB WRITE Transaction
                        if (pwrite) begin
                            // Check for the main config register
                            if (paddr == 15'h0000) begin
                                no_of_items_reg <= pwdata[9:0];
                            end else begin
                                // APB WRITE to Item_cfg memory
                                Item_cfg[paddr >> 2] <= pwdata;
                            end
                        end else begin
                            // APB READ Transaction
                            if (paddr == 15'h0000) begin
                                prdata <= {22'b0, no_of_items_reg};
                            end else begin
                                prdata <= Item_cfg[paddr >> 2];
                            end
                        end
                    end
                    apb_state <= APB_IDLE;
                    pready <= 1'b0;
                end
            endcase
        end
    end

    // FSM Access Logic
    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            // Reset logic
        end else if (!cfg_mode) begin
            // Only allow FSM access in Operation Mode
            if (cfg_item_update_req) begin
                // Update the dispensed items and decrement available items
                Item_cfg[cfg_item_id][31:24] <= Item_cfg[cfg_item_id][31:24] + 1;
                Item_cfg[cfg_item_id][23:16] <= Item_cfg[cfg_item_id][23:16] - 1;
            end
        end
    end
endmodule