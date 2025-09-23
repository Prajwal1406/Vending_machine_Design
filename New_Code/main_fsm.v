module main_fsm #(
	parameter MAX_ITEMS = 1024,
  	parameter MAX_NOTE_VAL = 100
)(
  input wire clk,
  input wire rstn,
  input wire cfg_mode,
  input wire sync_currency_valid,
  input wire [$clog2(MAX_NOTE_VAL):0] sync_currency_value,
  input wire sync_item_select_valid,
  input wire [$clog2(MAX_ITEMS)-1:0] sync_item_select,
  
  output reg        mem_read_en,
  output reg [$clog2(MAX_ITEMS)-1:0]  mem_read_addr,
  input wire [15:0] mem_item_cost,
  input wire [7:0]  mem_item_available,
  input wire        mem_data_valid,
  
  output reg        mem_update_en,
  output reg [$clog2(MAX_ITEMS)-1:0]  mem_update_addr,
  
  output reg item_dispense_valid,
  output reg [$clog2(MAX_ITEMS)-1:0] item_dispense,
  output reg [$clog2(MAX_NOTE_VAL):0] currency_change
);
  
  localparam STATE_IDLE = 2'b00;     
  localparam STATE_WAIT_FOR_MONEY = 2'b01;
  localparam STATE_DISPENSE = 2'b10;
  localparam STATE_EMPTY = 2'b11;
 
  reg [1:0] current_state, next_state; 
  reg [15:0] current_credit;
  reg [9:0] selected_item_reg;
  
  // Latched item information registers
  reg        item_info_valid;
  reg [15:0] item_cost_reg;
  reg [7:0]  item_available_reg;
  
  // Sequential logic: state updates, latching, memory control (registered)
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin 
      current_state <= STATE_IDLE;
      current_credit <= 16'b0;
      selected_item_reg <= 10'b0;
      item_info_valid <= 1'b0;
      item_cost_reg <= 16'b0;
      item_available_reg <= 8'b0;
      mem_read_en <= 1'b0;
      mem_read_addr <= 10'b0;
      mem_update_en <= 1'b0;
      mem_update_addr <= 10'b0;
    end else begin
      current_state <= next_state;

      // default outputs each cycle
      mem_read_en <= 1'b0;
      mem_update_en <= 1'b0;
      item_dispense_valid <= 1'b0;
      item_dispense <= 10'b0;
      currency_change <= 8'b0;

      if(next_state == STATE_IDLE && current_state != STATE_IDLE) begin
        current_credit <= 16'b0;
      end
      
      if(next_state == STATE_IDLE) begin
        item_info_valid <= 1'b0;
      end
      
      // latch selected item when selection arrives in IDLE
      if(current_state == STATE_IDLE && sync_item_select_valid) begin 
        selected_item_reg <= sync_item_select;
        // Immediately initiate a memory read for the selected item (one-cycle read request)
        mem_read_en <= 1'b1;
        mem_read_addr <= sync_item_select;
      end
      
      // Latch item information when memory responds
      if(mem_data_valid) begin
        item_cost_reg <= mem_item_cost;
        item_available_reg <= mem_item_available;
        item_info_valid <= 1'b1;
      end

      // accumulate credit in WAIT_FOR_MONEY
      if(sync_currency_valid && current_state == STATE_WAIT_FOR_MONEY) begin
        current_credit <= current_credit + sync_currency_value;
      end

//      if (current_state == STATE_DISPENSE) begin
//      end

    end
  end
  
  // Combinational next-state and outputs
  always @(*) begin
    next_state = current_state;
    // default outputs
    mem_update_en = 1'b0;
    mem_update_addr = selected_item_reg;
    item_dispense_valid = 1'b0;
    item_dispense = 10'b0;
    currency_change = 8'b0;

    if (cfg_mode) begin
      next_state = STATE_IDLE;
    end else begin
      case(current_state)
        STATE_IDLE: begin
          if(sync_item_select_valid) begin
            next_state = STATE_WAIT_FOR_MONEY; // memory read request already asserted in sequential when selection occurred
          	end
          else if (sync_currency_valid) begin
            // No item selected but coin inserted ? return immediately
            item_dispense_valid <= 1'b1;
            item_dispense      <= 10'd0;       // 0 = no item
            currency_change    <= sync_currency_value;
            next_state         = STATE_IDLE;         // stay in idle
        	end
        end
        
        STATE_WAIT_FOR_MONEY: begin
          if (item_info_valid && item_available_reg == 8'b0 && current_credit > 0) begin
            next_state = STATE_EMPTY;
          end else if(item_info_valid && current_credit >= item_cost_reg) begin
            next_state = STATE_DISPENSE;
          end
        end
        
        STATE_DISPENSE: begin
          // On entering DISPENSE, perform update and produce outputs
          item_dispense_valid = 1'b1;
          item_dispense = selected_item_reg;
          if (current_credit > item_cost_reg)
            currency_change = (current_credit > item_cost_reg) ? 
                  (current_credit - item_cost_reg) : 
                  8'b0;

          
          else
            currency_change = 8'b0;

          mem_update_en = 1'b1;     
          mem_update_addr = selected_item_reg;
          next_state = STATE_IDLE;
        end
        
        STATE_EMPTY: begin
          item_dispense_valid = 1'b1;
          item_dispense = 10'd1023;       // sentinel for empty
          currency_change = current_credit[7:0]; 
          mem_update_en = 1'b0;    
          next_state = STATE_IDLE;
        end
        
        default: begin
          next_state = STATE_IDLE;
        end
      endcase
    end
  end
  
endmodule
