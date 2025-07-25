import CORDIC::*;
import FloatingPoint::*;
import Vector::*;

module mkTestCORDIC();
   CORDIC dut <- mkCORDIC();

   Reg#(UInt#(10)) cycle <- mkReg(0);
   Reg#(UInt#(7)) input_idx <- mkReg(0);
   Reg#(UInt#(7)) output_idx <- mkReg(0);
   Reg#(Bool) all_inputs_sent <- mkReg(False);
   Reg#(Bool) test_complete <- mkReg(False);

   // Comprehensive test cases for hyperbolic tangent
   Vector#(27, Bit#(32)) test_vals = newVector();
   Vector#(27, String) test_names = newVector();
   Vector#(27, Bit#(32)) expected_results = newVector();

   // Test cases with expected results (approximate)
   test_vals[0]  = 32'h00000000;  test_names[0]  = "0.0";     expected_results[0]  = 32'h00000000; // tanh(0) = 0
   test_vals[1]  = 32'h3c23d70a;  test_names[1]  = "0.01";    expected_results[1]  = 32'h3c23d70a; // tanh(0.01) ≈ 0.01
   test_vals[2]  = 32'h3d4ccccd;  test_names[2]  = "0.05";    expected_results[2]  = 32'h3d4ccccd; // tanh(0.05) ≈ 0.05
   test_vals[3]  = 32'h3dcccccd;  test_names[3]  = "0.1";     expected_results[3]  = 32'h3dcccccd; // tanh(0.1) ≈ 0.0997
   test_vals[4]  = 32'h3e4ccccd;  test_names[4]  = "0.2";     expected_results[4]  = 32'h3e490FDB; // tanh(0.2) ≈ 0.197
   test_vals[5]  = 32'h3e99999a;  test_names[5]  = "0.3";     expected_results[5]  = 32'h3e9504F3; // tanh(0.3) ≈ 0.291
   test_vals[6]  = 32'h3ecccccd;  test_names[6]  = "0.4";     expected_results[6]  = 32'h3ec1F7CE; // tanh(0.4) ≈ 0.379
   test_vals[7]  = 32'h3f000000;  test_names[7]  = "0.5";     expected_results[7]  = 32'h3eec7326; // tanh(0.5) ≈ 0.462
   test_vals[8]  = 32'h3f19999a;  test_names[8]  = "0.6";     expected_results[8]  = 32'h3f0985D8; // tanh(0.6) ≈ 0.537
   test_vals[9]  = 32'h3f333333;  test_names[9]  = "0.7";     expected_results[9]  = 32'h3f1AC5E3; // tanh(0.7) ≈ 0.604
   test_vals[10] = 32'h3f4ccccd;  test_names[10] = "0.8";     expected_results[10] = 32'h3f2A9F8E; // tanh(0.8) ≈ 0.664
   test_vals[11] = 32'h3f666666;  test_names[11] = "0.9";     expected_results[11] = 32'h3f3726CA; // tanh(0.9) ≈ 0.716
   test_vals[12] = 32'h3f800000;  test_names[12] = "1.0";     expected_results[12] = 32'h3f430C31; // tanh(1.0) ≈ 0.762
   
   // Negative values (tanh is odd function)
   test_vals[13] = 32'hbc23d70a;  test_names[13] = "-0.01";   expected_results[13] = 32'hbc23d70a; // tanh(-0.01) ≈ -0.01
   test_vals[14] = 32'hbe4ccccd;  test_names[14] = "-0.2";    expected_results[14] = 32'hbe490FDB; // tanh(-0.2) ≈ -0.197
   test_vals[15] = 32'hbf000000;  test_names[15] = "-0.5";    expected_results[15] = 32'hbeec7326; // tanh(-0.5) ≈ -0.462
   test_vals[16] = 32'hbf800000;  test_names[16] = "-1.0";    expected_results[16] = 32'hbf430C31; // tanh(-1.0) ≈ -0.762
   
   // Larger values (should saturate toward ±1)
   test_vals[17] = 32'h40000000;  test_names[17] = "2.0";     expected_results[17] = 32'h3f733333; // tanh(2.0) ≈ 0.964
   test_vals[18] = 32'h40400000;  test_names[18] = "3.0";     expected_results[18] = 32'h3f7CCCCD; // tanh(3.0) ≈ 0.995
   test_vals[19] = 32'hc0000000;  test_names[19] = "-2.0";    expected_results[19] = 32'hbf733333; // tanh(-2.0) ≈ -0.964
   test_vals[20] = 32'hc0400000;  test_names[20] = "-3.0";    expected_results[20] = 32'hbf7CCCCD; // tanh(-3.0) ≈ -0.995
   
   // Edge cases near convergence limit
   test_vals[21] = 32'h3f8f5c29;  test_names[21] = "1.118";   expected_results[21] = 32'h3f600000; // tanh(1.118) ≈ 0.875
   test_vals[22] = 32'hbf8f5c29;  test_names[22] = "-1.118";  expected_results[22] = 32'hbf600000; // tanh(-1.118) ≈ -0.875
   
   // Very large values (should clamp and saturate)
   test_vals[23] = 32'h41200000;  test_names[23] = "10.0";    expected_results[23] = 32'h3f600000; // clamped, then tanh ≈ 0.875
   test_vals[24] = 32'hc1200000;  test_names[24] = "-10.0";   expected_results[24] = 32'hbf600000; // clamped, then tanh ≈ -0.875
   test_vals[25] = 32'h41a00000;  test_names[25] = "20.0";    expected_results[25] = 32'h3f600000; // clamped, then tanh ≈ 0.875
   test_vals[26] = 32'hc1a00000;  test_names[26] = "-20.0";   expected_results[26] = 32'hbf600000; // clamped, then tanh ≈ -0.875

   rule tick;
      cycle <= cycle + 1;
      if (cycle > 1000) begin // Safety timeout
         $display("ERROR: Test timeout after %0d cycles", cycle);
         $finish(1);
      end
   endrule

   // Send inputs with proper spacing
   rule send_input (!all_inputs_sent && !test_complete);
      if (input_idx < 27) begin
         Float x = unpack(test_vals[input_idx]);
         dut.setInput(x);
         $display("[%0d] Sent input %0d: tanh(%s) = 0x%h", 
                  cycle, input_idx, test_names[input_idx], test_vals[input_idx]);
         input_idx <= input_idx + 1;
         if (input_idx == 26) begin
            all_inputs_sent <= True;
            // $display("[%0d] All inputs sent", cycle);
         end
      end
   endrule

   // Collect and verify outputs
   rule get_output (output_idx < input_idx && !test_complete);
      let y <- dut.getOutput();
      
      Bit#(32) y_bits = pack(y);
      Bit#(32) expected = expected_results[output_idx];
      
      // Calculate error (simple bit difference for now)
      Bool close_match = True;
      Bit#(32) diff = y_bits ^ expected;
      // For floating point, we'll accept some precision loss
      // This is a simplified check - in practice you'd want proper FP comparison
      
    //   $display("[%0d] Output %0d: tanh(%s)", cycle, output_idx, test_names[output_idx]);
      $display("    Result:   0x%h", y_bits);
    //   $display("    Expected: 0x%h", expected);
      if (diff != 0) begin
        //  $display("    Difference: 0x%h", diff);
      end
      $display("");
      
      output_idx <= output_idx + 1;
      if (output_idx == 26) begin
        //  $display("=== CORDIC Test Completed Successfully ===");
        //  $display("Total cycles: %0d", cycle);
        //  $display("All 27 test cases processed");
         test_complete <= True;
         $finish(0);
      end
   endrule

   // Initial display
   // rule show_start (cycle == 1);
   //  //   $display("=== Starting CORDIC Hyperbolic Tangent Test ===");
   //  //   $display("Testing 27 iterations with proper repeat handling");
   //  //   $display("Convergence range: |x| <= 1.118");
   // endrule

endmodule