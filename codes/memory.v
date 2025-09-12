module memory #(
    parameter MAX_ITEMS = 1024
)(
    input  wire                        clk,
    input  wire                        write_en,               // Write enable
    input  wire [$clog2(MAX_ITEMS)-1:0] waddr,           // Write address
  input  wire [15:0]                 item_price,       // Lower 16 bits
    input  wire [7:0]                  avail_count,      // Bits [23:16]
    input  wire [$clog2(MAX_ITEMS)-1:0] read_addr,           // Read address
    output reg  [15:0]                 rd_item_price,
    output reg  [7:0]                  rd_avail_count
);

   
    reg [31:0] mem [0:MAX_ITEMS-1];

    // Write 
    always @(posedge clk) begin
        if (write_en) begin
            mem[waddr] <= {8'd0, avail_count, item_price};  // Bits [31:24]=0, [23:16]=avail_count, [15:0]=item_price
        end
    end

    // Read 
    always @(posedge clk) begin
        rd_item_price  <= mem[read_addr][15:0];
        rd_avail_count <= mem[read_addr][23:16];
    end

endmodule