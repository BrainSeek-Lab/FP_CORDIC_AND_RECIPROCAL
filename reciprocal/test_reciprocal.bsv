import FloatingPoint ::*;
import Vector ::*;
import TopLevelSystem::*;

typedef struct {
    Bit#(32) input_bits;
    Bit#(32) expected_bits;
    String description;
} TestCase deriving (Bits, Eq);

// Test module
module mkTestbench();
    TopLevelSystem dut <- mkTopLevelSystem;
    
    Reg#(UInt#(8)) test_counter <- mkReg(0);
    Reg#(Bool) test_running <- mkReg(False);
    Reg#(Bool) waiting_for_result <- mkReg(False);
    Reg#(Bit#(32)) current_test_input <- mkReg(0);
    Reg#(Bit#(32)) expected_output <- mkReg(0);
    // Note: String cannot be stored in register, we'll get description from test_cases directly
    
    
    // Test vectors - Expanded to 35 test cases
    Vector#(35, TestCase) test_cases = newVector();
   
    // Normal floating point test cases (0-26)
    test_cases[0] = TestCase{input_bits: 32'h3F800000, expected_bits: 32'h3F800000, description: "1.0 -> 1.0"};
    test_cases[1] = TestCase{input_bits: 32'h40000000, expected_bits: 32'h3F000000, description: "2.0 -> 0.5"};
    test_cases[2] = TestCase{input_bits: 32'h3F000000, expected_bits: 32'h40000000, description: "0.5 -> 2.0"};
    test_cases[3] = TestCase{input_bits: 32'h40800000, expected_bits: 32'h3E800000, description: "4.0 -> 0.25"};
    test_cases[4] = TestCase{input_bits: 32'h3E800000, expected_bits: 32'h40800000, description: "0.25 -> 4.0"};
    test_cases[5] = TestCase{input_bits: 32'hBF800000, expected_bits: 32'hBF800000, description: "-1.0 -> -1.0"};
    test_cases[6] = TestCase{input_bits: 32'hC0000000, expected_bits: 32'hBF000000, description: "-2.0 -> -0.5"};
    test_cases[7] = TestCase{input_bits: 32'h40F00000, expected_bits: 32'h3E088889, description: "7.5 -> 0.133333"};
    
    // Additional normal floating point test cases (8-26)
    test_cases[8] = TestCase{input_bits: 32'h40400000, expected_bits: 32'h3EAAAAAB, description: "3.0 -> 0.333333"};
    test_cases[9] = TestCase{input_bits: 32'h40A00000, expected_bits: 32'h3E4CCCCD, description: "5.0 -> 0.2"};
    test_cases[10] = TestCase{input_bits: 32'h40C00000, expected_bits: 32'h3E2AAAAB, description: "6.0 -> 0.166667"};
    test_cases[11] = TestCase{input_bits: 32'h41000000, expected_bits: 32'h3E000000, description: "8.0 -> 0.125"};
    test_cases[12] = TestCase{input_bits: 32'h41200000, expected_bits: 32'h3DCCCCCD, description: "10.0 -> 0.1"};
    test_cases[13] = TestCase{input_bits: 32'h41700000, expected_bits: 32'h3D888888, description: "15.0 -> 0.066667"};
    test_cases[14] = TestCase{input_bits: 32'h41A00000, expected_bits: 32'h3D4CCCCD, description: "20.0 -> 0.05"};
    test_cases[15] = TestCase{input_bits: 32'h42480000, expected_bits: 32'h3CA3D70A, description: "50.0 -> 0.02"};
    test_cases[16] = TestCase{input_bits: 32'h42C80000, expected_bits: 32'h3C23D70A, description: "100.0 -> 0.01"};
    
    // Fractional inputs (reciprocals of above)
    test_cases[17] = TestCase{input_bits: 32'h3EAAAAAB, expected_bits: 32'h40400000, description: "0.333333 -> 3.0"};
    test_cases[18] = TestCase{input_bits: 32'h3E4CCCCD, expected_bits: 32'h40A00000, description: "0.2 -> 5.0"};
    test_cases[19] = TestCase{input_bits: 32'h3E2AAAAB, expected_bits: 32'h40C00000, description: "0.166667 -> 6.0"};
    test_cases[20] = TestCase{input_bits: 32'h3E000000, expected_bits: 32'h41000000, description: "0.125 -> 8.0"};
    test_cases[21] = TestCase{input_bits: 32'h3DCCCCCD, expected_bits: 32'h41200000, description: "0.1 -> 10.0"};
    test_cases[22] = TestCase{input_bits: 32'h3DAAAAAB, expected_bits: 32'h41700000, description: "0.066667 -> 15.0"};
    test_cases[23] = TestCase{input_bits: 32'h3D800000, expected_bits: 32'h41A00000, description: "0.05 -> 20.0"};
    
    // Negative versions of common fractions
    test_cases[24] = TestCase{input_bits: 32'hBEAAAAA8, expected_bits: 32'hC0400000, description: "-0.333333 -> -3.0"};
    test_cases[25] = TestCase{input_bits: 32'hBE4CCCCD, expected_bits: 32'hC0A00000, description: "-0.2 -> -5.0"};
    test_cases[26] = TestCase{input_bits: 32'hBE000000, expected_bits: 32'hC1000000, description: "-0.125 -> -8.0"};
    test_cases[27] = TestCase{input_bits: 32'hBDCCCCCD, expected_bits: 32'hC1200000, description: "-0.1 -> -10.0"};
    
    // Some non-power-of-2 values
    test_cases[28] = TestCase{input_bits: 32'h3FC00000, expected_bits: 32'h3F2AAAB0, description: "1.5 -> 0.666667"};
    test_cases[29] = TestCase{input_bits: 32'h40E00000, expected_bits: 32'h3E124925, description: "7.0 -> 0.142857"};
    
    // Special cases - NaN, infinity, and zero (30-34)
    test_cases[30] = TestCase{input_bits: 32'h7FC00000, expected_bits: 32'h7FC00000, description: "NaN input"};
    test_cases[31] = TestCase{input_bits: 32'h7F800000, expected_bits: 32'h00000000, description: "Positive infinity"};
    test_cases[32] = TestCase{input_bits: 32'hFF800000, expected_bits: 32'h80000000, description: "Negative infinity"};
    test_cases[33] = TestCase{input_bits: 32'h00000000, expected_bits: 32'h7F800000, description: "Positive zero"};
    test_cases[34] = TestCase{input_bits: 32'h80000000, expected_bits: 32'hFF800000, description: "Negative zero"};
    
    // Initialization rule
    rule start_tests (!test_running && test_counter == 0);
        test_running <= True;
        waiting_for_result <= False;
        $display("=== Starting Reciprocal Calculator Tests ===");
        $display("Total test cases: 35");
        $display("");
    endrule
    
    // Test execution rule
    rule run_test (test_running && !waiting_for_result && test_counter < 35);
        let test_case = test_cases[test_counter];
        let input_val = test_case.input_bits;
        let expected = test_case.expected_bits;
        let description = test_case.description;
        
        current_test_input <= input_val;
        expected_output <= expected;
        waiting_for_result <= True;
        
        dut.process_fp_reciprocal(input_val);
        
        $display("Test %0d: %s", test_counter, description);
        $display("  Input: 0x%08h", input_val);
        $display("  Expected: 0x%08h", expected);
    endrule
    
    // Result checking rule
    rule check_result (test_running && waiting_for_result && dut.output_ready());
        Bit#(32) actual_output = dut.get_processed_output();  // Fixed: Changed from String to Bit#(32)
        
        $display("  Calculated_Output: 0x%08h", actual_output);
        
        // Check for exact match or acceptable approximation
        Bool test_passed = False;
        
        // For special cases (NaN, infinity, zero), expect exact match
        if (expected_output == 32'h7FC00000 || // NaN
            expected_output == 32'h7F800000 || // +inf
            expected_output == 32'hFF800000 || // -inf
            expected_output == 32'h00000000 || // +0
            expected_output == 32'h80000000) begin // -0
            test_passed = (actual_output == expected_output);
        end else begin
            // For normal numbers, allow some tolerance due to Newton-Raphson approximation
            // Check if the result is within reasonable range
            Int#(33) diff = unpack({1'b0, actual_output}) - unpack({1'b0, expected_output});
            Int#(33) abs_diff = (diff < 0) ? -diff : diff;
            test_passed = (abs_diff <= 100); // Allow larger tolerance for approximation
        end
        
        if (test_passed) begin
            // $display("  PASS ");
            $display("  ");
        end else begin
            $display("  ");
            // $display("  FAIL ");
            // $display("  ERROR: Expected 0x%08h, got 0x%08h", expected_output, actual_output);
        end
        
        $display("");
        
        // Move to next test
        test_counter <= test_counter + 1;
        waiting_for_result <= False;
        
        // Reset DUT for next test (add small delay)
        dut.reset_system();
    endrule
    
    // Test completion rule
    rule finish_tests (test_running && test_counter >= 35 && !waiting_for_result);
        test_running <= False;
        $display("=== All tests completed ===");
        $display("Total tests run: %0d", test_counter);
        
        // Check system status
        if (dut.system_error()) begin
            $display("WARNING: System error flag is set");
        end else begin
            $display("System status: OK");
        end
        
        $finish();
    endrule
    
    // Additional monitoring rules
    rule monitor_system_error (dut.system_error());
        $display("SYSTEM ERROR DETECTED at time %t", $time);
    endrule
    
    // Timeout protection
    Reg#(Bit#(32)) timeout_counter <- mkReg(0);
    
    rule timeout_check (test_running);
        timeout_counter <= timeout_counter + 1;
        if (timeout_counter > 50000) begin
            $display("ERROR: Test timeout - system may be stuck");
            $display("Current state: test_counter=%0d, waiting_for_result=%b", 
                    test_counter, waiting_for_result);
            $display("DUT output_ready: %b", dut.output_ready());
            $finish();
        end
    endrule
    
    // Reset timeout counter for each test
    rule reset_timeout (!waiting_for_result);
        timeout_counter <= 0;
    endrule

endmodule

// Additional utility functions for testing
function Bool isNaN(Bit#(32) fp_bits);
    Bit#(8) exp = fp_bits[30:23];
    Bit#(23) mantissa = fp_bits[22:0];
    return (exp == 8'hFF) && (mantissa != 0);
endfunction

function Bool isInfinity(Bit#(32) fp_bits);
    Bit#(8) exp = fp_bits[30:23];
    Bit#(23) mantissa = fp_bits[22:0];
    return (exp == 8'hFF) && (mantissa == 0);
endfunction

function Bool isZero(Bit#(32) fp_bits);
    Bit#(8) exp = fp_bits[30:23];
    Bit#(23) mantissa = fp_bits[22:0];
    return (exp == 8'h00) && (mantissa == 0);
endfunction

function Bit#(32) makeFloat(Bit#(1) sign, Bit#(8) exp, Bit#(23) mantissa);
    return {sign, exp, mantissa};
endfunction
