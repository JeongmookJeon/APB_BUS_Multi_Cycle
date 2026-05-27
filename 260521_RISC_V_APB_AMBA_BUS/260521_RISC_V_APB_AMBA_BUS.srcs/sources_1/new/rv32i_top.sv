`timescale 1ns / 1ps


module rv32i_mcu (
    input               clk,
    input               rst,
    inout        [15:0] GPIO,
    input        [ 7:0] GPI,
    input               Uart_rx,
    output              Uart_tx,
    output       [ 7:0] GPO,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data

);

    //logic dwe;
    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;
    logic [3:0] alu_control;
    logic bus_w_req, bus_r_req, bus_ready;

    logic [31:0] paddr, PWDATA;
    logic penable, pwrite;
    logic psel0, psel1, psel2, psel3, psel4, psel5;
    logic pready0, pready1, pready2, pready3, pready4, pready5;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5;

    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32i_cpu U_RV32I_CPU (
        .*,
        .o_funct3(o_funct3)
    );

    apb_master U_APB_MASTER (

        .PCLK  (clk),
        .PRESET(rst),
        .addr  (bus_addr),
        .Wdata (bus_wdata),
        .w_req (bus_w_req),  // from cpu, write request, signal cpu : dwe
        .r_req (bus_r_req),  // from cpu, read request, signal cpu : dre 
        .rdata (bus_rdata),  // RAM  
        .ready (bus_ready),

        // to APB Slave 
        .paddr  (paddr),    //need register
        .PWDATA (PWDATA),   //need register
        .penable(penable),
        .pwrite (pwrite),

        //from APB Slave
        .psel0  (psel0),
        .psel1  (psel1),
        .psel2  (psel2),
        .psel3  (psel3),
        .psel4  (psel4),
        .psel5  (psel5),
        .prdata0(prdata0),
        .prdata1(prdata1),
        .prdata2(prdata2),
        .prdata3(prdata3),
        .prdata4(prdata4),
        .prdata5(prdata5),
        .pready0(pready0),
        .pready1(pready1),
        .pready2(pready2),
        .pready3(pready3),
        .pready4(pready4),
        .pready5(pready5)
    );

    BRAM U_BRAM (
        .*,
        .PCLK  (clk),
        .psel  (psel0),    // RAM 
        .prdata(prdata0),  // RAM 
        .pready(pready0)   // RAM 
    );

    APB_GPO U_APB_GPO (
        .PCLK(clk),
        .PRESET(rst),
        .paddr(paddr),
        .PWDATA(PWDATA),
        .penable(penable),
        .pwrite(pwrite),
        .psel(psel1),
        .prdata(prdata1),
        .pready(pready1),
        .GPO(GPO)

    );

    APB_GPI U_APB_GPI (
        .PCLK(clk),
        .PRESET(rst),
        .paddr(paddr),
        .PWDATA(PWDATA),  // No work  
        .penable(penable),
        .pwrite(pwrite),
        .psel(psel2),
        .GPI(GPI),  // work like PWDATA
        .pready(pready2),
        .prdata(prdata2)

    );

    APB_GPIO U_APB_GPIO (

        .PCLK(clk),
        .PRESET(rst),
        .paddr(paddr),
        .PWDATA(PWDATA),
        .penable(penable),
        .pwrite(pwrite),
        .psel(psel3),
        .prdata(prdata3),
        .pready(pready3),
        .GPIO(GPIO)
    );


    APB_FND_SLAVE U_APB_FND (
        .PCLK(clk),
        .PRESET(rst),
        .paddr(paddr),
        .PWDATA(PWDATA),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel4),
        .prdata(prdata4),
        .pready(pready4),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    uart_slave U_APB_UART (

        .PCLK(clk),
        .PRESET(rst),
        .paddr(paddr),
        .PWDATA(PWDATA),
        .pwrite(pwrite),
        .penable(penable),
        .psel(psel5),
        .Uart_rx(Uart_rx),
        .Uart_tx(Uart_tx),
        .prdata(prdata5),
        .pready(pready5)
    );

endmodule
