# AMBA AHB-Lite Multi-Slave Bus Interconnect & Pipelined Controller Core

A synthesis-ready, parameterizable AMBA AHB-Lite (Advanced High-performance Bus) subsystem implemented in Verilog HDL. This architecture features a master pipelined engine capable of orchestrating complex burst types (Single, Incrementing, Wrapping, and Undefined-length bursts) across a multi-slave fabric managed by a centralized combinational address decoder and response multiplexer network.

---

## Technical Specifications & Protocol Features

* **Memory Data Bus Configuration**: 32-bit Pipelined Data Width (`DataWidth = 32`).
* **System Address Bus Configuration**: 32-bit Parameterized Address Width (`AddressWidth = 32`).
* **Central Address Space Allocation**: Mapped through an independent combinational decoder splitting 1 KB memory segment boundaries per slave (`Depth = 1024` bytes):
  * **`slave_0`**: `32'h0000_0000` to `32'h0000_03FF`
  * **`slave_1`**: `32'h0000_0400` to `32'h0000_07FF`
  * **`slave_2`**: `32'h0000_0800` to `32'h0000_0BFF`
  * **`default_slave`**: Catches out-of-range memory spaces (`>= 32'h0000_0C00`) to guarantee robust bus safety flags.
* **Supported Burst Typologies**: Handles standard AMBA definitions: `SINGLE`, `INCR`, `WRAP4`, `INCR4`, `WRAP8`, `INCR8`, `WRAP16`, and `INCR16`.
* **Supported Transfer Sizes**: Configurable structural indexing for `BYTE` (8-bit), `HALFWORD` (16-bit), and `WORD` (32-bit) boundaries.

---

The design enforces an explicit split between address/control and data phases, leveraging latched tracking registers to handle zero-wait-state pipelining:

### 1. Master Controller Engine (`master.v`)
Driven by a multi-state operational Finite State Machine (FSM) containing state registers: `idle`, `start`, `addr_transfer1`, `addr_transfer2`, `transfer`, `waitReady`, `error_state`, `lock_idle`, and `done_s`. 
* Automatically computes sequential address offsets (`Next_Address`) for incrementing and wrapping schemes.
* Features byte lane mirroring and alignment controls to format `BYTE` and `HALFWORD` sequences across the 32-bit data lane (`HWdata`) depending on lower address boundary bits (`HAddr_reg[1:0]`).
* Evaluates `HMastlock_req` parameters to hold the interconnect infrastructure safely in a locked state, shifting out to `lock_idle` during qualified burst terminations.

### 2. Central Address Decoder (`decoder.v`)
An absolute combinational block parsing upper-tier address bits (`HAddr[31:10]`). It matches access cycles against predefined slave spaces, generating isolated individual select lines (`HSel[2:0]`) or triggering the global system `HSel_default` line if a master attempts to access unmapped territory.

### 3. Integrated Response Multiplexer (`mux.v`)
Routinely aggregates parallel incoming status parameters (`HRdataX`, `HRespX`, and `HReadyOutX`) from the selected hardware component. Uses combinational select mapping logic to pass data back to the master engine without propagation bottlenecks.

### 4. Parametric Slaves & Error-Trap Memory Engines (`slave_0.v`, `slave_1.v`, `slave_2.v`, `default_slave.v`)
* Real Slaves embed a three-state operational framework (`RESP_IDLE`, `RESP_READWAIT`, `RESP_ERR2`).
* Implements address range checking (`addr_in_range`) and alignment checking logic (`misaligned`). If an illegal address or misaligned width allocation occurs, the slave automatically inserts an error response sequence (`HResp = 1'b1`) backed by a multi-cycle two-phase low ready signal (`HReadyOut = 1'b0`) to abort faulty operations safely.
* Includes an engineering bugfix that gates active memory writing with `valid_transfer` status signals to prevent lingering registers from triggering phantom data corruption during idle cycles.
* The `default_slave` acts as a protocol catchall, returning a strict 2-cycle standard `ERROR` handshake whenever unmapped addresses are selected.

---

## Complete Verification & Testcase Matrix

The simulation environment (`AHB_top_tb.v`, `master_tb.v`, and `slave_tb.v`) contains comprehensive verification structures utilizing automated task models to evaluate performance under realistic bus traffic conditions:

