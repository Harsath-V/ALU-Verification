`timescale 1ns / 1ps

class transaction_item;
    bit rstn;
    rand bit [7:0] a,b;
    rand bit [2:0] op;
    bit [7:0] result;
    bit carry;

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
  logic [2:0]op;
  logic [7:0] result;
  logic 		carry;
endinterface

//-----------------------
// GENERATOR
// ----------------------
class generator;
  event drv_done;
  mailbox drv_mbx;

  task run();
    bit [2:0] opcode [5] = '{3'b000, 3'b001, 3'b010, 3'b011, 3'b100};
    for (int i = 0; i < 10; i++) begin
        for (int j = 0; j < 10; j++) begin
            for (int k = 0; k < 5; k++) begin
              transaction_item item = new;
//              item.rstn = 1;
              item.a = i;
              item.b = j;
              item.op = opcode[k];
              $display("T=%0t [Generator] a=%0d b=%0d op=%03b", $time, i, j, opcode[k]);
              drv_mbx.put(item);
//              $display ("T=%0t [Generator] Wait for driver to be done", $time);
              @(drv_done);
            end
        end
    end
  endtask
endclass

//-----------------------
// DRIVER
// ----------------------
class driver;
    mailbox drv_mbx;
    event drv_done;
    virtual intf vif;

    task run();
        $display ("T=%0t [Driver] starting ...", $time);
        forever begin
            transaction_item item;
//            $display ("T=%0t [Driver] waiting for item ...", $time);
            drv_mbx.get(item);
            item.print();
            @ (negedge vif.clk);
            vif.a <= item.a;
            vif.b <= item.b;
            vif.op <= item.op;
            @ (posedge vif.clk);
            #1;
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
            bins one  = {8'h01};
            bins max  = {8'hFF};
        }

        cp_b : coverpoint item.b {
            bins zero = {8'h00};
            bins one  = {8'h01};
            bins max  = {8'hFF};
        }

        cp_carry : coverpoint item.carry {
            bins no_carry = {0};
            bins carry    = {1};
        }

        op_a : cross cp_op, cp_a;
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
    virtual intf vif;
    mailbox scb_mbx;
    alu_coverage c0;

    task run();
        $display ("T=%0t [Monitor] starting ...", $time);
        forever begin
            transaction_item item = new();
            @ (posedge vif.clk);
            #1;
            item.rstn = vif.rstn;
            item.a = vif.a;
            item.b = vif.b;
            item.op = vif.op;
            item.result = vif.result;
            item.carry = vif.carry;
            item.print();
            scb_mbx.put(item);
            c0.sample(item);
        end
    endtask
endclass

//-----------------------
// SCOREBOARD
// ----------------------
class scoreboard;
    mailbox scb_mbx;
    task run();
        transaction_item item, ref_item;
        int carry_success = 0;
        int result_success = 0;
        int carry_failure = 0;
        int result_failure = 0;

        forever begin
            scb_mbx.get(item);
            ref_item = new();
            ref_item.copy(item);

            // expected conditions
            if (ref_item.rstn) begin
                if(ref_item.op == 3'b000)
                    {ref_item.carry, ref_item.result} = ref_item.a + ref_item.b;
                else if(ref_item.op == 3'b001)
                    {ref_item.carry, ref_item.result} = ref_item.a - ref_item.b;
                else if(ref_item.op == 3'b010)
                    {ref_item.carry, ref_item.result} = ref_item.a & ref_item.b;
                else if(ref_item.op == 3'b011)
                    {ref_item.carry, ref_item.result} = ref_item.a | ref_item.b;
                else if(ref_item.op == 3'b100)
                    {ref_item.carry, ref_item.result} = ref_item.a ^ ref_item.b;
                else
                    {ref_item.carry, ref_item.result} = 0;
            end
            else begin
                {ref_item.carry, ref_item.result} = 0;
            end

            if (ref_item.carry != item.carry) begin
//                $display("[%0t] Scoreboard Error! Carry mismatch ref_item=0x%0h item=0x%0h", $time, ref_item.carry, item.carry);
                carry_failure = carry_failure + 1;
          end else begin
//            $display("[%0t] Scoreboard Pass! Carry match ref_item=0x%0h item=0x%0h", $time, ref_item.carry, item.carry);
            carry_success = carry_success + 1;
          end

          if (ref_item.result != item.result) begin
//            $display("[%0t] Scoreboard Error! Result mismatch ref_item=0x%0h item=0x%0h", $time, ref_item.result, item.result);
            result_failure = result_failure + 1;
          end else begin
//            $display("[%0t] Scoreboard Pass! Result match ref_item=0x%0h item=0x%0h", $time, ref_item.result, item.result);
            result_success = result_success + 1;
          end
          $display(" Success = %0d, %0d", result_success, carry_success);
          $display(" Failure = %0d, %0d", result_failure, carry_failure);
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

  virtual intf vif;

  function new();
      d0 = new;
      m0 = new;
      g0 = new;
      s0 = new;
      c0 = new;

      drv_mbx = new();
      scb_mbx = new();
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
      	g0.run();
      join_any
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

        intf.rstn <= 0;
        intf.a    = 0;
        intf.b    = 0;
        intf.op   = 0;

        repeat (2) @(posedge clk);
        #1;
        intf.rstn = 1;

        t0.e0.vif = intf;
        t0.run();

        $display("==============================");
        $display("FUNCTIONAL COVERAGE");
        $display("==============================");
        $display("cp_op    = %0.2f%%",
                 t0.e0.c0.alu_cg.cp_op.get_coverage());
        $display("cp_a     = %0.2f%%",
                 t0.e0.c0.alu_cg.cp_a.get_coverage());
        $display("cp_b     = %0.2f%%",
                 t0.e0.c0.alu_cg.cp_b.get_coverage());
        $display("cp_carry = %0.2f%%",
                 t0.e0.c0.alu_cg.cp_carry.get_coverage());
        $display("Overall  = %0.2f%%",
                 t0.e0.c0.alu_cg.get_coverage());
        $display("==============================");

        $finish;
    end
endmodule
