module currency_val #(
    parameter CURRENCY_WIDTH = 7  //max value 127
)(
    input wire clk, //clk signal
    input wire  rstn,  //active low signal
    input wire [CURRENCY_WIDTH-1:0] currency_value, 
    input wire currency_valid,    
    output reg [CURRENCY_WIDTH-1:0] total_currency,   
    output  reg currency_avail 
);
    
    always @(posedge clk or negedge rstn) begin 
        if (!rstn) begin
            total_currency <= 0;
            currency_avail <= 0;
        end else begin
            if (rising_edge) begin
                total_currency <= total_currency + currency_value;
                currency_avail <= 1;
            end else begin
                currency_avail <= 0;
            end
        end
    end
endmodule