### 1. Standalone Master Subsystem Testcases (`master_tb.v`)
* **Test 1: Even Address Single Byte Handshake**: Exercises individual 8-bit memory operations on base addresses to check basic write/read cycles.
* **Test 2: Odd Address Single Byte Access**: Asserts single-byte tasks on shifted boundaries (`0x0000_0001`) to verify data lane shifting accuracy.
* **Test 3: Pipelined `WRAP4` Word Array Burst**: Dispatches a 4-beat wrapping word payload across address `0x0000_0004` to verify proper address inversion routing.
* **Test 4: Interleaved `WRAP8` Halfword Execution**: Focuses on sub-word structural wrapping bursts, cross-checking that upper/lower data lanes match cleanly.
* **Test 5: Complex `WRAP16` Continuous Byte Sweep**: Pushes the system to high transition densities by checking full 16-beat byte wrapping structures.
* **Test 6: Pipelined `INCR4` Sequential Processing**: Simulates basic continuous memory increments across boundary points.
* **Test 7: Extended `INCR8` Multi-Word Protocol Stress**: Floods the 32-bit line with successive increment data chunks to evaluate back-to-back bandwidth.
* **Test 8: High-Density `INCR16` Halfword Pipeline**: Validates pipeline performance over 16 continuous halfword data transitions.
* **Test 9: Dynamic Undefined Length Burst (`INCR` Type)**: Emulates custom processor access behavior by using an unpredictable runtime length sequence (`beats_req = 8'd5`).
* **Test 10: Asynchronous Mid-Burst Pipeline Reset**: Forces a hardware reset pulse directly during active burst phases to confirm the core clears internal registers and avoids bus locks.
* **Test 11: Active Post-Reset Pipeline Recovery**: Resumes operations immediately following an abrupt shutdown phase to verify standard initialization stability.
* **Test 12: Locked Interconnect Performance (`HMastlock`)**: Drives high-priority master sequences with atomic bus assertions enabled to ensure uninterrupted transaction execution.

### 2. Standalone Slave Subsystem Testcases (`slave_tb.v`)
The standalone slave environment isolates a single 1 KB memory block and pushes boundary protocols using an autonomous dual-memory scoring system (`ref_mem`):
* **Test 1: Core Initialized Reset Phase**: Pulses `HResetn` low to guarantee the slave defaults to an active handshake response (`HReadyOut = 1`) and a clean status line (`HResp = 0`).
* **Test 2: Standalone Byte Extraction Write**: Initiates an 8-bit broadside push onto coordinate `0` to confirm local buffer array latching accuracy.
* **Test 3: Standalone Byte Extraction Read**: Asserts a follow-up read sequence to verify data holds firmly in memory address index zero.
* **Test 4: Out-of-Bounds Error Protocol Trap**: Forces an illegal address access (`32'd111111111`) to test the 2-cycle protocol failure mechanism, confirming `HResp` accurately pulses high while `HReadyOut` drives low on cycle 1 before stepping back up on cycle 2.
* **Test 5: Pipelined Continuous Halfword Write**: Streams consecutive 16-bit halfword structures directly across shifted addresses (`32'd2`, `32'd4`, `32'd6`) without inserting clock gaps.
* **Test 6: Pipelined Continuous Halfword Read**: Validates zero-gap pipelined retrieval across back-to-back halfword indexes using automated verification lookups.
* **Test 7: Deselected Idle Handshake Recovery**: Drops the slave select pin (`HSel = 0`) during live activity to ensure the hardware maintains high impedance responses without loading the active interconnect line.
* **Test 8: High Boundary Word Boundary Write**: Pushes a full 32-bit structure into the final 4-byte threshold of the memory block (`32'd1020`) to verify upper address limit safety.
* **Test 9: High Boundary Word Boundary Read**: Pulls data back from index `1020` to guarantee memory cells survive ceiling allocations without dropping bits.
* **Test 10: Misaligned Address Strobe Violation**: Re-injects a halfword layout targeted at an uneven byte lane boundary (`32'd5`) to verify that the core misaligned-decoder successfully traps the error and throws an AMBA protocol abort.
* **Test 11: Wait-State Bus Hold Validation**: Drops the master ready control network line (`HReady = 0`) to verify that the internal address tracking structures freeze identically without dropping data states.
* **Test 12 & 13: High-Throughput Tight Back-to-Back Arrays**: Combines back-to-back `NONSEQ` and `SEQ` 32-bit processing blocks across write/read boundaries to prove high-throughput capabilities.

### 3. Top-Level Interconnect Integration Testcases (`AHB_top_tb.v`)
* **Top System Test 1**: Validates single-byte operations targeting `slave_0`.
* **Top System Test 2**: Verifies halfword execution cycles targeting memory spaces inside `slave_1`.
* **Top System Test 3**: Executes 32-bit word verification routines targeting structures inside `slave_2`.
* **Top System Test 4 (Address Range Violation Trap)**: Fires a write operation to out-of-bounds space `32'h0001_0000` to confirm the decoder isolates the request and activates the default slave safety routine.
* **Top System Test 5 (Interleaved Cross-Slave Bursting)**: Floods the fabric with a `WRAP4` burst to `slave_0` followed immediately by an `INCR8` burst to `slave_1` to verify zero-cycle stall transitions between different devices.
* **Top System Test 6 (Custom Variable-Length Bursting)**: Asserts a user-defined length incrementing burst (`beats_req = 6`) into `slave_2` to test structural flexibility.

---
