`timescale 1ns / 1ps

class transaction_item;
    bit rstn;
    rand bit [7:0] a,b;
    rand bit [2:0] op;
    bit [7:0] result;
    bit carry;
    
//    // Constrain opcodes to valid ALU operations
//    constraint valid_op {
//        op inside {3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111};
//    }

//    // Distribution constraint for corner cases
//    constraint corner_cases_a {
//        a dist { 8'h00 := 20, 8'hFF := 20, [8'h01:8'hFE] := 60};
//    }
//    constraint corner_cases_b {
//        b dist { 8'h00 := 20, 8'hFF := 20, [8'h01:8'hFE] := 60 };
//    }
    
    function void print();
        $display("Values: a=0x%0h, b=0x%0h, result=0x%0h, carry=0x%0h",a, b, result, carry);
    endfunction

    function void copy(transaction_item tmp);
        this.rstn = tmp.rstn;
        this.a = tmp.a;
        this.b = tmp.b;
        this.op = tmp.op;
        this.result = tmp.result;
        this.carry = tmp.carry;
  endfunction
endclass

//-----------------------
// INTERFACE
// ----------------------
interface intf(input bit clk);
  logic rstn;
  logic [7:0] a, b;
  logic [2:0] op;
  logic [7:0] result;
  logic       carry;

  // Driver Clocking Block: Outputs from TB -> Inputs to DUT
  clocking driver_cb @(posedge clk);
    default input #1step output #1ns;
    output rstn, a, b, op;
  endclocking

  // Monitor Clocking Block: Inputs to TB <- Outputs from DUT
  clocking monitor_cb @(posedge clk);
    default input #1step output #1ns;
    input rstn, a, b, op, result, carry;
  endclocking

  // Modports to restrict direction
  modport DRV (clocking driver_cb, input clk);
  modport MON (clocking monitor_cb, input clk);
  
  // SVA 1: Reset Assertion (Active Low Reset forces outputs to 0 on next posedge)
    property p_reset_check;
        @(posedge clk) !rstn |=> (result == 8'h00 && carry == 1'b0);
    endproperty
    a_reset_check: assert property(p_reset_check)
        else $error("SVA Error: Reset failed to clear outputs!");

    // SVA 2: Operation Stability Check (Outputs shouldn't be X/Z when reset is released)
    property p_no_unknowns;
        @(posedge clk) disable iff (!rstn) !$isunknown({result, carry});
    endproperty
    a_no_unknowns: assert property(p_no_unknowns)
        else $error("SVA Error: Result/Carry driving X or Z!");

    // SVA 3: Combinational AND Assertion check using $past
    property p_and_and;
        @(posedge clk) disable iff (!rstn)
        $past(rstn) && ($past(op) == 3'b010) |-> (result == ($past(a) & $past(b)) && carry == 1'b0);
    endproperty
    a_and_and: assert property(p_and_and)
        else $error("SVA Error: AND operation output mismatch!");
   
   // SVA 4: Combinational ADD Assertion check using $past     
   property p_and_add;
        @(posedge clk) disable iff (!rstn)
        $past(rstn) && ($past(op) == 3'b000) |-> ({carry, result} == ($past(a) + $past(b)));
    endproperty
    a_and_add: assert property(p_and_add)
        else $error("SVA Error: ADD operation output mismatch!");
    
    // SVA 5: Combinational SUB Assertion check using $past
    property p_and_sub;
        @(posedge clk) disable iff (!rstn)
        $past(rstn) && ($past(op) == 3'b001) |-> (result == ($past(a) - $past(b)) && carry == ($past(a) < $past(b)));
    endproperty
    a_and_sub: assert property(p_and_sub)
        else $error("SVA Error: SUB operation output mismatch!");   
    
    // SVA 6: Combinational OR Assertion check using $past
    property p_and_or;
        @(posedge clk) disable iff (!rstn)
        $past(rstn) && ($past(op) == 3'b011) |-> (result == ($past(a) | $past(b)) && carry == 1'b0);
    endproperty
    a_and_or: assert property(p_and_or)
        else $error("SVA Error: OR operation output mismatch!");      
    
    // SVA 7: Combinational XOR Assertion check using $past
    property p_and_xor;
        @(posedge clk) disable iff (!rstn)
        $past(rstn) && ($past(op) == 3'b100) |-> (result == ($past(a) ^ $past(b)) && carry == 1'b0);
    endproperty
    a_and_xor: assert property(p_and_xor)
        else $error("SVA Error: XOR operation output mismatch!");   
    
    // SVA 8: Invalid Opcode
    property p_invalid_op;
        @(posedge clk) disable iff (!rstn)
        ($past(op) inside {3'b101, 3'b110, 3'b111}) |-> (result == 8'h00 && carry == 1'b0);
    endproperty
    a_invalid_op: assert property(p_invalid_op)
        else $error("SVA Error: Invalid opcode did not produce zero output!");
endinterface

//-----------------------
// GENERATOR
// ----------------------
class generator;
  event drv_done;
  event gen_cmpltd;
  mailbox drv_mbx;
  
  task run();
    bit [2:0] opcode [8] = '{3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111};
    
    for (int i = 0; i < 256; i++) begin
        for (int j = 0; j < 256; j++) begin
            for (int k = 0; k < 8; k++) begin
                transaction_item item = new();
                
                item.rstn = 1'b1; // Default to active high operational mode
                item.a = i;
                item.b = j;
                item.op = opcode[k];
                
                drv_mbx.put(item);
                @(drv_done);
            end
        end
     end
     -> gen_cmpltd;
  endtask
endclass

//-----------------------
// DRIVER
// ----------------------
class driver;
    mailbox drv_mbx;
    event drv_done;
    virtual intf.DRV vif;
    
    task reset();
        @(vif.driver_cb);
        vif.driver_cb.rstn <= 1'b0;
        vif.driver_cb.a    <= 8'h00;
        vif.driver_cb.b    <= 8'h00;
        vif.driver_cb.op   <= 3'b000;
        repeat(2) @(vif.driver_cb);
        vif.driver_cb.rstn <= 1'b1;
    endtask
    
    task run();
        $display ("T=%0t [Driver] starting ...", $time);
        forever begin
            transaction_item item;
            drv_mbx.get(item);
            
            // Synchronize with driver clocking block
            @(vif.driver_cb);
            @(vif.driver_cb);
            vif.driver_cb.rstn <= item.rstn;
            vif.driver_cb.a    <= item.a;
            vif.driver_cb.b    <= item.b;
            vif.driver_cb.op   <= item.op;
//            @(vif.driver_cb);
            ->drv_done;
        end
    endtask
endclass

//-----------------------
// COVERPOINT
// ----------------------
class alu_coverage;
    transaction_item item;
    covergroup alu_cg;

        cp_op : coverpoint item.op {
            bins add    = {3'b000};
            bins sub    = {3'b001};
            bins and_op = {3'b010};
            bins or_op  = {3'b011};
            bins xor_op = {3'b100};
        }

        cp_a : coverpoint item.a {
            bins zero = {8'h00};
            bins max  = {8'hFF};
            bins low_range  = {[8'h01:8'h7F]};
            bins high_range = {[8'h80:8'hFE]};
        }

        cp_b : coverpoint item.b {
            bins zero = {8'h00};
            bins max  = {8'hFF};
            bins low_range  = {[8'h01:8'h7F]};
            bins high_range = {[8'h80:8'hFE]};
        }  
         
        cp_carry : coverpoint item.carry {
            bins no_carry = {1'b0};
            bins carry_set = {1'b1};
        }
        
        cp_rstn : coverpoint item.rstn {
            bins active_reset = {1'b0};
            bins operational  = {1'b1};
        }

        // Crosses
        cross_op_a : cross cp_op, cp_a;
        cross_op_b : cross cp_op, cp_b;
        cross_op_carry : cross cp_op, cp_carry {
            ignore_bins no_logical_carry = binsof(cp_op) intersect {3'b010, 3'b011, 3'b100} 
                                          && binsof(cp_carry) intersect {1'b1};
        }
        cross_all  : cross cp_op, cp_a, cp_b;
    endgroup

    function new();
        alu_cg = new();
    endfunction

    function void sample(transaction_item t);
        item = t;
        alu_cg.sample();
    endfunction

endclass

//-----------------------
// MONITOR
// ----------------------
class monitor;
    virtual intf.MON vif;
    mailbox scb_mbx;
    alu_coverage c0;
    
    task run();
        $display ("T=%0t [Monitor] starting ...", $time);
        forever begin
            transaction_item item = new();
            // Sample strictly on clocking block edge (no #1 manual delay needed)
            @(vif.monitor_cb);
            item.rstn = vif.monitor_cb.rstn;
            item.a    = vif.monitor_cb.a;
            item.b    = vif.monitor_cb.b;
            item.op   = vif.monitor_cb.op;
            
            @(vif.monitor_cb);
            item.result = vif.monitor_cb.result;
            item.carry  = vif.monitor_cb.carry;
            
//            item.print();
            scb_mbx.put(item);
            c0.sample(item);
        end
    endtask
endclass

//-----------------------
// REFERENC MODEL
// ----------------------
class reference_model;
    function transaction_item predict(transaction_item in_trans);
        transaction_item exp_trans = new();
        exp_trans.copy(in_trans);

        if (exp_trans.rstn) begin
            case (exp_trans.op)
                3'b000: {exp_trans.carry, exp_trans.result} = exp_trans.a + exp_trans.b;
                3'b001: {exp_trans.carry, exp_trans.result} = {exp_trans.a < exp_trans.b, exp_trans.a - exp_trans.b}; // Unsigned borrow-out
                3'b010: {exp_trans.carry, exp_trans.result} = {1'b0, exp_trans.a & exp_trans.b};
                3'b011: {exp_trans.carry, exp_trans.result} = {1'b0, exp_trans.a | exp_trans.b};
                3'b100: {exp_trans.carry, exp_trans.result} = {1'b0, exp_trans.a ^ exp_trans.b};
                default: {exp_trans.carry, exp_trans.result} = '0;
            endcase
        end else begin
            {exp_trans.carry, exp_trans.result} = '0;
        end

        return exp_trans;
    endfunction
endclass

//-----------------------
// SCOREBOARD
// ----------------------
class scoreboard;
    mailbox scb_mbx;
    int pass_count = 0;
    int fail_count = 0;
    task run();
        transaction_item item;
        transaction_item prev_item;
        transaction_item ref_item;
        reference_model ref_mod;

        forever begin
            ref_mod = new();
            // Get transaction from monitor
            scb_mbx.get(item);
            // ------------------------------------------------
            // First transaction:
            // DUT output still corresponds to reset/old data
            // So don't compare it.
            // ------------------------------------------------
            if (prev_item == null) begin
                prev_item = new();
                prev_item.copy(item);
                $display("T=%0t [Scoreboard] First transaction captured, waiting for DUT output...",$time);
                continue;
            end
            
            ref_item = ref_mod.predict(item);

            // ------------------------------------------------
            // Compare expected result against DUT output
            // ------------------------------------------------
            if ((ref_item.result === item.result) &&
                (ref_item.carry  === item.carry)) begin
                    pass_count++;
                end
            else begin
                fail_count++;
                $display(
                    "T=%0t [ERROR] Mismatch! Op=%03b A=%0h B=%0h | Exp: Result=%0h Carry=%0b | Rec: Result=%0h Carry=%0b",
                    $time,
                    prev_item.op,
                    prev_item.a,
                    prev_item.b,
                    ref_item.result,
                    ref_item.carry,
                    item.result,
                    item.carry
                );

            end
//            $display(
//                "T=%0t [Scoreboard] Summary: Passed=%0d, Failed=%0d",
//                $time,
//                pass_count,
//                fail_count
//            );
            // ------------------------------------------------
            // Current transaction becomes previous transaction
            // for the next clock cycle
            // ------------------------------------------------
            prev_item.copy(item);
        end
    endtask
endclass



//-----------------------
// ENVIRONMENT
// ----------------------
class env;
  driver 		d0; 		// Driver handle
  monitor 		m0; 		// Monitor handle
  generator		g0; 		// Generator Handle
  scoreboard	s0; 		// Scoreboard handle
  alu_coverage  c0;

  mailbox 	drv_mbx; 		// Connect GEN -> DRV
  mailbox 	scb_mbx; 		// Connect MON -> SCB
  event 	drv_done; 		// Indicates when driver is done
  event     gen_cmpltd;

  virtual intf vif;

  function new();
      d0 = new;
      m0 = new;
      g0 = new;
      s0 = new;
      c0 = new;

      drv_mbx = new();
      scb_mbx = new();
      
//      drv_done   = new();
//      gen_cmpltd = new();
  endfunction

  virtual task run();
      d0.drv_mbx = drv_mbx; g0.drv_mbx = drv_mbx;
      m0.scb_mbx = scb_mbx; s0.scb_mbx = scb_mbx;
      d0.drv_done = drv_done; g0.drv_done = drv_done;
      m0.c0 = c0;

      d0.vif = vif;
      m0.vif = vif;
      
      fork
        s0.run();
		d0.run();
    	m0.run();
      join_none
      
      d0.reset();
      
      fork
      g0.run();
      @(g0.gen_cmpltd);
      join_any
      
      // Allow pipeline pipeline drain (wait until scoreboard processes remaining mailbox items)
      wait(scb_mbx.num() == 0);
      #100ns;
      
       
      $display(
                "T=%0t [Scoreboard] Summary: Passed=%0d, Failed=%0d",
                $time,
                s0.pass_count,
                s0.fail_count
            );
  endtask
endclass

//-----------------------
// TEST
// ----------------------
class test;
    env e0;
    function new();
        e0 = new;
    endfunction

    task run();
        e0.run();
    endtask
endclass

//----------------------------------
// TESTBENCH TOP
//----------------------------------

module testbench();
    reg clk;
    initial begin
        clk = 0;
        intf.rstn = 0;
        forever begin
            #10 clk = ~clk;
        end
    end

    intf intf(clk);

    alu u0(
        .clk(intf.clk),
        .rstn(intf.rstn),
        .a(intf.a),
        .b(intf.b),
        .op(intf.op),
        .result(intf.result),
        .carry(intf.carry)
    );

    test t0;
    initial begin
        t0 = new;
        t0.e0.vif = intf;

        t0.run();

        $display("==============================");
        $display("FUNCTIONAL COVERAGE");
        $display("==============================");
        $display("cp_op    = %0.2f%%", t0.e0.c0.alu_cg.cp_op.get_coverage());
        $display("cp_a     = %0.2f%%", t0.e0.c0.alu_cg.cp_a.get_coverage());
        $display("cp_b     = %0.2f%%", t0.e0.c0.alu_cg.cp_b.get_coverage());
        $display("Cross Overall  = %0.2f%%", t0.e0.c0.alu_cg.cross_all.get_coverage());
        $display("Overall  = %0.2f%%", t0.e0.c0.alu_cg.get_coverage());
        $display("==============================");
        
        $finish;
    end
endmodule
