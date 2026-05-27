`timescale 1ns / 1ps
`include "define.vh"

module APB_GPO (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [31:0] paddr,
    input  logic [31:0] PWDATA,
    input  logic        penable,
    input  logic        pwrite,
    input  logic        psel,
    output logic [31:0] prdata,
    output logic        pready,
    output logic [ 7:0] GPO          // 8비트 출력 포트로 변경
);

    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;
    logic [7:0] GPO_ODATA_REG, GPO_CTL_REG; // 내부 레지스터 8비트화

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    //GPO to Bus Read (상위 24비트 Zero-padding)
    assign prdata = (psel & ~pwrite) ? 
                    (paddr[11:0] == GPO_CTL_ADDR) ?  {24'h000000, GPO_CTL_REG} :
                    (paddr[11:0] == GPO_ODATA_ADDR) ? {24'h000000, GPO_ODATA_REG}: 
                    32'h0000_0000 : 32'h0000_0000;

    // Bus to GPO Write
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPO_CTL_REG   <= 8'h00;
            GPO_ODATA_REG <= 8'h00;
        end else begin
            if (pready) begin
                if (pwrite) begin
                    case (paddr[11:0])
                        GPO_CTL_ADDR:   GPO_CTL_REG <= PWDATA[7:0];
                        GPO_ODATA_ADDR: GPO_ODATA_REG <= PWDATA[7:0];
                    endcase
                end
            end
        end
    end

    gpo U_GPO (
        .ctl(GPO_CTL_REG),
        .o_data(GPO_ODATA_REG),
        .gpo_out(GPO)
    );

endmodule

module gpo (
    input  logic [7:0] ctl,
    input  logic [7:0] o_data,
    output logic [7:0] gpo_out
);
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign gpo_out[i] = ctl[i] ? o_data[i] : 1'bz;
        end
    endgenerate
endmodule