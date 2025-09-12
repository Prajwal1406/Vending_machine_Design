module main_fsm (
  input wire clk,
  input wire rstn,
  input wire cfg_mode,
  input wire sync_currency_valid,
  input wire [7:0] sync_currency_value,
  input wire sync_item_select_valid,
  input wire [9:0] sync_item_select,
  //Interface with cfg block
  input wire [15:0] item_cost,
  input wire [7:0] item_available,
  output reg [9:0] cfg_item_id, //address kind of
  output reg cfg_item_read_req,
  output reg cfg_item_update_req,
  //Outputs to the Output Control Block
  output reg item_dispense_valid,
  output reg [9:0] item_dispense,
  output reg [7:0] currency_change
);
  
  //States for the fsm
  localparam STATE_IDLE = 2'b00;
  localparam STATE_WAIT_FOR_MONEY = 2'b01;
  localparam STATE_DISPENSE = 2'b10;
  localparam STATE_RETURN_CHANGE = 2'b11;
  //Registers for FSM state and variables
  reg [1:0] current_state,next_state;
  reg [15:0] current_credit;
  reg [9:0] selected_item_reg;
  
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin 
    	current_state <= STATE_IDLE;
      	current_credit <= 16'b0;
      	selected_item_reg <= 10'b0;
    end else begin
      	current_state <= next_state;
      if(current_state == STATE_IDLE && sync_item_select_valid) begin 
      	selected_item_reg <= sync_item_select;
      end
      if(sync_currency_valid) begin
        current_credit <= current_credit + sync_currency_value;
      end
    end
  end
  
 //FSM LOGIC
  always@(*)begin
    next_state = current_state;
    cfg_item_read_req = 1'b0;
    cfg_item_update_req = 1'b0;
    cfg_item_id = selected_item_reg;
    item_dispense_valid = 1'b0;
    item_dispense = 10'b0;
    currency_change = 8'b0;
    
    case(current_state)
      STATE_IDLE: begin
        if(sync_item_select_valid)begin
          cfg_item_read_req = 1'b1;
          next_state = STATE_WAIT_FOR_MONEY;
        end
      end
      STATE_WAIT_FOR_MONEY: begin
        if(current_credit >= item_cost) begin
          next_state = STATE_DISPENSE;
        end
      end
      STATE_DISPENSE: begin
        item_dispense_valid = 1'b1;
        item_dispense = selected_item_reg;
        currency_change = current_credit - item_cost;
        cfg_item_update_req = 1'b1;
        next_state = STATE_RETURN_CHANGE;
      end
      STATE_RETURN_CHANGE: begin
        next_state= STATE_IDLE;
        current_credit = 16'b0;
      end
    endcase
  end
endmodule