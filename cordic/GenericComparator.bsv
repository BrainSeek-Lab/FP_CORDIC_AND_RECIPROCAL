package GenericComparator;

// IEEE 754 Single Precision Floating Point format
typedef struct {
    Bit#(1)  sign;
    Bit#(8)  exponent;
    Bit#(23) mantissa;
} FP32 deriving (Bits, Eq);

// Convert 32-bit representation to FP32 struct
function FP32 bitToFP32(Bit#(32) x);
    return FP32 {
        sign: x[31],
        exponent: x[30:23],
        mantissa: x[22:0]
    };
endfunction

// Generic function to check if |x| < threshold
function Bool absLessThan(Bit#(32) x, Bit#(32) threshold);
    FP32 fp_x = bitToFP32(x);
    FP32 fp_thresh = bitToFP32(threshold);
    
    // Handle special cases for x
    Bool x_is_zero_or_denorm = (fp_x.exponent == 8'b00000000);
    Bool x_is_special = (fp_x.exponent == 8'b11111111);
    
    // Handle special cases for threshold
    Bool thresh_is_special = (fp_thresh.exponent == 8'b11111111);
    Bool thresh_is_zero = (fp_thresh.exponent == 8'b00000000);
    
    // For normal numbers, compare magnitude (ignore sign bit)
    Bool exp_less = (fp_x.exponent < fp_thresh.exponent);
    Bool exp_equal = (fp_x.exponent == fp_thresh.exponent);
    Bool mant_less = (fp_x.mantissa < fp_thresh.mantissa);
    
    Bool normal_result = exp_less || (exp_equal && mant_less);
    
    // Special case handling using conditional operator
    Bool result = x_is_zero_or_denorm ? 
                      !thresh_is_zero :  // |0| < thresh only if thresh > 0
                      (x_is_special || thresh_is_special) ? 
                          False :  // NaN/Inf comparisons are false
                          normal_result;
    
    return result;
endfunction

// Interface for generic comparator
interface GenericComparator;
    method Bool compare(Bit#(32) x, Bit#(32) threshold);
endinterface

// Top-level generic comparator module
(* synthesize *)
module mkGenericComparator (GenericComparator);
    
    method Bool compare(Bit#(32) x, Bit#(32) threshold);
        return absLessThan(x, threshold);
    endmethod
    
endmodule

endpackage