`timescale 1ns / 1ps
`include "define.vh"


module APB_FND_SLAVE(
        input               PCLK,
        input               PRESET,
        input  logic [31:0] paddr,
        input  logic [31:0] PWDATA,
        input  logic        pwrite,
        input  logic        penable,
        input  logic        psel,
        output logic [31:0] prdata,
        output logic        pready, 
        output logic [3:0]  fnd_digit,
        output logic [7:0]  fnd_data 

        );

    localparam [11:0] GPIO_O_ADDR = 12'h004;
    logic [15:0] GPIO_O_REG;
    logic [15:0] FND_OUT;
    
    assign  pready = (psel & penable) ? 1'b1 : 1'b0;

    assign prdata = (paddr[11:0] == GPIO_O_ADDR) ? {16'h0000,GPIO_O_REG} :32'h0000_0000;
                



    always_ff @( posedge PCLK, posedge PRESET ) begin 
        if(PRESET)begin
            GPIO_O_REG <= 16'h0000;           
        end else begin
        if(pready & pwrite)begin
            case (paddr[11:0])
                //BUS에서 GPIO로 들어온 Data
                GPIO_O_ADDR : GPIO_O_REG <= PWDATA[15:0];
            endcase
        end
    end 
    end 
        
    assign FND_OUT = GPIO_O_REG; 




fnd_controller U_FND_CNTL(
    .clk(PCLK),
    .rst(PRESET),
    .fnd_idata(FND_OUT),
    .fnd_digit(fnd_digit),
    .fnd_data(fnd_data)
);

endmodule


module fnd_controller(
    input        clk,
    input        rst,
    input [15:0] fnd_idata,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000,w_mux_4x1_out;
    wire [1:0] w_digit_sel;
    wire w_1khz;

    digit_splitter U_DIGIT_SPL (
        .in_data(fnd_idata[8:0]),   //fnd_idata[8:0]
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
);

    clk_div U_CLK_DIV (
        .clk(clk),
        .rst(rst),
        .o_1khz(w_1khz)
    );


counter_4 U_COUNTER_4 (
    .clk(w_1khz),
    .rst(rst),
    .digit_sel(w_digit_sel)
);


decoder_2x4 U_DECODDER_2x4(
    .digit_sel(w_digit_sel),
    .fnd_digit(fnd_digit)
);

mux_4x1 U_Mux_4x1 (
    .sel(w_digit_sel),
    .digit_1(w_digit_1),         //.digit_1(fnd_idata[3:0]),
    .digit_10(w_digit_10),        // .digit_10(fnd_idata[7:4]),
    .digit_100(w_digit_100),      //   .digit_100(fnd_idata[11:8]),
    .digit_1000(w_digit_1000),    //     .digit_1000(fnd_idata[15:12]),
    .mux_out(w_mux_4x1_out)
);
    bcd U_BCD(
        .bcd(w_mux_4x1_out),
        .fnd_data(fnd_data) //no reg. wire 
    );

    
endmodule

module clk_div (
    input clk,
    input rst,
    output reg o_1khz
);


    reg [$clog2(100_000):0] counter_r;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_r <= 0;
            o_1khz <= 1'b0;
             end else begin
                 if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
                
                end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 1'b0;
                end
        end
    end
    
endmodule

module counter_4 (
    input clk,
    input rst,
    output [1:0] digit_sel
);

    reg [1:0] counter_r;
    assign digit_sel = counter_r;

    always @(posedge clk, posedge rst) begin
        if(rst) begin 
            // init counter_r
            counter_r <= 0;

        end else begin
            // to do
            counter_r <= counter_r + 1;
        end
    end
    
endmodule

//to select to fnd digit display 
module decoder_2x4 (
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit

);

    always @(digit_sel) begin
        case (digit_sel)
        2'b00: fnd_digit = 4'b1110;
        2'b01: fnd_digit = 4'b1101;
        2'b10: fnd_digit = 4'b1011;
        2'b11: fnd_digit = 4'b0111;
        endcase
        
    end
    
endmodule




module mux_4x1 (
    input [1:0] sel,
    input [3:0] digit_1,
    input   [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
        2'b00: mux_out = digit_1;
        2'b01: mux_out = digit_10;
        2'b10: mux_out = digit_100;
        2'b11: mux_out = digit_1000;
        endcase
    end
    
endmodule

module digit_splitter (
    input  [8:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);

    assign digit_1 = in_data % 10;
    assign digit_10 = (in_data/10) % 10;
    assign digit_100 = (in_data/100) % 10;
    assign digit_1000 = (in_data/1000) % 10;

endmodule

module bcd (
    input      [3:0] bcd,
    output reg [7:0] fnd_data ///bcd output 
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hC0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hB0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            //
            4'd10: fnd_data = 8'h88; // A
            4'd11: fnd_data = 8'h83; // b (숫자 8과 구분하기 위해 소문자로 표시)
            4'd12: fnd_data = 8'hC6; // C
            4'd13: fnd_data = 8'hA1; // d (숫자 0과 구분하기 위해 소문자로 표시)
            4'd14: fnd_data = 8'h86; // E
            4'd15: fnd_data = 8'h8E; // F
            default : fnd_data = 8'hFF;
        endcase

    end

endmodule



