ALU Verification using SystemVerilog

A class-based SystemVerilog verification environment developed to verify
an 8-bit synchronous Arithmetic Logic Unit (ALU) using
constrained/exhaustive stimulus, a reference model, scoreboard
checking, SystemVerilog Assertions (SVA), functional coverage, cross
coverage, and XSIM code coverage.

Project Overview

This project is the first verification project in a progression toward
more advanced RTL verification, including FIFO verification, APB
verification, and eventually UVM-based environments.

The ALU supports five valid operations and three invalid/reserved
opcodes.

DUT Operations

Opcode     Operation   Carry

3'b000   ADD         Addition carry-out
3'b001   SUB         Borrow indication (a < b)
3'b010   AND         0
3'b011   OR          0
3'b100   XOR         0
3'b101   Invalid     0, result 0
3'b110   Invalid     0, result 0
3'b111   Invalid     0, result 0

The ALU is synchronous and uses an active-low reset.

Verification Environment

The testbench follows a class-based, transaction-level architecture:

                    +-------------+
                    |  Generator  |
                    +------+------+
                           |
                        Mailbox
                           |
                           v
                    +-------------+
                    |   Driver    |
                    +------+------+
                           |
                           v
                    +-------------+
                    |     DUT     |
                    |     ALU     |
                    +------+------+
                           |
                           v
                    +-------------+
                    |   Monitor   |
                    +------+------+
                           |
                        Mailbox
                           |
              +------------+------------+
              |                         |
              v                         v
       +-------------+          +---------------+
       | Scoreboard  |<---------| Reference     |
       |             |          | Model         |
       +-------------+          +---------------+
              |
              v
         PASS / FAIL

       +-------------------+
       | Functional        |
       | Coverage          |
       +-------------------+

       +-------------------+
       | SVA Assertions    |
       +-------------------+

       +-------------------+
       | XSIM Code         |
       | Coverage          |
       +-------------------+

Components

Transaction Item
Encapsulates ALU inputs, reset, and output information.

Generator
Generates exhaustive ALU stimulus covering all combinations of:

a: 256 values

b: 256 values

op: 8 values

Total stimulus combinations:

256 × 256 × 8 = 524,288

Driver
Drives transactions to the DUT through a virtual interface and
clocking block.

Monitor
Samples DUT inputs and outputs using a clocking block and forwards
observed transactions to the scoreboard and coverage model.

Reference Model
Independently calculates the expected ALU result and carry/borrow
behavior.

Scoreboard
Compares DUT outputs against the reference model and maintains
pass/fail counts.

Functional Coverage
Covers ALU operations, input ranges, carry behavior, reset state,
and relevant cross coverage.

SVA Assertions
Checks reset behavior, output validity, operation correctness, and
invalid opcode behavior.

Stimulus Strategy

The final ALU test uses exhaustive stimulus rather than relying only on
randomization.

For every possible pair of 8-bit operands and every 3-bit opcode:

a   = 0 → 255
b   = 0 → 255
op  = 000 → 111

This gives:

524,288 unique input combinations

The exhaustive approach is particularly suitable for this small 8-bit
ALU because the complete input space can be simulated.

Assertions

The testbench includes SystemVerilog Assertions for:

Reset

Verifies that asserting the active-low reset causes the registered
outputs to clear.

Unknown Output Detection

Checks that result and carry do not become unknown during normal
operation.

Operation Checks

Assertions independently verify:

ADD

SUB

AND

OR

XOR

The assertions account for the ALU's registered output latency using
$past().

Invalid Opcode

Verifies that opcodes 101, 110, and 111 produce zero result and
zero carry.

Functional Coverage

The functional coverage model contains:

Coverpoints

cp_op

cp_a

cp_b

cp_carry

cp_rstn

Cross Coverage

Operation × A

Operation × B

Operation × Carry

Operation × A × B

Logical operations are excluded from the carry-set cross where carry is
not a meaningful output for those operations.

Final Functional Coverage

cp_op          100%
cp_a           100%
cp_b           100%
Cross Overall  100%
Overall        100%

Code Coverage

Code coverage was collected using Vivado XSIM.

The following metrics were enabled:

Statement coverage

Branch coverage

Condition coverage

Toggle coverage

The observed overall XSIM report included:

Line Coverage       92.3611%
Branch Coverage     100%
Condition Coverage  97.619%
Toggle Coverage     37.71%

The overall toggle score is affected by Vivado-generated glbl.v
infrastructure. The generated glbl.v contains global/JTAG-related
signals that are not part of the ALU verification target.

For the ALU RTL itself:

Branch Coverage     100%
Condition Coverage  100%
Statement Coverage  85.71%

The statement report showed uncovered structural case/begin/end
lines while the executable operation statements were exercised.

Therefore, the code coverage results were inspected rather than
increasing stimulus solely to chase an overall percentage.

Tools

SystemVerilog

Vivado

Vivado XSIM

SystemVerilog Assertions (SVA)

Functional Coverage

XSIM Code Coverage

Project Structure

A typical project organization is:

ALU_Verification/
│
├── README.md
│
├── rtl/
│   └── design.sv
│
└── tb/
    └── testbench.sv

The exact directory structure may vary depending on the Vivado project
organization.

Verification Results

Final functional verification achieved:

Generated stimulus : 524,288 exhaustive combinations
Scoreboard failures: 0
Functional coverage: 100%
Branch coverage    : 100%
Condition coverage : 100%

The testbench therefore exercised the complete defined ALU input space
and all defined functional scenarios without scoreboard mismatches.

Key Verification Concepts Demonstrated

This project was used to build a foundation in:

Class-based SystemVerilog

Transaction-based verification

Object-oriented testbench components

Virtual interfaces

Clocking blocks

Mailboxes

Events

Generator/Driver/Monitor architecture

Reference models

Scoreboards

Functional coverage

Cross coverage

SystemVerilog Assertions

$past() temporal checking

Exhaustive verification

XSIM code coverage

Coverage analysis

Reset verification

DUT/output latency handling

Lessons Learned

1. Functional coverage and code coverage are different

Functional coverage measures whether the intended scenarios were
exercised.

Code coverage measures which portions of the RTL and simulation code
were executed.

Both provide different information and should not be treated as
interchangeable.

2. Output latency must be considered in the monitor

Because the ALU registers its outputs, an observed output corresponds to
the input transaction from the previous clock cycle.

The monitor therefore needs to associate inputs and outputs according to
the DUT's timing rather than simply comparing values sampled at the same
edge.

3. Clocking blocks control synchronization

The testbench uses clocking blocks to define when signals are sampled
and driven, avoiding arbitrary procedural delays in the verification
components.

4. Coverage numbers need interpretation

A low overall code-coverage number does not automatically mean that the
DUT is poorly verified. Generated infrastructure such as glbl.v can
contribute to the reported score.

Coverage should be analyzed at the DUT level and uncovered items should
be investigated before adding unnecessary stimulus.

Future Improvements

Potential improvements to this project include:

Cleaner explicit termination of driver, monitor, and scoreboard
processes

More formal reset/pipeline flushing in the scoreboard

Clear separation of reset transactions from normal stimulus

Dedicated directed corner-case tests

Constraint-based random testing in addition to exhaustive testing

Multi-seed regression

Improved coverage configuration to focus reporting on the DUT

Additional code-coverage analysis

These improvements are useful extensions, but the current project
establishes the required verification fundamentals for moving to a more
complex DUT.
