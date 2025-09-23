module top;

localparam MAX_ITEMS = 32;
localparam MAX_NOTE_VAL = 100;

reg clk;
reg rstn;
reg        pclk;
reg [14:0] paddr;
reg        prstn;
reg [31:0] pwdata;
wire [31:0] prdata;
reg        pwrite;
reg        psel;
reg        penable;
wire	   pready;
reg        cfg_mode;
reg currency_valid;
reg [$clog2(MAX_NOTE_VAL):0] currency_value;
reg item_select_valid;
reg [$clog2(MAX_ITEMS)-1 : 0] item_select;

//Ouput interface
wire dispense_valid;
wire [$clog2(MAX_ITEMS)-1 : 0] item_dispensed;
wire [7:0] currency_change;

reg [$clog2(MAX_ITEMS)-1 : 0] exp_item_dispensed;
reg [15:0] exp_currency_change;

reg debug_en;
string test_name;

vending_top #(
  .MAX_ITEMS (MAX_ITEMS),
  .MAX_NOTE_VAL(MAX_NOTE_VAL)
) dut (
  // General interface
  .clk_fsm(clk),
  .rstn(rstn),

  // APB Interface
  .clk_apb(pclk),
  .paddr(paddr),
  .pwdata(pwdata),
  .prdata(prdata),
  .pwrite(pwrite),
  .psel(psel),
  .pready(pready),
  // Config mode
  .cfg_mode(cfg_mode),

  // Coin / Note interface
  .currency_valid_async(currency_valid),
  .currency_value_async(currency_value),

  // Item select interface
  .item_select_valid_async(item_select_valid),
  .item_select_async(item_select),

  // Output interface (mapped to what TB expects)
  .item_dispense_valid(dispense_valid),
  .item_dispense(item_dispensed),
  .currency_change(currency_change)
);



//All inputs 0 at start of sim
initial begin
  clk         = 'h0;
  rstn        = 1'b1;
  pclk        = 'h0;
  prstn       = 1'b1;
  paddr       = 'h0;
  pwdata      = 'h0;
  pwrite      = 'h0;
  psel        = 'h0;
  currency_valid     = 'h0;
  currency_value    = 'hFFF;
  item_select_valid  = 'h0;
  item_select   = 'hFFFF;

end
initial begin
forever begin
  #5 clk = ~clk;
end
end
initial begin
forever begin
  #10 pclk = ~pclk;
end
end

//Rst generation for 10ns
initial begin
rstn = 1'b1;
prstn = 1'b1;
#1ns;
rstn = 1'b0;
prstn = 1'b0;
#10ns;
rstn = 1'b1;
prstn = 1'b1;
end

//Write to cfg
task apb_write(input [15:0] addr, input [31:0] data);
begin
    @(negedge clk);
    cfg_mode = 1'b1;
    paddr  = addr;
    pwdata = data;
    psel   = 1'b1;
    pwrite = 1'b1;
    penable = 1'b1;

    wait(pready == 1);  // Wait for DUT to complete write
  	repeat (3) @(negedge pclk); 

    // Deassert
    paddr  = 0;
    pwdata = 0;
    psel   = 0;
    pwrite = 0;
    penable = 0;
    cfg_mode = 0;

    if (debug_en)
        $display("APB WRITE addr=0x%04X data=0x%08X DONE", addr, data);

    @(negedge clk);
end
endtask

task apb_read(input [15:0] addr, output [31:0] rd_data, input [31:0] chk_data=0, input chk=0);
begin
  @(negedge clk);
  paddr  = 'h0;
  psel   = 1'b0;
  pwrite = 1'b0;
  penable = 1'b1;
  cfg_mode = 1'b1;
  @(negedge clk);
  paddr  = addr;
  psel   = 1'b1;
  pwrite = 1'b0;
  pwdata = 'h0;
  @(negedge clk);
    wait (pready == 1);
  rd_data = prdata;
  if (chk && (prdata !== chk_data)) begin
    $error("Expected Data = %0x Actual data = %0x", chk_data, prdata);
  end 
  else begin
    if (debug_en) $display("Read data is 0x%x", prdata);
  end
  paddr  = 'h0;
  psel   = 1'b0;
  pwrite = 1'b0;
  pwdata = 'h0;
  penable = 1'b0;
  cfg_mode = 1'b0;
  @(negedge clk);
end
endtask



//Task to program a specific item cfg
task program_item_cfg (input [$clog2(MAX_ITEMS)-1 : 0] item_no, input [15:0] item_value, input [7:0] item_available);
begin
  apb_write((16'h0004 + item_no*4), {8'd0, item_available, item_value});
end
endtask

//program_item_cfg
task read_item_cfg (input [$clog2(MAX_ITEMS)-1 : 0] item_no, input [15:0] item_value, input [7:0] item_available, output rd_data);
begin
  apb_read((16'h0004 + item_no*4), rd_data, {8'd0, item_available, item_value});
end
endtask
//program_item_cfg

//Set or Reset Item Interface
task set_rst_item(input [$clog2(MAX_ITEMS)-1 : 0] item_no, input set_rst);
begin
  @(negedge clk);
  if (set_rst) begin
    item_select_valid = 1'b1;
    item_select  = item_no;
  end
  else begin
    item_select_valid = 1'b0;
    item_select  = 'hFFFF;
  end
  @(negedge clk);
end 
endtask //set_rst_item

//Send a specific note on interface
task send_note(input [15:0] val);
begin
  $display("Driving Note interface: %0d ", val);
  @(negedge clk);
    currency_valid = 1'b1;
    currency_value = val;
    @(negedge clk);
    currency_valid = 0;
    @(negedge clk);
