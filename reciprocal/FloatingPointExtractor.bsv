import FloatingPoint ::*;

// Enhanced structure with validity and special case flags
typedef struct {
    Bit#(1)  sign_bit;
    Bit#(8)  exponent_bits;
    Bit#(23) mantissa_bits;
    Bit#(23) scaled_mantissa;
    Bit#(8)  scaled_exponent;
    Bool     is_valid;
    Bool     is_nan;
    Bool     is_infinity;
    Bool     is_zero;
    Bool     is_denormalized;
} FloatingPointData deriving (Bits, Eq);

// Enhanced interface with validity checking
interface FloatingPointExtractor;
    method Action extract(Bit#(32) fp_bits);
    method FloatingPointData result();
    method Bool isReady();
endinterface

// Safe floating point extractor module
module mkFloatingPointExtractor(FloatingPointExtractor);
    
    // Register to store the result with proper initialization
    Reg#(FloatingPointData) data_reg <- mkReg(FloatingPointData {
        sign_bit: 0,
        exponent_bits: 0,
        mantissa_bits: 0,
        scaled_mantissa: 0,
        scaled_exponent: 0,    // Fixed: Added missing initialization
        is_valid: False,
        is_nan: False,
        is_infinity: False,
        is_zero: False,
        is_denormalized: False
    });
    
    method Action extract(Bit#(32) fp_bits);
        // Unpack the input bits to floating point
        FloatingPoint#(8,23) fp_number = unpack(fp_bits);
        
        // Extract the basic components
        Bit#(1)  sign_bit      = pack(fp_number.sign);
        Bit#(8)  exponent_bits = fp_number.exp;
        Bit#(23) mantissa_bits = fp_number.sfd;
        
        // Check for special cases
        Bool is_zero_val = (exponent_bits == 0) && (mantissa_bits == 0);
        Bool is_denorm   = (exponent_bits == 0) && (mantissa_bits != 0);
        Bool is_inf      = (exponent_bits == 8'hFF) && (mantissa_bits == 0);
        Bool is_nan_val  = (exponent_bits == 8'hFF) && (mantissa_bits != 0);
        
        // Handle scaling for both mantissa and exponent
        Bit#(23) scaled_mantissa;
        Bit#(8)  scaled_exponent;
        
        if (is_zero_val || is_denorm || is_inf || is_nan_val) begin
            // Don't scale special values
            scaled_mantissa = mantissa_bits;
            scaled_exponent = exponent_bits;
        end else begin
            // Scale normal numbers: mantissa/2 and exponent+1
            // This normalizes the number into [0.5, 1.0) range
            scaled_mantissa = mantissa_bits >> 1;
            scaled_exponent = exponent_bits + 1;
        end
        
        // Store the result with all safety flags
        data_reg <= FloatingPointData {
            sign_bit:        sign_bit,
            exponent_bits:   exponent_bits,
            mantissa_bits:   mantissa_bits,
            scaled_mantissa: scaled_mantissa,
            scaled_exponent: scaled_exponent,  // Fixed: Properly assigned
            is_valid:        True,
            is_nan:          is_nan_val,
            is_infinity:     is_inf,
            is_zero:         is_zero_val,
            is_denormalized: is_denorm
        };
        
        // Debug output
        $display("FloatingPoint extracted: Sign=%b, Exp=%h, Mantissa=%h", 
                sign_bit, exponent_bits, mantissa_bits);
        $display("Scaled values: Mantissa=%h, Exponent=%h", 
                scaled_mantissa, scaled_exponent);
        $display("Special flags: NaN=%b, Inf=%b, Zero=%b, Denorm=%b", 
                is_nan_val, is_inf, is_zero_val, is_denorm);
    endmethod
    
    method FloatingPointData result();
        return data_reg;
    endmethod
    
    method Bool isReady();
        return data_reg.is_valid;
    endmethod

endmodule