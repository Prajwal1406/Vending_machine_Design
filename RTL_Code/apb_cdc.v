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
    reg [31:0] no_of_items_reg;

    // APB domain registers 
    reg        slow_mem_req;         
    reg        slow_write_op;        
    reg [9:0]  slow_mem_addr;        
    reg [31:0] slow_mem_wdata;       
    reg [31:0] slow_mem_rdata;       

    // Fast domain registers 
    reg        fast_mem_done;        
    reg [31:0] fast_mem_rdata;       
    reg        fast_write_op;        
    reg [9:0]  fast_mem_addr;        
    reg [31:0] fast_mem_wdata;       

    reg [1:0]  req_sync;             
    reg [1:0]  done_sync;            

    // APB Domain Logic (50MHz)
    always @(posedge clk_apb or negedge rstn) begin
        if (!rstn) begin
            prdata           <= 32'b0;
            pready           <= 1'b0;
            no_of_items_reg  <= 10'b0;
            slow_mem_req     <= 1'b0;
            slow_write_op    <= 1'b0;
            slow_mem_addr    <= 10'b0;
            slow_mem_wdata   <= 32'b0;
            slow_mem_rdata   <= 32'b0;
            done_sync        <= 2'b0;
        end else begin
            // Synchronize done signal from fast domain
            done_sync <= {done_sync[0], fast_mem_done};

            // Default: clear pready unless we're completing a transaction
            pready <= 1'b0;

            // APB transaction logic
            if (psel && !pready && !slow_mem_req) begin
                // Address 0x0000: Local item count register (no CDC needed)
                if (paddr == 15'h0000) begin
                    if (pwrite) begin
                        no_of_items_reg <= pwdata[31:0];
                    end else begin
                        prdata <= no_of_items_reg;
                    end
                    pready <= 1'b1;
                end
                else begin
                    slow_mem_req   <= 1'b1;
                    slow_write_op  <= pwrite;
                    slow_mem_addr  <= (paddr >> 2) - 1;
                    slow_mem_wdata <= pwdata;
                end
            end
            else if (slow_mem_req && done_sync[1]) begin
                prdata       <= slow_mem_rdata;
                pready       <= 1'b1;
                slow_mem_req <= 1'b0;
            end
            
            if (done_sync == 2'b01) begin  // Rising edge of done
                slow_mem_rdata <= fast_mem_rdata;
            end
        end
    end

    // Fast Domain Logic (100MHz)
    always @(posedge clk_fsm or negedge rstn) begin
        if (!rstn) begin
            cfg_read_en      <= 1'b0;
            cfg_read_addr    <= 10'b0;
            cfg_write_en     <= 1'b0;
            cfg_write_addr   <= 10'b0;
            cfg_write_data   <= 32'b0;
            fast_mem_done    <= 1'b0;
            fast_mem_rdata   <= 32'b0;
            fast_write_op    <= 1'b0;
            fast_mem_addr    <= 10'b0;
            fast_mem_wdata   <= 32'b0;
            req_sync         <= 2'b0;
        end else begin
            req_sync <= {req_sync[0], slow_mem_req};

            cfg_read_en  <= 1'b0;
            cfg_write_en <= 1'b0;

            
            if (req_sync == 2'b01) begin // Detect new transaction (rising edge)
                fast_mem_done  <= 1'b0;
                fast_write_op  <= slow_write_op;
                fast_mem_addr  <= slow_mem_addr;
                fast_mem_wdata <= slow_mem_wdata;
                
                if (slow_write_op) begin
                    // Write operation
                    cfg_write_en   <= 1'b1;
                    cfg_write_addr <= slow_mem_addr;
                    cfg_write_data <= slow_mem_wdata;
                end else begin
                    // Read operation
                    cfg_read_en   <= 1'b1;
                    cfg_read_addr <= slow_mem_addr;
                end
            end
            else if (req_sync == 2'b11 && fast_write_op) begin
                fast_mem_done <= 1'b1; // Write completed immediately
            end
            else if (cfg_read_valid) begin
                fast_mem_rdata <= cfg_read_data;
                fast_mem_done  <= 1'b1;
            end
            else if (req_sync == 2'b00) begin
                fast_mem_done <= 1'b0;
            end
        end
    end

endmodule