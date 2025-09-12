module item_select #(
parameter ITEM_ADDR_WIDTH =10 
)
(
input  wire clk,       
input wire rstn,       
input wire [ITEM_ADDR_WIDTH-1:0] item_select,  
input wire item_select_valid,      
output reg [ITEM_ADDR_WIDTH-1:0] item_selected,  
output reg selection_valid   
);
always @(posedge clk or negedge rstn) 
   begin
        if (!rstn) 
        begin
           item_selected <= 0;
            selection_valid <= 0;
        end 
        else begin
            if (item_select_valid)begin    
                item_selected <= item_select;
                selection_valid <= 1;
            end 
            else begin     
                selection_valid <= 0;
            end
        end
    end
endmodule