end
endtask

//Send an item value with change, decide on the order of notes along with
//change
task input_total_money(input [15:0] total_value);
begin
//Assume valid notes: 1, 2, 5, 10, 20
reg [15:0] remaining_value;

remaining_value = total_value;
  $display("Input all money: value: %0d", remaining_value);
while (remaining_value > 0)begin
  if (remaining_value >= 20) begin
    send_note(20);
    remaining_value -= 20;
  end
  else if (remaining_value >=10) begin
    send_note(10);
    remaining_value -= 10;
  end
  else if (remaining_value >=5) begin
    send_note(5);
    remaining_value -= 5;
  end
  else if (remaining_value >=2) begin
    send_note(2);
    remaining_value -= 2;
  end
  else if (remaining_value >=1) begin
    send_note(1);
    remaining_value -= 1;
  end	
end // while


  
end
endtask

task get_item(input [$clog2(MAX_ITEMS)-1 : 0] item_no, input [15:0] item_value, input [7:0] change=0);
begin
  $display("********************************"); 
  $display(" Item No: %0d, Cost: %0d, Change: %0d ", item_no, item_value, change);
  set_rst_item(item_no, 1);
  input_total_money ((item_value + change));  
  set_rst_item(item_no, 0);
  exp_item_dispensed = item_no;
  exp_currency_change = change;
  $display("---------------------------------");
end
endtask
//plusarg
initial begin
debug_en = 0;
test_name = "";
if ($test$plusargs ("DEBUG")) begin
  $display("Setting debug");
  debug_en = 1;
end
if ($value$plusargs ("TEST_NAME=%s", test_name)) begin
end
end // Initial for plusarg


//Test Cases calling
initial begin
  //Wait for resets to settle down
  #100ns;
  case (test_name)
    "write_read_test": write_read_test();
    "directed_test"  : directed_test();
    "random_test"    : random_test();
    default: ;
  endcase
$finish;
end

always @(posedge clk)
begin
  if (dispense_valid) begin
    $display("Output: Item Dispensed Item_no: %0d, Change: %0d ", item_dispensed, currency_change);
    if (exp_item_dispensed != item_dispensed) begin
      $display("FAIL: Exp Item   = %0d, Actual Item   = %0d", exp_item_dispensed, item_dispensed);
    end
    else begin 
      $display("PASS: Exp Item   = %0d, Actual Item   = %0d", exp_item_dispensed, item_dispensed);
    end
    if (exp_currency_change != currency_change) begin
      $display("FAIL: Exp change = %0d, Actual change = %0d", exp_currency_change, currency_change);
    end
    else begin
      $display("PASS: Exp change = %0d, Actual change = %0d", exp_currency_change, currency_change);
    end
  $display("---------------------------------\n");
  end
end
//Dump
initial begin
$dumpfile("dump.vcd");
$dumpvars(0, top);
  
end

initial begin


  test_name = "directed_test";
  debug_en = 1;
end


//----------------------------
//------Test Cases------------
//----------------------------
task write_read_test();
  reg [31:0] rd_data;
  $display("Running write_read_test");

  // Write item 0
  apb_write(16'h0000, 32'habcd);

  // Write all items
  for (int i=0; i<MAX_ITEMS; i++) begin
    apb_write((16'h0004 + i*4), (16'h2000 + i));
  end

  // Read item 0
  apb_read(16'h0000, rd_data, 32'habcd, 1'b1);

  // Read all items
  for (int i=0; i<MAX_ITEMS; i++) begin
    apb_read((16'h0004 + i*4), rd_data, (16'h2000 + i), 1'b1);
  end
endtask
 // write_read_test

task directed_test();
reg [15:0] item_val[8];
reg [7:0]  item_avail[8];
  $display("Running a directed test");
item_val['d0] = 'd11; //Value
item_val['d1] = 'd22; //Value
item_val['d2] = 'd35; //Value
item_val['d3] = 'd55; //Value
item_val['d4] = 'd51; //Value
item_val['d5] = 'd48; //Value
item_val['d6] = 'd36; //Value
item_val['d7] = 'd08; //Value
item_avail['d0] = 'd13; //Available
item_avail['d1] = 'd7 ; //Available
item_avail['d2] = 'd9 ; //Available
item_avail['d3] = 'd2 ; //Available
item_avail['d4] = 'd2 ; //Available
item_avail['d5] = 'd19; //Available
item_avail['d6] = 'd30; //Available
item_avail['d7] = 'd5 ; //Available
  for (int item_no=0; item_no<8; item_no++) begin
    program_item_cfg(item_no, item_val[item_no], item_avail[item_no]); //program 8 items
  end

//Run 10 items
get_item(1, item_val[1], 3);
repeat (2) @(negedge clk);
get_item(5, item_val[5], 2);
repeat (2) @(negedge clk);
get_item(3, item_val[3], 0);
repeat (2) @(negedge clk);
get_item(4, item_val[4], 0);
repeat (2) @(negedge clk);
get_item(7, item_val[7], 1);
repeat (2) @(negedge clk);
get_item(0, item_val[0], 1);
repeat (2) @(negedge clk);
get_item(2, item_val[2], 5);
repeat (2) @(negedge clk);
get_item(6, item_val[6], 1);
repeat (2) @(negedge clk);

for (int i=0; i<10; i++) begin
  @(negedge clk);
end

endtask

task random_test();
  $display("Running a random test");
//   program_item_cfg()
endtask

endmodule 
