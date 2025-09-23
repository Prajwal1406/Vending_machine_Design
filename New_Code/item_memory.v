module item_memory #(
    parameter MAX_ITEMS = 1024,
    parameter ADDR_WIDTH = 10    // log2(MAX_ITEMS)
)(
    // Single clock domain (100MHz FSM clock)
    input  wire                    clk_fsm,
    input  wire                    rstn,
    
    // FSM Interface - UNCHANGED signal names
    input  wire                    fsm_read_en,
    input  wire [ADDR_WIDTH-1:0]   fsm_read_addr,
    output reg  [15:0]             fsm_item_cost,
    output reg  [7:0]              fsm_item_available,
    output reg                     fsm_data_valid,
    
    input  wire                    fsm_update_en,
    input  wire [ADDR_WIDTH-1:0]   fsm_update_addr,
    
    // Configuration Interface - NEW for APB CDC connection
    input  wire                    cfg_read_en,
    input  wire [ADDR_WIDTH-1:0]   cfg_read_addr,
    output reg  [31:0]             cfg_read_data,
    output reg                     cfg_read_valid,
    
    input  wire                    cfg_write_en,
    input  wire [ADDR_WIDTH-1:0]   cfg_write_addr,
    input  wire [31:0]             cfg_write_data
);

    // Memory array - same format as before
    reg [31:0] item_memory [0:MAX_ITEMS-1];
    
    // Initialize memory to prevent X states
//    integer i;
//    initial begin
//        for (i = 0; i < MAX_ITEMS; i = i + 1) begin
//            item_memory[i] = 32'h0000_0000;
//        end
//    end

    // Single clock domain logic
    always @(posedge clk_fsm or negedge rstn) begin
        if (!rstn) begin
            // FSM outputs
            fsm_item_cost      <= 16'b0;
            fsm_item_available <= 8'b0;
            fsm_data_valid     <= 1'b0;
            // Config outputs
            cfg_read_data      <= 32'b0;
            cfg_read_valid     <= 1'b0;
        end else begin
            // Default values
            fsm_data_valid <= 1'b0;
            cfg_read_valid <= 1'b0;
            
            // FSM read operation (unchanged logic)
            if (fsm_read_en) begin
                fsm_item_cost      <= item_memory[fsm_read_addr][15:0];   // Cost
                fsm_item_available <= item_memory[fsm_read_addr][23:16];  // Available count
                fsm_data_valid     <= 1'b1;
            end
            
            // FSM update operation (unchanged logic)
            if (fsm_update_en) begin
                item_memory[fsm_update_addr][31:24] <= item_memory[fsm_update_addr][31:24] + 1; // Dispensed count++
                item_memory[fsm_update_addr][23:16] <= item_memory[fsm_update_addr][23:16] - 1; // Available count--
            end
            
            // Configuration read operation (for APB CDC)
            if (cfg_read_en) begin
                cfg_read_data  <= item_memory[cfg_read_addr];
                cfg_read_valid <= 1'b1;
            end
            
            // Configuration write operation (for APB CDC)
            if (cfg_write_en) begin
                item_memory[cfg_write_addr] <= cfg_write_data;
            end
        end
    end

endmodule
