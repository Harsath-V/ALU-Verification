# 8-bit ALU — SystemVerilog Functional Verification

A SystemVerilog-based verification environment for a simple **8-bit Arithmetic Logic Unit (ALU)**. The project demonstrates a class-based, constrained-random testbench with a generator, driver, monitor, reference model, scoreboard, functional coverage, and SystemVerilog Assertions (SVA).

## Project Overview

The ALU is a clocked design with an active-low asynchronous reset. It accepts two 8-bit operands and a 3-bit operation code, producing an 8-bit result and a carry output.

The verification environment generates randomized transactions, drives them to the DUT, observes the outputs, calculates expected results using a reference model, compares expected and actual outputs, and collects functional coverage.

## ALU Operations

| `op` | Operation | Result | Carry |
|------|-----------|--------|-------|
| `000` | Addition | `a + b` | Carry-out |
| `001` | Subtraction | `a - b` | Unsigned borrow-out |
| `010` | AND | `a & b` | `0` |
| `011` | OR | `a \| b` | `0` |
| `100` | XOR | `a ^ b` | `0` |
| Others | Default | `0` | `0` |

The DUT is implemented as a sequential ALU, with outputs updated on the rising edge of `clk`.

## Verification Architecture

```text
                 +----------------+
                 |    Generator   |
                 | Constrained     |
                 | Random Stimulus |
                 +-------+--------+
                         |
                         v
                 +----------------+
                 |     Driver     |
                 +-------+--------+
                         |
                         v
                  +-------------+
                  |     DUT     |
                  |  8-bit ALU  |
                  +------+------+
                         |
                         v
                 +----------------+
                 |    Monitor     |
                 +-------+--------+
                         |
             +-----------+-----------+
             |                       |
             v                       v
      +-------------+         +--------------+
      | Scoreboard  |         |  Coverage    |
      | + Reference |         |  Collection  |
      |    Model    |         +--------------+
      +-------------+

             Interface
        + SystemVerilog Assertions
        + Clocking Blocks
        + Modports
```

## Testbench Components

### 1. Transaction Item

`transaction_item` represents a single ALU transaction.

It contains:
- Reset
- Operand `a`
- Operand `b`
- Operation `op`
- Observed/expected `result`
- Observed/expected `carry`

The operands and operation are randomized using SystemVerilog constraints.

### 2. Constrained-Random Generator

The generator creates **2500 randomized transactions**.

The operation is constrained to the five supported ALU operations:

```systemverilog
3'b000, 3'b001, 3'b010, 3'b011, 3'b100
```

Corner-case distribution is also applied to both operands:

- `8'h00` — 20%
- `8'hFF` — 20%
- `8'h01` to `8'hFE` — 60%

This increases the likelihood of exercising boundary values while still providing broad randomized stimulus.

### 3. Driver

The driver receives transactions through a mailbox and drives:

- `rstn`
- `a`
- `b`
- `op`

through the interface's driver clocking block.

The reset sequence initially drives reset low for two clock cycles and then releases it.

### 4. Monitor

The monitor samples DUT inputs and outputs through the monitor clocking block and forwards transactions to the scoreboard.

It also sends observed transactions to the functional coverage model.

### 5. Reference Model

The reference model independently calculates the expected ALU output for each transaction.

This provides a golden model against which the DUT output is compared.

### 6. Scoreboard

The scoreboard compares:

- Expected `result` vs. actual `result`
- Expected `carry` vs. actual `carry`

The implementation accounts for the ALU's one-cycle sequential behavior by using the previous sampled transaction when generating the expected output.

It maintains:

```text
Pass Count
Fail Count
```

and prints mismatch information whenever the DUT output differs from the reference model.

### 7. Functional Coverage

The testbench collects coverage for:

- Operation
- Operand `a`
- Operand `b`
- Carry
- Reset state

Cross coverage includes:

