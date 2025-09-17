module item_memory #(
    parameter MAX_ITEMS = 1024,
    parameter ADDR_WIDTH = 10    // log2(MAX_ITEMS)
)(

    // Port A: FSM Interface (100MHz)
    input  wire                    clk_fsm,
    input  wire                    rstn,
    
    // FSM read interface  
    input  wire                    fsm_read_en,
    input  wire [ADDR_WIDTH-1:0]   fsm_read_addr,
    output reg  [15:0]             fsm_item_cost,
    output reg  [7:0]              fsm_item_available,
    output reg                     fsm_data_valid,
    
    input  wire                    fsm_update_en,
    input  wire [ADDR_WIDTH-1:0]   fsm_update_addr,
    
    // Port B: APB Interface (50MHz)  
    input  wire                    clk_apb,
    input  wire                    apb_en,
    input  wire                    apb_we,
    input  wire [ADDR_WIDTH-1:0]   apb_addr,
    input  wire [31:0]             apb_wdata,
    output reg  [31:0]             apb_rdata,
    output reg                     apb_ready
);

    reg [31:0] item_memory [0:MAX_ITEMS-1];


    always @(posedge clk_fsm or negedge rstn) begin
        if (!rstn) begin
            fsm_item_cost      <= 16'b0;
            fsm_item_available <= 8'b0;
            fsm_data_valid     <= 1'b0;
        end else begin
            fsm_data_valid <= 1'b0; 
            if (fsm_read_en) begin
                fsm_item_cost      <= item_memory[fsm_read_addr][15:0];
                fsm_item_available <= item_memory[fsm_read_addr][23:16];
                fsm_data_valid     <= 1'b1;
            end
            if (fsm_update_en) begin
                item_memory[fsm_update_addr][31:24] <= item_memory[fsm_update_addr][31:24] + 1;
                item_memory[fsm_update_addr][23:16] <= item_memory[fsm_update_addr][23:16] - 1;
            end
        end
    end
    
    always @(posedge clk_apb or negedge rstn) begin
        if (!rstn) begin
            apb_rdata <= 32'b0;
            apb_ready <= 1'b0;
        end else begin
            apb_ready <= 1'b0; 
            if (apb_en) begin
                if (apb_we) begin
                    item_memory[apb_addr] <= apb_wdata;
                end else begin
                    apb_rdata <= item_memory[apb_addr];
                end
                apb_ready <= 1'b1;
            end
        end
    end

endmodule
