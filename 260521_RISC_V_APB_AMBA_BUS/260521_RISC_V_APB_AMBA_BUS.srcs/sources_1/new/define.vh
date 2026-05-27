//`define SIMULATION

//OP code 
`define R_TYPE     7'b011_0011
`define S_TYPE     7'b010_0011
`define I_TYPE     7'b001_0011
`define IL_TYPE    7'b000_0011
`define B_TYPE     7'b110_0011
`define LUI_TYPE   7'b011_0111
`define AUIPC_TYPE 7'b001_0111
`define JAL_TYPE   7'b110_1111
`define JALR_TYPE  7'b110_0111
//R-type Instruction 
`define ADD  4'b0_000  
`define SUB  4'b1_000  
`define SLL  4'b0_001  
`define SLT  4'b0_010  
`define SLTU 4'b0_011 
`define XOR  4'b0_100  
`define SRL  4'b0_101  
`define SRA  4'b1_101   
`define OR   4'b0_110  
`define AND  4'b0_111  

//B_TYPE 
`define BEQ   4'b0_000  
`define BNE   4'b0_001
`define BLT   4'b0_100
`define BGE   4'b0_101
`define BLTU  4'b0_110
`define BGEU  4'b0_111
