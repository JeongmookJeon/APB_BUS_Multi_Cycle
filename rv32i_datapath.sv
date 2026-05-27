`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input  logic        clk,
    input  logic        rst,
    input  logic        pc_en,
    input  logic        rf_we,
    input  logic        alu_src,
    input  logic [ 3:0] alu_control,
    input  logic [31:0] instr_data,
    input  logic [31:0] bus_rdata,
    input  logic [ 2:0] rfwd_src,
    input  logic        branch,
    input  logic        jalr_srcsel,
    input  logic        jal_srcsel,
    output logic [31:0] instr_addr,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata
);

    logic [31:0] imm_data, alu_result, alurs2_data, pc_imm_out, pc_4_out;
    logic [31:0] rfwd_data;
    logic btaken;
    //decoder 
    logic [31:0]
        i_dec_rs1, o_dec_rs1, i_dec_rs2, o_dec_rs2, i_dec_imm, o_dec_imm;
    //execute 
    logic [31:0] o_exe_rs2, o_exe_alu_result;
    //mem
    logic [31:0] o_mem_drdata;
    //register
    logic [31:0] o_pc_4, o_pc_imm, o_imm_wb;

    //assign [31:0]ir_data;
    // write back to register file 
    assign bus_addr  = o_exe_alu_result;
    assign bus_wdata = o_exe_rs2;

    //fetch, exexute
    program_counter U_PC (
        .clk(clk),
        .rst(rst),
        .pc_en(pc_en),
        .btaken(btaken),
        .branch(branch),
        .jal_srcsel(jal_srcsel),
        .jalr_srcsel(jalr_srcsel),
        .rd1(o_dec_rs1),
        .imm_data(o_dec_imm),
        .program_counter(instr_addr),
        .pc_imm_out(pc_imm_out),
        .pc_4_out(pc_4_out)
    );

    register_file U_REG_FILE (
        .clk(clk),
        .rst(rst),
        .RA1(instr_data[19:15]),
        .RA2(instr_data[24:20]),
        .WA(instr_data[11:7]),
        .Wdata(rfwd_data),
        .rf_we(rf_we),
        .RD1(i_dec_rs1),
        .RD2(i_dec_rs2)
    );

    imm_extender U_IMM_EXTENDER (
        .instr_data(instr_data),
        .imm_data  (imm_data)
    );

    register U_DEC_REG_RS1 (
        .clk(clk),
        .rst(rst),
        .data_in(i_dec_rs1),
        .data_out(o_dec_rs1)
    );


    register U_DEC_REG_RS2 (
        .clk(clk),
        .rst(rst),
        .data_in(i_dec_rs2),
        .data_out(o_dec_rs2)
    );

    //Immextender--> register
    register U_DEC_IMM_EXT (
        .clk(clk),
        .rst(rst),
        .data_in(imm_data),
        .data_out(o_dec_imm)
    );

    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0(o_dec_rs2),  //sel 0
        .in1(o_dec_imm),  //sel 1
        .mux_sel(alu_src),
        .out_mux(alurs2_data)
    );

    alu U_ALU (
        .rd1(o_dec_rs1),
        .rd2(alurs2_data),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .btaken(btaken)
    );

    ////execute register for ALU result, RS2
    register U_EXE_ALU_RESULT (
        .clk(clk),
        .rst(rst),
        .data_in(alu_result),
        .data_out(o_exe_alu_result)  //ro Daddr
    );

    register U_EXE_REG_RS2 (
        .clk(clk),
        .rst(rst),
        .data_in(o_dec_rs2),  //from alu result
        .data_out(o_exe_rs2)  // to data MEM_Wdata
    );

    //MEM to WB
    register U_MEM_REG_DRDATA (
        .clk(clk),
        .rst(rst),
        .data_in(bus_rdata),  //from alu result
        .data_out(o_mem_drdata)  // to data MEM_Wdata
    );
    mux_5x1 U_WB_MUX (
        .in0(alu_result),  // from EXE_ALU Result
        .in1(o_mem_drdata),  //from data memory 
        .in2(o_dec_imm),  // from imm extend , for LUI
        .in3(pc_imm_out),  //011    //AUIPC pc + IMM  //auipc
        .in4(pc_4_out),  //100    //Pc+4  //JAL/ JARl //j-type
        .mux_sel(rfwd_src),
        .o_mux_5x1(rfwd_data)
    );

endmodule


module mux_5x1 (
    input  logic [31:0] in0,       //000
    input  logic [31:0] in1,       //001
    input  logic [31:0] in2,       //010
    input  logic [31:0] in3,       //011
    input  logic [31:0] in4,       //100
    input  logic [ 2:0] mux_sel,
    output logic [31:0] o_mux_5x1
);

    always_comb begin
        o_mux_5x1 = 32'd0;
        case (mux_sel)
            3'b000:  o_mux_5x1 = in0;
            3'b001:  o_mux_5x1 = in1;
            3'b010:  o_mux_5x1 = in2;
            3'b011:  o_mux_5x1 = in3;
            3'b100:  o_mux_5x1 = in4;
            default: o_mux_5x1 = 32'h0000_0000;
        endcase
    end
endmodule

module mux_2x1 (
    input  logic [31:0] in0,      //sel 0
    input  logic [31:0] in1,      //sel 1
    input  logic        mux_sel,
    output logic [31:0] out_mux
);

    assign out_mux = (mux_sel) ? in1 : in0;

endmodule

module imm_extender (
    input  logic [31:0] instr_data,
    output logic [31:0] imm_data
);

    always_comb begin
        imm_data = 32'd0;
        case (instr_data[6:0])
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `I_TYPE, `IL_TYPE, `JALR_TYPE: begin  //JALR was same I_TYPE IMM 
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `B_TYPE: begin
                imm_data = {
                    {19{instr_data[31]}},
                    instr_data[31],  //imm bit 11
                    instr_data[7],  //imm bit 10:5
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
            `LUI_TYPE, `AUIPC_TYPE: begin
                imm_data = {instr_data[31:12], 12'd0};
            end
            `JAL_TYPE: begin
                imm_data = {
                    {12{instr_data[31]}},
                    instr_data[19:12],  // 8bit     
                    instr_data[20],  //1bit  
                    instr_data[30:21],  //10bit 
                    1'b0  //1bit
                };
            end
        endcase
    end

