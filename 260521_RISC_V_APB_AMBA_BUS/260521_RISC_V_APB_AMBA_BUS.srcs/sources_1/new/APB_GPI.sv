`timescale 1ns / 1ps
`include "define.vh"

module APB_GPI (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [31:0] paddr,
    input  logic [31:0] PWDATA,
    input  logic        penable,
    input  logic        pwrite,
    input  logic        psel,
    output logic [31:0] prdata,
    output logic        pready,
    input  logic [ 7:0] GPI          // 8비트 입력 포트로 변경
);

    localparam [11:0] GPI_CTL_ADDR = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;
    logic [7:0] GPI_CTL_REG, GPI_IDATA_REG; // 내부 레지스터 8비트화

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    //GPI to Bus Read (상위 24비트 Zero-padding)
    assign prdata = (psel & ~pwrite) ? 
                    (paddr[11:0] == GPI_CTL_ADDR) ?  {24'h000000, GPI_CTL_REG} :
                    (paddr[11:0] == GPI_IDATA_ADDR) ? {24'h000000, GPI_IDATA_REG}: 
                    32'h0000_0000 : 32'h0000_0000;

    // Bus to GPI Write
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPI_CTL_REG   <= 8'h00;
        end else begin
            if (pready) begin
                if (pwrite) begin
                    case (paddr[11:0])
                        GPI_CTL_ADDR:   GPI_CTL_REG <= PWDATA[7:0];
                    endcase
                end
            end
        end
    end

    gpi U_GPI (
        .ctl(GPI_CTL_REG),
        .gpi_in(GPI),
        .i_data(GPI_IDATA_REG)
    );

endmodule

module gpi (
    input  logic [7:0] ctl,
    input  logic [7:0] gpi_in,
    output logic [7:0] i_data
);
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign i_data[i] = ctl[i] ? gpi_in[i] : 1'bz;
        end
    endgenerate
endmodule