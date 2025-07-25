package ThresholdChecker;

import GenericComparator::*;

// Interface for the threshold checker design
interface ThresholdChecker;
    method Bool isLessThan1_17(Bit#(32) x);     // |x| < 1.17
endinterface

(* synthesize *)
module mkThresholdChecker (ThresholdChecker);
    
    // Threshold value in IEEE 754 format
    Bit#(32) threshold_1_17 = 32'h3F95C28F;  // 1.17
    
    // Method for threshold check
    method Bool isLessThan1_17(Bit#(32) x);
        return absLessThan(x, threshold_1_17);
    endmethod
    
endmodule

endpackage