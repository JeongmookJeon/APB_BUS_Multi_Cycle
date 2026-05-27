`timescale 1ns / 1ps

module BRAM (
    input  logic        PCLK,
    input  logic [31:0] paddr,
    input  logic [31:0] PWDATA,
    input  logic        penable,
    input  logic        pwrite,
    input  logic        psel,
    output logic [31:0] prdata,
    output logic        pready
);
    logic [31:0] bmem[0:1023];  // 1024 * 4byte : 4K 

    assign pready = (penable & psel) ? 1'b1 : 1'b0;
    
    always_ff @(posedge PCLK) begin
        if (psel & penable & pwrite) begin
            bmem[paddr[11:2]] <= PWDATA;
        end
    end
    assign prdata = bmem[paddr[11:2]];

endmodule
