package CORDIC;

import FloatingPoint::*;
import Vector::*;
import ROM::*;
import ThresholdChecker::*;

/*
 * CORDIC Hyperbolic Module for tanh(x) Computation
 * 
 * This module implements the hyperbolic CORDIC algorithm to compute tanh(x)
 * using iterative rotations in hyperbolic coordinate space.
 * 
 * Key Features:
 * - Direct computation for |x| < 1.17 (convergence radius)
 * - Range extension using double angle formula for larger inputs
 * - 25 CORDIC iterations with repeated iterations at positions 4 and 13
 * - IEEE-754 single precision floating point arithmetic
 * 
 * Algorithm Overview:
 * 1. Check if input is within CORDIC convergence radius (~1.17)
 * 2. If outside range, use x/2 and apply double angle formula later
 * 3. Perform hyperbolic CORDIC iterations: x' = x + d*y*2^(-i)
 *                                         y' = y + d*x*2^(-i)  
 *                                         z' = z - d*atanh(2^(-i))
 * 4. Result is tanh(original_input) = y_final / x_final
 * 5. Apply double angle formula if range extension was used
 */

// Interface definition - simple input/output for tanh computation
interface CORDIC;
   method Action setInput(Float x);        // Input: x value for tanh(x)
   method ActionValue#(Float) getOutput(); // Output: tanh(x) result
endinterface

