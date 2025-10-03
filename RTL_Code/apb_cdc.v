module apb_cdc #(
    parameter MAX_ITEMS = 1024,
    parameter ADDR_WIDTH = 10
)(
    // APB Interface (50MHz domain)
    input  wire        clk_apb,      
    input  wire        rstn,         
    input  wire [14:0] paddr,        
    input  wire        psel,         
    input  wire        pwrite,       
    input  wire [31:0] pwdata,       
    input  wire        cfg_mode,     
    output reg  [31:0] prdata,       
    output reg         pready,       

    // Memory Interface (100MHz domain)  
    input  wire        clk_fsm,      
    output reg         cfg_read_en,  
    output reg  [$clog2(MAX_ITEMS)-1:0]  cfg_read_addr,
    input  wire [31:0] cfg_read_data,
    input  wire        cfg_read_valid,
    
    output reg         cfg_write_en, 
    output reg  [$clog2(MAX_ITEMS)-1:0]  cfg_write_addr,
    output reg  [31:0] cfg_write_data
);

    // Local item count register (APB domain only)
    reg [9:0] no_of_items_reg;
  	reg valid_data;

    // APB domain registers - Clear naming
    reg        apb_start_transaction;     // APB starts a transaction
    reg        apb_is_write;             // Type of transaction  
    reg [9:0]  apb_addr;                 // Address from APB
    reg [31:0] apb_wdata;                // Write data from APB
    reg [31:0] apb_rdata;                // Read data for APB

    // FSM domain registers - Clear naming  
    reg        fsm_transaction_done;     // FSM finished the work
    reg [31:0] fsm_rdata;               // Data FSM read from memory

    // Synchronizers - Shorter, clearer names
    reg [1:0]  start_sync;              // Synchronize start signal APB->FSM
    reg [1:0]  done_sync;               // Synchronize done signal FSM->APB

    //=====================================
    // APB Domain Logic (50MHz)
    //=====================================
    always @(posedge clk_apb or negedge rstn) begin
        if (!rstn) begin
            prdata                <= 32'b0;
            pready                <= 1'b0;
            no_of_items_reg       <= 10'b0;
            apb_start_transaction <= 1'b0;
            apb_is_write          <= 1'b0;
            apb_addr              <= 10'b0;
            apb_wdata             <= 32'b0;
            apb_rdata             <= 32'b0;
            done_sync             <= 2'b0;
        end else begin
            // Synchronize done signal from FSM domain
            done_sync <= {done_sync[0], fsm_transaction_done};

            // APB transaction logic
            if (psel && !pready) begin
                // Address 0x0000: Local item count register (no CDC needed)
                if (paddr == 15'h0000) begin
                    if (pwrite) begin
                        no_of_items_reg <= pwdata[9:0];
                    end else begin
                        prdata <= {22'b0, no_of_items_reg};
                    end
                    pready <= 1'b1;
                end
                // Other addresses: Memory access via CDC
                else if (!apb_start_transaction) begin
                    // Start cross-domain transaction
                    apb_start_transaction <= 1'b1;
                    apb_is_write          <= pwrite;
                    apb_addr              <= (paddr >> 2) - 1;
                    apb_wdata             <= pwdata;
                end
                // Wait for done from FSM domain
                else if (done_sync[1]) begin
                    // Transaction complete
                    prdata                <= apb_rdata;
                    pready                <= 1'b1;
                    apb_start_transaction <= 1'b0;
                end else begin
                  pready <= 1'b0;
                end
            end else begin
                // Clear pready when transaction ends
                pready <= 1'b0;
            end
        end
    end

    //=====================================
    // FSM Domain Logic (100MHz)
    //=====================================
    always @(posedge clk_fsm or negedge rstn) begin
        if (!rstn) begin
            cfg_read_en           <= 1'b0;
            cfg_read_addr         <= 10'b0;
            cfg_write_en          <= 1'b0;
            cfg_write_addr        <= 10'b0;
            cfg_write_data        <= 32'b0;
            fsm_transaction_done  <= 1'b0;
            fsm_rdata             <= 32'b0;
            start_sync            <= 2'b0;
        end else begin
            // Synchronize start signal from APB domain
            start_sync <= {start_sync[0], apb_start_transaction};

            // Default values
            cfg_read_en  <= 1'b0;
            cfg_write_en <= 1'b0;

            // Detect new transaction (rising edge)
            if (start_sync == 2'b01) begin
                // New transaction arrived - start memory operation
                fsm_transaction_done <= 1'b0;
                
                if (apb_is_write) begin
                    // Write operation
                    cfg_write_en   <= 1'b1;
                    cfg_write_addr <= apb_addr;
                    cfg_write_data <= apb_wdata;
                    // For writes, signal done immediately
                    fsm_transaction_done <= 1'b1;
                end else begin
                    // Read operation
                    cfg_read_en   <= 1'b1;
                    cfg_read_addr <= apb_addr;
                end
            end
            // For reads, signal done when data is valid
            else if (cfg_read_valid) begin
                fsm_rdata            <= cfg_read_data;
                apb_rdata            <= cfg_read_data;  // Cross to APB domain
                fsm_transaction_done <= 1'b1;
            end
            // Clear done when start goes away (transaction cleanup)
            else if (start_sync == 2'b00) begin
                fsm_transaction_done <= 1'b0;
            end
        end
    end

endmodule
