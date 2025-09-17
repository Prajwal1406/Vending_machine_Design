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

    input  wire        cfg_mode,  
    
    output reg         mem_apb_en,
    output reg         mem_apb_we,
    output reg [9:0]   mem_apb_addr,
    output reg [31:0]  mem_apb_wdata,
    input  wire [31:0] mem_apb_rdata,
    input  wire        mem_apb_ready
);

    reg [9:0]  no_of_items_reg;
    reg [1:0]  apb_state;
    
    localparam APB_IDLE   = 2'b00;
    localparam APB_ACCESS = 2'b10;

    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            apb_state       <= APB_IDLE;
            pready          <= 1'b0;
            prdata          <= 32'b0;
            no_of_items_reg <= 10'b0;
            mem_apb_en      <= 1'b0;
            mem_apb_we      <= 1'b0;
            mem_apb_addr    <= 10'b0;
            mem_apb_wdata   <= 32'b0;
        end else begin
            // Default assignments
            mem_apb_en <= 1'b0;
            mem_apb_we <= 1'b0;
            
            case (apb_state)
                APB_IDLE: begin
                    pready <= 1'b0;
                    if (psel) begin
                        apb_state <= APB_ACCESS;
                    end
                end
                
                APB_ACCESS: begin
                    if (psel) begin
                        if (paddr == 15'h0000) begin
                            if (pwrite) begin
                                no_of_items_reg <= pwdata[9:0];
                            end else begin
                                prdata <= {22'b0, no_of_items_reg};
                            end
                            pready <= 1'b1;
                            
                        end else begin
                            mem_apb_en   <= 1'b1;
                            mem_apb_we   <= pwrite;
                            mem_apb_addr <= (paddr >> 2) - 1; 
                            mem_apb_wdata<= pwdata;
                            
                            if (mem_apb_ready) begin
                                prdata <= mem_apb_rdata;
                                pready <= 1'b1;
                            end else begin
                                pready <= 1'b0;
                            end
                        end
                    end
                    
                    if (pready) begin
                        apb_state <= APB_IDLE;
                    end
                end
                
                default: begin
                    apb_state <= APB_IDLE;
                end
            endcase
        end
    end

endmodule