module mkCORDIC(CORDIC);

   // =================================================================
   // CONSTANTS AND CONFIGURATION
   // =================================================================
   
   // Total iterations needed: 25 normal + 2 repeated = 27 total
   // Iterations 4 and 13 are repeated in hyperbolic CORDIC for convergence
   Integer num_iterations = 27;
   
   // =================================================================
   // STATE REGISTERS
   // =================================================================
   
   // Input/Output flow control
   Reg#(Maybe#(Float)) in_val  <- mkReg(tagged Invalid);  // Pending input
   Reg#(Maybe#(Float)) out_val <- mkReg(tagged Invalid);  // Computed result
   
   // Computation state tracking
   Reg#(Bool) computing <- mkReg(False);                   // Currently computing flag
   Reg#(UInt#(6)) iteration_step <- mkReg(0);             // Current iteration (0-26)
   Reg#(UInt#(6)) rom_index <- mkReg(0);                  // ROM lookup index (0-24)
   
   // Range extension control
   Reg#(Bool) need_double_angle <- mkReg(False);          // Flag: apply double angle formula
   
   // External modules
   ThresholdChecker checker <- mkThresholdChecker();      // Checks if |x| < 1.17
   
   // =================================================================
   // CORDIC LOOKUP TABLES
   // =================================================================
   
   // Power table: 2^(-i-1) values for CORDIC shift operations
   // Used in: x' = x ± y * 2^(-i-1), y' = y ± x * 2^(-i-1)
   Vector#(25, Bit#(32)) power_table = newVector();
   power_table[0]  = 32'h3F000000; // 2^-1 = 0.5
   power_table[1]  = 32'h3E800000; // 2^-2 = 0.25  
   power_table[2]  = 32'h3E000000; // 2^-3 = 0.125
   power_table[3]  = 32'h3D800000; // 2^-4 = 0.0625
   power_table[4]  = 32'h3D000000; // 2^-5 = 0.03125
   power_table[5]  = 32'h3C800000; // 2^-6 = 0.015625
   power_table[6]  = 32'h3C000000; // 2^-7 = 0.0078125
   power_table[7]  = 32'h3B800000; // 2^-8 = 0.00390625
   power_table[8]  = 32'h3B000000; // 2^-9 = 0.001953125
   power_table[9]  = 32'h3A800000; // 2^-10 = 0.0009765625
   power_table[10] = 32'h3A000000; // 2^-11 = 0.00048828125
   power_table[11] = 32'h39800000; // 2^-12 = 0.000244140625
   power_table[12] = 32'h39000000; // 2^-13 = 0.0001220703125
   power_table[13] = 32'h38800000; // 2^-14 = 6.103515625e-05
   power_table[14] = 32'h38000000; // 2^-15 = 3.0517578125e-05
   power_table[15] = 32'h37800000; // 2^-16 = 1.52587890625e-05
   power_table[16] = 32'h37000000; // 2^-17 = 7.62939453125e-06
   power_table[17] = 32'h36800000; // 2^-18 = 3.814697265625e-06
   power_table[18] = 32'h36000000; // 2^-19 = 1.9073486328125e-06
   power_table[19] = 32'h35800000; // 2^-20 = 9.5367431640625e-07
   power_table[20] = 32'h35000000; // 2^-21 = 4.76837158203125e-07
   power_table[21] = 32'h34800000; // 2^-22 = 2.384185791015625e-07
   power_table[22] = 32'h34000000; // 2^-23 = 1.1920928955078125e-07
   power_table[23] = 32'h33800000; // 2^-24 = 5.960464477539063e-08
   power_table[24] = 32'h33000000; // 2^-25 = 2.9802322387695312e-08
   
   // Storage for all iteration results - stores (x,y,z) triple for each step
   Reg#(Vector#(28, Tuple3#(Float, Float, Float))) iterations <- mkReg(newVector());

   // ROM containing atanh(2^(-i)) values for angle accumulation
   ROM_IFC atanh_rom <- mkROM();

   // =================================================================
   // MATHEMATICAL CONSTANTS
   // =================================================================
   
   // CORDIC gain factor: K = ∏(sqrt(1 - 2^(-2i-2))) ≈ 1.207
   // Applied to initial x value to compensate for algorithm scaling
   Float cordic_gain = unpack(32'h3F540240);
   
   // Common floating point constants
   Float zero = fromReal(0.0);
   Float one = fromReal(1.0);
   Float neg_one = fromReal(-1.0);
   Float two = fromReal(2.0);
   Float half = fromReal(0.5);

   // =================================================================
   // HELPER FUNCTIONS
   // =================================================================
   
   /*
    * Determines if current ROM index should be repeated
    * In hyperbolic CORDIC, certain iterations must be performed twice
    * for proper convergence: specifically iterations 4 and 13 (0-indexed: 3 and 12)
    */
   function Bool shouldRepeat(UInt#(6) rom_idx);
      return (rom_idx == 3 || rom_idx == 12);
   endfunction

   // =================================================================
   // COMPUTATION RULES
   // =================================================================

   /*
    * RULE: start_computation
    * 
    * Triggered when: New input available, no computation in progress, no output pending
    * 
    * Purpose: Initialize CORDIC computation
    * 1. Check if input magnitude is within convergence radius (~1.17)
    * 2. If outside range, use x/2 as CORDIC input and set double angle flag
    * 3. Initialize CORDIC state: x₀ = K (gain), y₀ = 0, z₀ = input
    * 4. Start iteration process
    */
   rule start_computation (in_val matches tagged Valid .xin &&& !isValid(out_val) &&& !computing);
      // Check if input magnitude is within CORDIC convergence radius
      Bool within_range = checker.isLessThan1_17(pack(xin));
      
      Float cordic_input;
      if (within_range) begin
         // Input is small enough - use directly with CORDIC
         cordic_input = xin;
         need_double_angle <= False;
      end else begin
         // Input too large - use range extension
         // Compute tanh(x/2) first, then apply double angle formula: tanh(x) = 2*tanh(x/2)/(1+tanh²(x/2))
         let half_mult = multFP(xin, half, defaultValue);
         cordic_input = tpl_1(half_mult);
         need_double_angle <= True;
      end

      // Initialize CORDIC algorithm state
      // x₀ = CORDIC gain factor (compensates for algorithm scaling)
      // y₀ = 0 (will accumulate to sinh component)  
      // z₀ = target value (will be driven to zero)
      Float x_init = cordic_gain;
      Float y_init = zero;
      Float z_init = cordic_input;

      // Store initial state and prepare for iterations
      Vector#(28, Tuple3#(Float, Float, Float)) init_iterations = newVector();
      init_iterations[0] = tuple3(x_init, y_init, z_init);
      iterations <= init_iterations;
      
      // Reset iteration counters and start computing
      iteration_step <= 0;
      rom_index <= 0;
      computing <= True;
   endrule

   /*
    * RULE: perform_iteration
    * 
    * Triggered when: Currently computing and haven't completed all iterations
    * 
    * Purpose: Execute one CORDIC iteration
    * 1. Determine rotation direction based on z sign
    * 2. Perform hyperbolic rotation: x' = x + d*y*2^(-i), y' = y + d*x*2^(-i)
    * 3. Update angle accumulator: z' = z - d*atanh(2^(-i))
    * 4. Handle repeated iterations (at positions 4 and 13)
    * 
    * The algorithm converges such that z approaches 0 and y/x approaches tanh(original_z)
    */
   rule perform_iteration (computing && iteration_step < fromInteger(num_iterations));
      // Get current state
      UInt#(6) step = iteration_step;
      UInt#(6) rom_idx = rom_index;
      Vector#(28, Tuple3#(Float, Float, Float)) curr_iterations = iterations;
      
      // Extract current x, y, z values
      let curr = curr_iterations[step];
      Float curr_x = tpl_1(curr);  // Current x coordinate (cosh component)
      Float curr_y = tpl_2(curr);  // Current y coordinate (sinh component)  
      Float curr_z = tpl_3(curr);  // Current angle residual

      // Determine rotation direction based on z sign
      // If z > 0: rotate to reduce z (d = +1)
      // If z < 0: rotate in opposite direction (d = -1)
      Bit#(32) z_bits = pack(curr_z);
      Bool is_negative = (z_bits[31] == 1'b1);
      Float d = is_negative ? neg_one : one;

      // Get scaling factor for this iteration: 2^(-i-1)
      Float power = unpack(power_table[rom_idx]);
      
      // Get angle decrement from ROM: atanh(2^(-i-1))
      Bit#(32) dz_bits = atanh_rom.read(pack(truncate(rom_idx)));
      Float dz = unpack(dz_bits);

      // Compute coordinate updates
      // dx = y * 2^(-i-1) (scaled y component to add to x)
      let dx_mult = multFP(curr_y, power, defaultValue);
      Float dx = tpl_1(dx_mult);
      
      // dy = x * 2^(-i-1) (scaled x component to add to y)
      let dy_mult = multFP(curr_x, power, defaultValue);
      Float dy = tpl_1(dy_mult);

      // Apply rotation direction
      let dx_d_mult = multFP(d, dx, defaultValue);
      Float dx_d = tpl_1(dx_d_mult);
      
      let dy_d_mult = multFP(d, dy, defaultValue);
      Float dy_d = tpl_1(dy_d_mult);
      
      let dz_d_mult = multFP(d, dz, defaultValue);
      Float dz_d = tpl_1(dz_d_mult);

      // Update coordinates using hyperbolic CORDIC equations
      // x_{i+1} = x_i + d_i * y_i * 2^(-i-1)
      let x_new_add = addFP(curr_x, dx_d, defaultValue);
      Float x_new = tpl_1(x_new_add);
      
      // y_{i+1} = y_i + d_i * x_i * 2^(-i-1)  
      let y_new_add = addFP(curr_y, dy_d, defaultValue);
      Float y_new = tpl_1(y_new_add);
      
      // z_{i+1} = z_i - d_i * atanh(2^(-i-1))
      let z_new_sub = addFP(curr_z, negate(dz_d), defaultValue);
      Float z_new = tpl_1(z_new_sub);

      // Store results and advance to next iteration
      curr_iterations[step + 1] = tuple3(x_new, y_new, z_new);
      iterations <= curr_iterations;
      iteration_step <= step + 1;
      
      // Handle repeated iterations logic
      // Iterations 4 and 13 (rom_idx 3 and 12) must be performed twice
      if (shouldRepeat(rom_idx) && step < fromInteger(num_iterations - 1)) begin
         if ((rom_idx == 3 && step != 4) || (rom_idx == 12 && step != 16)) begin
            // First use of this ROM entry - don't advance ROM index yet
         end else begin
            // Second use complete - advance to next ROM entry
            rom_index <= rom_idx + 1;
         end
      end else begin
         // Normal iteration - advance ROM index
         rom_index <= rom_idx + 1;
      end
   endrule

   /*
    * RULE: finish_computation
    * 
    * Triggered when: All iterations complete
    * 
    * Purpose: Extract final result and apply range extension if needed
    * 1. Compute tanh = y_final / x_final (basic CORDIC result)
    * 2. If range extension was used, apply double angle formula
    * 3. Store result for output
    * 4. Reset computation state
    */
   rule finish_computation (computing && iteration_step >= fromInteger(num_iterations));
      // Get final iteration results
      Vector#(28, Tuple3#(Float, Float, Float)) final_iterations = iterations;
      let final_vals = final_iterations[num_iterations];
      Float final_x = tpl_1(final_vals);  // Final cosh component
      Float final_y = tpl_2(final_vals);  // Final sinh component

      // Compute basic tanh result: tanh = sinh/cosh = y/x
      let tanh_div = divFP(final_y, final_x, defaultValue);
      Float tanh_result = tpl_1(tanh_div);
      
      Float final_result;
      if (need_double_angle) begin
         // Apply double angle formula: tanh(x) = 2*tanh(x/2) / (1 + tanh²(x/2))
         // We computed tanh(x/2), now need to get tanh(x)
         let tanh_sq = multFP(tanh_result, tanh_result, defaultValue);      // tanh²(x/2)
         let denom = addFP(one, tpl_1(tanh_sq), defaultValue);              // 1 + tanh²(x/2)
         let numer = multFP(two, tanh_result, defaultValue);                // 2*tanh(x/2)
         let final_div = divFP(tpl_1(numer), tpl_1(denom), defaultValue);   // Final division
         final_result = tpl_1(final_div);
      end else begin
         // No range extension needed - use CORDIC result directly
         final_result = tanh_result;
      end
      
      // Store result and reset computation state
      out_val <= tagged Valid final_result;
      computing <= False;
      iteration_step <= 0;
      rom_index <= 0;
      need_double_angle <= False;
   endrule

   // =================================================================
   // INTERFACE METHODS
   // =================================================================

   /*
    * setInput: Accept new input for tanh computation
    * Condition: No pending input and not currently computing
    */
   method Action setInput(Float x) if (!isValid(in_val) && !computing);
      in_val <= tagged Valid x;
   endmethod

   /*
    * getOutput: Return computed tanh result
    * Condition: Result is ready and computation is complete
    * Side effect: Clears both input and output, ready for next computation
    */
   method ActionValue#(Float) getOutput() if (out_val matches tagged Valid .y &&& !computing);
      out_val <= tagged Invalid;
      in_val <= tagged Invalid;
      return y;
   endmethod

endmodule

endpackage