endmodule

module register_file (
    input  logic        clk,
    input  logic        rst,
    input  logic [ 4:0] RA1,    // instruction code RS1
    input  logic [ 4:0] RA2,    // instruction code RS2
    input  logic [ 4:0] WA,     // instruction code RD
    input  logic [31:0] Wdata,  //instruction RD wirte data
    input  logic        rf_we,  // Register File wirte enable
    output logic [31:0] RD1,    //Register File RS1 ouput 
    output logic [31:0] RD2     //Register File RS2 output 
);

    logic [31:0] reg_file[1:31];

    always_ff @(posedge clk) begin
        if (!rst & rf_we & (WA != 5'd0)) begin
            reg_file[WA] <= Wdata;

        end
    end

    assign RD1 = (RA1 != 0) ? reg_file[RA1] : 0;
    assign RD2 = (RA2 != 0) ? reg_file[RA2] : 0;

endmodule

module alu (
    input  logic [31:0] rd1,          //RS1  //$signed --> assign signed 
    input  logic [31:0] rd2,          //RS2
    input  logic [ 3:0] alu_control,  //function7 [6],funct3 : 4bit   
    output logic [31:0] alu_result,   //alu_result 
    output logic        btaken
);


    //R-TYPE 
    always_comb begin
        alu_result = 32'h0000_0000;
        case (alu_control)
            `ADD: alu_result = rd1 + rd2;  //add rd  = rs1 + rs2
            `SUB: alu_result = rd1 - rd2;  //sub rd = rs1 - rs2
            `SLL: alu_result = rd1 << rd2[4:0];  // SLL rd = rs1 << rs2
            `SLT:
            alu_result = ($signed(rd1) < $signed(rd2)) ? 1 :
                0;  // slt rd = (rs1 < rs2) ? 1:0 //zero extend
            `SLTU: alu_result = (rd1 < rd2) ? 1 : 0;  //slt_u rd = rs1 - rs2
            `XOR: alu_result = rd1 ^ rd2;  //xor rd = rs1 ^ rs2
            `SRL: alu_result = rd1 >> rd2[4:0];  //SRL rd = rs1 >> rs2
            `SRA:
            alu_result = $signed(rd1) >>> rd2[4:0]
                ;  //SRA rd = rs1 >> rs2, msb_extention, arithmetic right shift 
            `OR: alu_result = rd1 | rd2;  //or rd = rs1 | rs2
            `AND: alu_result = rd1 & rd2;  //and rd = rs1 & rs2
        endcase
    end

    //B-Type
    always_comb begin
        btaken = 0;
        case (alu_control)
            `BEQ: begin
                if (rd1 == rd2) btaken = 1;  //true: pc = pc +IMM
                else btaken = 0;  //false : pc = pc +4
            end
            `BNE: begin
                if (rd1 != rd2) btaken = 1;  //true : pc = pc+IMM 
                else btaken = 0;  //false :pc= pc +4
            end
            `BLT: begin
                if (($signed(rd1)) < ($signed(rd2)))
                    btaken = 1;  //true : pc = pc+IMM 
                else btaken = 0;  //false :pc= pc +4
            end
            `BGE: begin
                if (($signed(rd1)) >= ($signed(rd2)))
                    btaken = 1;  //true : pc = pc+IMM 
                else btaken = 0;  //false :pc= pc +4
            end
            `BLTU: begin
                if (rd1 < rd2) btaken = 1;  //true : pc = pc+IMM  //zero extend 
                else btaken = 0;  //false :pc= pc +4
            end
            `BGEU: begin
                if (rd1 >= rd2) btaken = 1;  //true : pc = pc+IMM  //zero extend
                else btaken = 0;  //false :pc= pc +4
            end
        endcase
    end

endmodule


module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        pc_en,            //from Control unit for PC register 
    input  logic        btaken,           //from alu btype 
    input  logic        branch,
    input  logic        jal_srcsel,
    input  logic        jalr_srcsel,
    input  logic [31:0] rd1,
    input  logic [31:0] imm_data,
    output logic [31:0] program_counter,
    output logic [31:0] pc_imm_out,
    output logic [31:0] pc_4_out
);

    logic [31:0] pc_next, o_rs1_pc, o_exe_pcnext;

    mux_2x1 U_RS1_PC (
        .in0(program_counter),  //sel 0
        .in1(rd1),  //sel 1
        .mux_sel(jalr_srcsel),
        .out_mux(o_rs1_pc)
    );

    pc_alu U_PC_IMM (
        .a(imm_data),
        .b(o_rs1_pc),
        .pc_alu_out(pc_imm_out)
    );

    pc_alu U_PC_4 (
        .a(32'd4),
        .b(program_counter),
        .pc_alu_out(pc_4_out)
    );

    mux_2x1 U_PC_NEXT_MUX (
        .in0(pc_4_out),
        .in1(pc_imm_out),
        .mux_sel(jal_srcsel | (btaken & branch)),
        .out_mux(pc_next)
    );

    register U_PCNEXT_REG (
        .clk(clk),
        .rst(rst),
        .data_in(pc_next),
        .data_out(o_exe_pcnext)
    );

    register_en U_PC_REG (
        .clk(clk),
        .rst(rst),
        .en(pc_en),
        .data_in(o_exe_pcnext),  //o_exe_pcnext
        .data_out(program_counter)
    );
endmodule

module pc_alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] pc_alu_out
);

    assign pc_alu_out = a + b;

endmodule


module register (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);

    logic [31:0] reg_f;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            reg_f <= 0;
        end else begin
            reg_f <= data_in;
        end
    end

    assign data_out = reg_f;

endmodule

module register_en (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);
    logic [31:0] reg_f;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            reg_f <= 0;
        end else begin
            if (en) begin
                reg_f <= data_in;
            end
        end
    end

    assign data_out = reg_f;

endmodule
