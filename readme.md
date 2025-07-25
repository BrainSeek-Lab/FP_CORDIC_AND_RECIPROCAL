# Floating-Point CORDIC tanh(x) and Reciprocal Hardware Modules in Bluespec

A hardware implementation of mathematical functions using Bluespec SystemVerilog (BSV):
- **CORDIC Module**: Hyperbolic tangent (tanh) computation using the CORDIC algorithm
- **Reciprocal Calculator**: Floating-point reciprocal (1/x) using Newton-Raphson method

## Project Structure

```
├── cordic/                  # CORDIC hyperbolic tangent implementation
│   ├── CORDIC.bsv          # Main CORDIC module with range extension
│   ├── ROM.bsv             # Lookup table for atanh values
│   ├── ThresholdChecker.bsv # Input range validation
│   ├── GenericComparator.bsv # IEEE-754 floating-point comparator
│   └── test_cordic.bsv     # CORDIC testbench (27 test cases)
├── reciprocal/             # Reciprocal calculator implementation
│   ├── TopLevelSystem.bsv  # Main reciprocal system with Newton-Raphson
│   ├── FloatingPointExtractor.bsv # IEEE-754 parsing utilities
│   └── test_reciprocal.bsv # Reciprocal testbench (35 test cases)
└── Makefile               # Build automation
```

## Features

### CORDIC Module
- IEEE-754 single precision floating-point support
- Range extension using double angle formula for |x| ≥ 1.17
- 25 CORDIC iterations with automatic repeated iterations
- Comprehensive error handling

### Reciprocal Calculator
- Newton-Raphson algorithm with 3 iterations for high precision
- Special case handling (NaN, infinity, zero, denormals)
- Error tracking and system monitoring


## Quick Start

### Build and Run All Tests
```bash
make                    # Build and run both CORDIC and reciprocal tests
```

### Run Individual Tests
```bash
make test-cordic        # Build and run CORDIC test only
make test-reciprocal    # Build and run reciprocal test only
```

### Generate Verilog
```bash
make verilog           # Generate Verilog files for both modules
make verilog-cordic    # Generate CORDIC Verilog only
make verilog-reciprocal # Generate reciprocal Verilog only
```

## Test Coverage

### CORDIC Tests (27 cases)
- Basic values: 0.0, ±0.01, ±0.1, ±0.5, ±1.0
- Edge cases near convergence limit (1.118)
- Large values requiring range extension (±2.0, ±3.0, ±10.0, ±20.0)
- Saturation behavior verification

### Reciprocal Tests (35 cases)
- Normal floating-point values and their reciprocals
- Fractional inputs and negative values
- Special cases: NaN, ±infinity, ±zero
- Non-power-of-2 values for precision testing

## Interface Usage

### CORDIC Interface
```bsv
CORDIC dut <- mkCORDIC();
dut.setInput(input_float);           // Send input
let result <- dut.getOutput();       // Get tanh(input)
```

### Reciprocal Interface
```bsv
TopLevelSystem dut <- mkTopLevelSystem();
dut.process_fp_reciprocal(input_bits);  // Send 32-bit input
let result = dut.get_processed_output(); // Get 1/input
```

## Build System

The Makefile provides comprehensive build automation:

### Main Targets
- `make` or `make all` - Build and run both test suites
- `make test-cordic` - CORDIC test only
- `make test-reciprocal` - Reciprocal test only

### Verilog Generation
- `make verilog` - Generate all Verilog files
- `make verilog-cordic` - CORDIC modules only
- `make verilog-reciprocal` - Reciprocal modules only

### Cleaning
- `make clean` - Remove all build artifacts
- `make clean-cordic` - Clean CORDIC files only
- `make clean-reciprocal` - Clean reciprocal files only

### Help
- `make help` - Show all available targets and usage

## Output Files

Test results are automatically saved:
- `cordic_output.txt` - CORDIC test results
- `reciprocal_output.txt` - Reciprocal test results

Generated Verilog files are placed in:
- `verilog_cordic/` - CORDIC Verilog modules
- `verilog_reciprocal/` - Reciprocal Verilog modules

## Requirements

- Bluespec Compiler (bsc)
- Make utility


## Algorithm Details

### CORDIC Hyperbolic Mode
Uses iterative rotations: `x' = x + d*y*2^(-i)`, `y' = y + d*x*2^(-i)`
with range extension via double angle formula for convergence beyond |x| < 1.17.

### Newton-Raphson Reciprocal
Three-iteration Newton-Raphson: `Z_{n+1} = Z_n * (2 - D * Z_n)`
with initial approximation `Z_0 = (48/17) - (32/17) * D` for inputs normalized to [0.5, 1.0).
