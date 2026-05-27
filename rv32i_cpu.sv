`timescale 1ns / 1ps
`include "define.vh"


module rv32i_cpu (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] instr_data,
    input  logic [31:0] bus_rdata,
    input  logic        bus_ready,
    output logic [31:0] instr_addr,
    output logic        bus_w_req,
    output logic        bus_r_req,
    output logic [ 2:0] o_funct3,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata
);
    logic pc_en, rf_we, alu_src, branch, jalr_srcsel, jal_srcsel;
    logic [31:0] alu_result;
    logic [ 3:0] alu_control;
    logic [ 2:0] rfwd_src;


    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .rst(rst),
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .ready(bus_ready),
        .pc_en(pc_en),  //for muticycle Fetch
        .alu_src(alu_src),
        .rf_we(rf_we),
        .branch(branch),
        .jalr_srcsel(jalr_srcsel),
        .jal_srcsel(jal_srcsel),
        .rfwd_src(rfwd_src),
        .alu_control(alu_control),
        .o_funct3(o_funct3),
        .dwe(bus_w_req),
        .dre(bus_r_req)
    );

    rv32i_datapath U_DATAPATH (.*);
endmodule

//add a register for Multicycle 
module control_unit (
    input              clk,
    input              rst,
    input  logic [6:0] funct7,
    input  logic [2:0] funct3,
    input  logic [6:0] opcode,
    input              ready,
    output logic       pc_en,
    output logic       alu_src,
    output logic       rf_we,
    output logic       branch,       //for B-type  
    output logic       jalr_srcsel,
    output logic       jal_srcsel,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_src,
    output logic [2:0] o_funct3,
    output logic       dwe,
    output logic       dre
);

    typedef enum logic [3:0] {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end

    end

    // Using by Opcode
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE,`I_TYPE,`B_TYPE,`LUI_TYPE,`AUIPC_TYPE,`JAL_TYPE,`JALR_TYPE: begin
                        n_state = FETCH;
                    end
                    `IL_TYPE: begin
                        n_state = MEM;
                    end
                    `S_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        if (ready) begin
                            n_state = FETCH;
                        end
                    end
                    `IL_TYPE: begin
                        n_state = WB;
                    end
                endcase
            end
            WB: begin
                if (ready) begin
                    n_state = FETCH;
                end
            end
        endcase
    end

    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        branch      = 1'b0;
        jalr_srcsel = 1'b0;
        jal_srcsel  = 1'b0;
        alu_control = 4'b0000;
        alu_src     = 1'b0;
        rfwd_src    = 3'b000;
        o_funct3    = 3'b000;
        dwe         = 1'b0;  // for s type
        dre         = 1'b0;  // for IL  type

        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        pc_en       = 1'b0;
                        rf_we       = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        alu_src = 1'b1;
                        rf_we   = 1'b1;
                        if (funct3 == 3'b101)
                            alu_control = {funct7[5], funct3};  //SRL, SRA
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        branch = 1'b1;
                        alu_src = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b000;
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `LUI_TYPE: begin
                        rf_we    = 1'b1;
                        rfwd_src = 3'b010;
                    end
                    `AUIPC_TYPE: begin
                        rf_we    = 1'b1;
                        rfwd_src = 3'b011;
                    end
                    `JAL_TYPE: begin
                        rf_we      = 1'b1;
                        jal_srcsel = 1'b1;
                        rfwd_src   = 3'b100;
                    end
                    `JALR_TYPE: begin
                        rf_we       = 1'b1;
                        jalr_srcsel = 1'b1;
                        jal_srcsel  = 1'b1;
                        rfwd_src    = 3'b100;
                    end
                endcase
            end
            MEM: begin
                o_funct3 = funct3;
                dre = 1'b1;
                case (opcode)
                    `S_TYPE: begin
                        dwe = 1'b1;
                    end

                endcase
            end

            WB: begin
                //IL TYPE
                rfwd_src = 3'b001;
                if (ready) begin
                    rf_we = 1'b1;
                end else begin
                    rf_we = 1'b0;
                end
            end
        endcase
    end
endmodule