- Operation × `a`
- Operation × `b`
- Operation × Carry
- Operation × `a` × `b`

Logical operations are excluded from the carry-set cross because AND, OR, and XOR explicitly drive carry to zero.

### 8. SystemVerilog Assertions

The interface contains three SVA checks.

#### Reset Check

Verifies that when reset is asserted, the DUT outputs become zero on the next rising clock edge.

#### Unknown-State Check

Checks that `result` and `carry` do not contain X/Z values during normal operation.

#### AND Operation Check

Uses `$past()` to verify that an AND operation produces the expected result and clears carry.

## Key SystemVerilog Concepts Demonstrated

This project demonstrates several important verification concepts:

- SystemVerilog classes
- Object-oriented testbench architecture
- Constrained-random stimulus
- Mailboxes
- Events
- Virtual interfaces
- Clocking blocks
- Modports
- Reference modeling
- Scoreboarding
- Functional coverage
- Cross coverage
- SystemVerilog Assertions
- `$past()`
- `$isunknown()`
- Reset verification
- One-cycle DUT latency handling

## File Structure

A typical GitHub repository can be organized as:

```text
8bit-alu-systemverilog/
│
├── rtl/
│   └── alu.sv
│
├── tb/
│   └── alu_tb.sv
│
├── README.md
└── ...
```

The RTL file contains the ALU DUT, while the testbench contains the transaction, generator, driver, monitor, reference model, scoreboard, coverage, assertions, environment, and testbench top.

## Expected Verification Flow

```text
Reset
  ↓
Generate randomized transaction
  ↓
Drive transaction to DUT
  ↓
DUT processes transaction on clock edge
  ↓
Monitor samples transaction/output
  ↓
Reference model predicts expected result
  ↓
Scoreboard compares expected vs. actual
  ↓
Coverage is sampled
  ↓
Repeat for 2500 transactions
  ↓
Print pass/fail and coverage summary
```

## Coverage Summary

At the end of simulation, the testbench reports:

```text
FUNCTIONAL COVERAGE
==============================
cp_op
cp_a
cp_b
Cross Overall
Overall
==============================
```

The exact coverage percentages depend on the simulator and randomized stimulus generated during the run.

## How to Run

The source uses SystemVerilog features, so it should be compiled using a SystemVerilog-capable simulator such as:

- Siemens Questa/ModelSim
- Synopsys VCS
- Cadence Xcelium
- Aldec Riviera-PRO

Example with a simulator that supports SystemVerilog:

```text
Compile:
    alu.sv
    alu_tb.sv

Run:
    testbench

Review:
    Pass/Fail scoreboard summary
    Assertion results
    Functional coverage
```

The exact compilation and simulation commands depend on the simulator being used.

## Verification Goals

The primary goals of this project are to verify:

1. Correct arithmetic operations.
2. Correct logical operations.
3. Correct carry behavior.
4. Correct reset behavior.
5. Absence of unknown output values during operation.
6. Correct handling of sequential/one-cycle output behavior.
7. Coverage of valid operations and operand ranges.
8. Coverage of important corner cases such as `0x00` and `0xFF`.

## Notes

- Reset is active-low (`rstn`).
- The ALU outputs are registered.
- Only five operation codes are considered valid.
- Addition and subtraction use a 9-bit concatenation to capture the carry/borrow bit.
- The testbench uses constrained randomization rather than a fixed directed test set.
- The scoreboard compares the DUT output against the previous transaction because the DUT is sequential.

## Future Improvements

Possible extensions include:

- Add directed tests for specific arithmetic corner cases.
- Add assertions for ADD, SUB, OR, and XOR operations.
- Add more detailed carry/borrow coverage.
- Add functional coverage for specific arithmetic boundary combinations.
- Add a virtual sequence/sequencer-style structure.
- Add automated regression scripts.
- Add waveform configuration and examples.
- Add simulator-specific Makefile or run scripts.
