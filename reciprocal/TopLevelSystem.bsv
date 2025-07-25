package TopLevelSystem;
import FloatingPoint ::*;
import FloatingPointExtractor ::*;

// Top-level system interface - simplified for reciprocal (1/x)
interface TopLevelSystem;
    method Action process_fp_reciprocal(Bit#(32) input_value);
    method Bit#(32) get_processed_output();
    method Bool output_ready();
    method Bool system_error();
    method Action reset_system();
endinterface

// Processing states for multi-cycle operations
typedef enum {
    IDLE,
    EXTRACTING_INPUT,
    COMPUTING_RECIPROCAL,
    COMPLETE
} ProcessingState deriving (Bits, Eq);

// Top-level module that implements Newton-Raphson reciprocal (1/x)
module mkTopLevelSystem(TopLevelSystem);
    
    // Instantiate your existing extractor
    FloatingPointExtractor fp_extractor <- mkFloatingPointExtractor;
    
    // State management
    Reg#(ProcessingState) current_state <- mkReg(IDLE);
    
    // Input storage
    Reg#(Bit#(32)) input_reg <- mkReg(0);
    
    // Output registers
    Reg#(Bit#(32)) final_output <- mkReg(0);
    Reg#(Bool) output_valid <- mkReg(False);
    
    // Error tracking registers
    Reg#(Bool) system_error_flag <- mkReg(False);
    Reg#(Bit#(16)) nan_count <- mkReg(0);
    Reg#(Bit#(16)) infinity_count <- mkReg(0);
    Reg#(Bit#(16)) denorm_count <- mkReg(0);
    
    // Performance/statistics registers
    Reg#(Bit#(32)) total_processed <- mkReg(0);
    Reg#(Bit#(32)) normal_numbers <- mkReg(0);
    
    // Constants for Newton-Raphson
    Float const_48_17 = unpack(32'h4034B4B5);  // 48/17 ≈ 2.8235
    Float const_32_17 = unpack(32'h3FF0F0F1);  // 32/17 ≈ 1.8824
    Float const_2_0   = unpack(32'h40000000);  // 2.0
    Float const_1_0   = unpack(32'h3F800000);  // 1.0
    
    // RULE 1: Handle NaN cases
    rule handle_nan_case (current_state == EXTRACTING_INPUT && 
                         fp_extractor.isReady() && 
                         fp_extractor.result().is_nan);
        
        $display("NaN detected in input at time %t", $time);
        
        // Handle NaN by outputting NaN
        final_output <= 32'h7FC00000;  // Quiet NaN
        output_valid <= True;
        current_state <= COMPLETE;
        
        // Update error tracking
        nan_count <= nan_count + 1;
        total_processed <= total_processed + 1;
        
        // Set system error if too many NaNs
        if (nan_count > 100) begin
            system_error_flag <= True;
            $display("CRITICAL: Excessive NaN inputs (%d) - system flagged", nan_count + 1);
        end
    endrule
    
    // RULE 2: Handle Infinity cases
    rule handle_infinity_case (current_state == EXTRACTING_INPUT && 
                              fp_extractor.isReady() && 
                              fp_extractor.result().is_infinity);
        
        FloatingPointData fp_data = fp_extractor.result();
        
        $display("Infinity detected in input at time %t: %s infinity", $time,
                fp_data.sign_bit == 1 ? "Negative" : "Positive");
        
        // 1/infinity = 0 (with appropriate sign)
        final_output <= fp_data.sign_bit == 1 ? 32'h80000000 : 32'h00000000; // ±0.0
        output_valid <= True;
        current_state <= COMPLETE;
        
        // Update tracking
        infinity_count <= infinity_count + 1;
        total_processed <= total_processed + 1;
    endrule
    
    // RULE 3: Handle Division by Zero (1/0)
    rule handle_zero_case (current_state == EXTRACTING_INPUT && 
                          fp_extractor.isReady() && 
                          fp_extractor.result().is_zero);
        
        FloatingPointData fp_data = fp_extractor.result();
        
        $display("Reciprocal of zero detected at time %t", $time);
        
        // 1/0 = ±infinity
        final_output <= fp_data.sign_bit == 1 ? 32'hFF800000 : 32'h7F800000; // ±infinity
        
        output_valid <= True;
        current_state <= COMPLETE;
        total_processed <= total_processed + 1;
    endrule
    
    // RULE 4: Handle Denormalized numbers
    rule handle_denormalized_case (current_state == EXTRACTING_INPUT && 
                                  fp_extractor.isReady() && 
                                  fp_extractor.result().is_denormalized);
        
        $display("Denormalized input detected - processing with reduced precision");
        
        // For denormalized numbers, proceed with normal computation but flag it
        current_state <= COMPUTING_RECIPROCAL;
        denorm_count <= denorm_count + 1;
    endrule
    
    // RULE 5: Handle Normal numbers - Newton-Raphson computation
    rule handle_normal_case (current_state == EXTRACTING_INPUT && 
                            fp_extractor.isReady() && 
                            !fp_extractor.result().is_nan &&
                            !fp_extractor.result().is_infinity &&
                            !fp_extractor.result().is_zero &&
                            (!fp_extractor.result().is_denormalized || denorm_count > 0));
        
        FloatingPointData fp_data = fp_extractor.result();
        
        $display("Computing reciprocal for normal number at time %t", $time);
        
        // Proceed to reciprocal computation
        current_state <= COMPUTING_RECIPROCAL;
        
        if (!fp_data.is_denormalized) begin
            normal_numbers <= normal_numbers + 1;
        end
    endrule
    
    // RULE 6: Newton-Raphson Reciprocal Computation
    rule compute_reciprocal (current_state == COMPUTING_RECIPROCAL && 
                            fp_extractor.isReady());
        
        FloatingPointData fp_data = fp_extractor.result();
        
        // $display("DEBUG: Starting Newton-Raphson computation");
        // $display("DEBUG: Input FP data - sign: %b, exp: %h, mantissa: %h", 
        //         fp_data.sign_bit, fp_data.exponent_bits, fp_data.mantissa_bits);
        
        // Construct scaled_D: normalize to [0.5, 1.0)
        // For normal numbers: D = sign * 1.mantissa * 2^(exp-127)
        // scaled_D = 1.mantissa * 2^(-1) = 0.1mantissa (in [0.5, 1.0))
        
        Bit#(8) bias_127 = 8'h7F;  // 127
        Int#(9) signed_exp = unpack({1'b0, fp_data.exponent_bits}) - unpack({1'b0, bias_127});
        
        // $display("DEBUG: Original exponent: %d, signed_exp: %d", fp_data.exponent_bits, signed_exp);
        
        // Create scaled_D in range [0.5, 1.0)
        Bit#(8) scaled_exp_bits = bias_127 - 1;  // 126 (for exponent -1)
        Float scaled_D = unpack({1'b0, scaled_exp_bits, fp_data.mantissa_bits});
        
        // $display("DEBUG: scaled_D = %h (should be in range [0.5, 1.0))", pack(scaled_D));
        
        // Z0 = (48/17) - (32/17) * scaled_D
        Float mult_32_scaled = tpl_1(multFP(const_32_17, scaled_D, defaultValue)); // (32/17) * scaled_D
        // $display("DEBUG: (32/17) * scaled_D = %h", pack(mult_32_scaled));
        
        Float neg_mult_32_scaled = negate(mult_32_scaled); // -(32/17) * scaled_D
        // $display("DEBUG: -(32/17) * scaled_D = %h", pack(neg_mult_32_scaled));
        
        Float z0 = tpl_1(addFP(const_48_17, neg_mult_32_scaled, defaultValue)); // 48/17 - (32/17) * scaled_D
        // $display("DEBUG: Z0 = (48/17) - (32/17) * scaled_D = %h", pack(z0));
        
        // First Newton-Raphson iteration: Z1 = Z0 * (2.0 - scaled_D * Z0)
        Float mult_scaled_z0 = tpl_1(multFP(scaled_D, z0, defaultValue)); // scaled_D * Z0
        // $display("DEBUG: scaled_D * Z0 = %h", pack(mult_scaled_z0));
        
        Float neg_mult_scaled_z0 = negate(mult_scaled_z0); // -scaled_D * Z0
        // $display("DEBUG: -scaled_D * Z0 = %h", pack(neg_mult_scaled_z0));
        
        Float term_2_minus = tpl_1(addFP(const_2_0, neg_mult_scaled_z0, defaultValue)); // 2.0 - scaled_D * Z0
        // $display("DEBUG: 2.0 - scaled_D * Z0 = %h", pack(term_2_minus));
        
        Float z1 = tpl_1(multFP(z0, term_2_minus, defaultValue));
        // $display("DEBUG: Z1 = Z0 * (2.0 - scaled_D * Z0) = %h", pack(z1));
        
        // Second iteration: Z2 = Z1 * (2.0 - scaled_D * Z1)
        Float mult_scaled_z1 = tpl_1(multFP(scaled_D, z1, defaultValue));
        // $display("DEBUG: scaled_D * Z1 = %h", pack(mult_scaled_z1));
        
        Float neg_mult_scaled_z1 = negate(mult_scaled_z1);
        // $display("DEBUG: -scaled_D * Z1 = %h", pack(neg_mult_scaled_z1));
        
        Float term_2_minus1 = tpl_1(addFP(const_2_0, neg_mult_scaled_z1, defaultValue));
        // $display("DEBUG: 2.0 - scaled_D * Z1 = %h", pack(term_2_minus1));
        
        Float z2 = tpl_1(multFP(z1, term_2_minus1, defaultValue));
        // $display("DEBUG: Z2 = Z1 * (2.0 - scaled_D * Z1) = %h", pack(z2));
        
        // Third iteration: Z3 = Z2 * (2.0 - scaled_D * Z2)
        Float mult_scaled_z2 = tpl_1(multFP(scaled_D, z2, defaultValue));
        // $display("DEBUG: scaled_D * Z2 = %h", pack(mult_scaled_z2));
        
        Float neg_mult_scaled_z2 = negate(mult_scaled_z2);
        // $display("DEBUG: -scaled_D * Z2 = %h", pack(neg_mult_scaled_z2));
        
        Float term_2_minus2 = tpl_1(addFP(const_2_0, neg_mult_scaled_z2, defaultValue));
        // $display("DEBUG: 2.0 - scaled_D * Z2 = %h", pack(term_2_minus2));
        
        Float z3 = tpl_1(multFP(z2, term_2_minus2, defaultValue));
        // $display("DEBUG: Z3 = Z2 * (2.0 - scaled_D * Z2) = %h", pack(z3));
        
        // Rescale: reciprocal_D = Z3 * 2^(-scaled_exp_D)
        // Create scaling factor: 2^(-scaled_exp_D)
        Bit#(8) rescale_exp = bias_127 - pack(signed_exp)[7:0] - 1;
        // $display("DEBUG: Rescale exponent calculation: bias_127(%d) - signed_exp(%d) - 1 = %d", 
                // bias_127, pack(signed_exp)[7:0], rescale_exp);
        
        Float scale_factor = unpack({1'b0, rescale_exp, 23'b0});
        // $display("DEBUG: Scale factor = 2^(-signed_exp-1) = %h", pack(scale_factor));
        
        Float reciprocal_D = tpl_1(multFP(z3, scale_factor, defaultValue));
        // $display("DEBUG: Before sign application: reciprocal_D = Z3 * scale_factor = %h", pack(reciprocal_D));
        
        // Apply sign from original input
        if (fp_data.sign_bit == 1) begin
            reciprocal_D = negate(reciprocal_D);
            // $display("DEBUG: Applied negative sign to result");
        end
        
        // $display("DEBUG: Final reciprocal result = %h", pack(reciprocal_D));
        
        final_output <= pack(reciprocal_D);
        output_valid <= True;
        current_state <= COMPLETE;
        total_processed <= total_processed + 1;
        
        $display("Reciprocal result: %h", pack(reciprocal_D));
    endrule
    
    // Interface methods
    method Action process_fp_reciprocal(Bit#(32) input_value);
        if (current_state == IDLE) begin
            // Store input and start processing
            input_reg <= input_value;
            output_valid <= False;
            
            // Start extraction of input
            fp_extractor.extract(input_value);
            current_state <= EXTRACTING_INPUT;
            
            $display("Starting reciprocal computation: 1/%h", input_value);
        end else begin
            $display("WARNING: Reciprocal request ignored - system busy");
        end
    endmethod
    
    method Bit#(32) get_processed_output();
        return final_output;
    endmethod
    
    method Bool output_ready();
        return output_valid && (current_state == COMPLETE);
    endmethod
    
    method Bool system_error();
        return system_error_flag;
    endmethod
    
    method Action reset_system();
        current_state <= IDLE;
        system_error_flag <= False;
        nan_count <= 0;
        infinity_count <= 0;
        denorm_count <= 0;
        total_processed <= 0;
        normal_numbers <= 0;
        output_valid <= False;
        input_reg <= 0;
        final_output <= 0;
        $display("System reset completed");
    endmethod
    
endmodule
endpackage



