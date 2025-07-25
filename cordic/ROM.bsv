package ROM;

import Vector::*;
import FloatingPoint::*;

// Define alias for IEEE-754 single precision float
typedef FloatingPoint#(8,23) Float32;

// ROM Interface - takes 5-bit address (0-24), returns 32-bit data
interface ROM_IFC;
    method Bit#(32) read(Bit#(5) addr);  // returns packed FP32
endinterface

// ROM Implementation with 25 FP32 values for hyperbolic CORDIC
module mkROM(ROM_IFC);

    // Create vector with 25 Float32 values - arctanh(2^(-i)) for i=0 to 24
    Vector#(25, Float32) rom_data = newVector();

    // Initialize ROM with precise arctanh values for hyperbolic CORDIC
    // These values are atanh(2^(-i)) for i = 0, 1, 2, ..., 24
    rom_data[0] = unpack(32'h3F0C9F54); // atanh(2^-1) = 0.5493061443
    rom_data[1] = unpack(32'h3E82C578); // atanh(2^-2) = 0.2554128119
    rom_data[2] = unpack(32'h3E00AC49); // atanh(2^-3) = 0.1256572141
    rom_data[3] = unpack(32'h3D802AC4); // atanh(2^-4) = 0.0625815715
    rom_data[4] = unpack(32'h3D000AAC); // atanh(2^-5) = 0.0312601785
    rom_data[5] = unpack(32'h3C8002AB); // atanh(2^-6) = 0.0156262718
    rom_data[6] = unpack(32'h3C0000AB); // atanh(2^-7) = 0.0078126590
    rom_data[7] = unpack(32'h3B80002B); // atanh(2^-8) = 0.0039062699
    rom_data[8] = unpack(32'h3B00000B); // atanh(2^-9) = 0.0019531275
    rom_data[9] = unpack(32'h3A800003); // atanh(2^-10) = 0.0009765628
    rom_data[10] = unpack(32'h3A000001); // atanh(2^-11) = 0.0004882813
    rom_data[11] = unpack(32'h39800000); // atanh(2^-12) = 0.0002441406
    rom_data[12] = unpack(32'h39000000); // atanh(2^-13) = 0.0001220703
    rom_data[13] = unpack(32'h38800000); // atanh(2^-14) = 0.0000610352
    rom_data[14] = unpack(32'h38000000); // atanh(2^-15) = 0.0000305176
    rom_data[15] = unpack(32'h37800000); // atanh(2^-16) = 0.0000152588
    rom_data[16] = unpack(32'h37000000); // atanh(2^-17) = 0.0000076294
    rom_data[17] = unpack(32'h36800000); // atanh(2^-18) = 0.0000038147
    rom_data[18] = unpack(32'h36000000); // atanh(2^-19) = 0.0000019073
    rom_data[19] = unpack(32'h35800000); // atanh(2^-20) = 0.0000009537
    rom_data[20] = unpack(32'h35000000); // atanh(2^-21) = 0.0000004768
    rom_data[21] = unpack(32'h34800000); // atanh(2^-22) = 0.0000002384
    rom_data[22] = unpack(32'h34000000); // atanh(2^-23) = 0.0000001192
    rom_data[23] = unpack(32'h33800000); // atanh(2^-24) = 0.0000000596
    rom_data[24] = unpack(32'h33000000); // atanh(2^-25) = 0.0000000298
    // Read method - returns FP32 as Bit#(32)
    method Bit#(32) read(Bit#(5) addr);
        if (addr < 25)
            return pack(rom_data[addr]);  // convert Float32 -> Bit#(32)
        else
            return 32'h00000000;          // fallback for invalid address
    endmethod

endmodule

endpackage