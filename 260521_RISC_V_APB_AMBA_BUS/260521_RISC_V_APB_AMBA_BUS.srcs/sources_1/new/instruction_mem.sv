`timescale 1ns / 1ps

module instruction_mem (
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data
);
    logic [31:0] rom[0:255];  

    initial begin

        $readmemh("APB_TEST_C.mem", rom);
    end

    assign instr_data = rom[instr_addr[31:2]]; 

endmodule
