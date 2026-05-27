`timescale 1ns / 1ps


module uart_slave (

    input               PCLK,
    input               PRESET,
    input  logic [31:0] paddr,
    input  logic [31:0] PWDATA,
    input  logic        pwrite,
    input  logic        penable,
    input  logic        psel,
    input               Uart_rx,
    output              Uart_tx,
    output logic [31:0] prdata,
    output logic        pready

);


    assign pready = (psel & penable) ? 1'b1 : 1'b0;

    //UART SLAVE ADDR
    localparam [11:0] UART_CTL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00C;  // OC = 12
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;  // OC = 16

    //UART SLAVE REGISTER
    logic [ 7:0] UART_TX_DATA_REG;
    logic [31:0] UART_CTL_REG;
    logic [31:0] UART_STATUS_REG;
    logic [ 7:0] UART_RX_DATA_REG;
    logic [ 1:0] UART_BAUD_REG;  // 00:9600, 01:19200, 10: 115200


    //UART SIGNAL 
    logic        ctl_tx_start;
    logic        tx_busy;
    logic        rx_done;
    logic [ 7:0] rx_data;


    //assign prdata = (paddr[11:0] == UART_RX_DATA_ADDR) ? {24'h000000, UART_RX_DATA_REG} : 32'hxxxx_xxxx;

    always_comb begin
        prdata = 32'h0000_0000;
        case (paddr[11:0])
            UART_RX_DATA_ADDR: prdata = {24'h000000, UART_RX_DATA_REG};
            UART_STATUS_ADDR: prdata = UART_STATUS_REG;
            UART_CTL_ADDR: prdata = UART_CTL_REG;
        endcase

    end


    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            UART_TX_DATA_REG <= 8'd0;
            UART_CTL_REG     <= 32'd0;
            UART_STATUS_REG  <= 32'd0;
            UART_RX_DATA_REG <= 8'd0;
            UART_BAUD_REG    <= 8'd0;

        end else begin
            ctl_tx_start <= 1'b0;

            if (pready & pwrite) begin
                case (paddr[11:0])
                    UART_TX_DATA_ADDR: UART_TX_DATA_REG <= PWDATA[7:0];
                    UART_BAUD_ADDR:    UART_BAUD_REG <= PWDATA[1:0];
                    UART_CTL_ADDR: begin
                        if (PWDATA[0]) begin
                            ctl_tx_start <= 1'b1;
                        end
                    end
                endcase
            end

            UART_STATUS_REG[1] <= tx_busy;

            if (rx_done) begin
                UART_RX_DATA_REG   <= rx_data;
                UART_STATUS_REG[0] <= 1'b1;
            end else 
                if(pready & !pwrite &(paddr[11:0] == UART_RX_DATA_ADDR))begin
                UART_STATUS_REG[0] <= 1'b0;
            end
        end


    end







    uart_top U_UART_TOP (
        .clk(PCLK),
        .rst(PRESET),
        .uart_rx(Uart_rx),
        .uart_tx(Uart_tx),
        .b_sel(UART_BAUD_REG),
        .tx_data(UART_TX_DATA_REG),
        .tx_start(ctl_tx_start),
        .tx_busy(tx_busy),
        .rx_data(rx_data),
        .rx_done(rx_done)

    );


endmodule







module uart_top (
    input              clk,
    input              rst,
    input  logic       uart_rx,
    output logic       uart_tx,
    input  logic [1:0] b_sel,
    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx_busy,
    output logic [7:0] rx_data,
    output logic       rx_done

);

    wire w_b_tick;
    wire tx_done;

    uart_rx UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    uart_tx UNT_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .b_tick(w_b_tick),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .uart_tx(uart_tx)
    );
    b_tick UNT_B_TICK (
        .clk(clk),
        .rst(rst),
        .b_sel(b_sel),
        .b_tick(w_b_tick)
    );
endmodule


module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg <= 3'd0;
            done_reg <= 1'b0;
            buf_reg <= 8'd0;
        end else begin
            c_state <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            done_reg <= done_next;
            buf_reg <= buf_next;
        end

    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        done_next = done_reg;
        buf_next = buf_reg;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 5'd0;
                bit_cnt_next = 3'd0;
                done_next = 1'b0;
                if (b_tick & rx == 0) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 5'd0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end

            end
            STOP: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 16) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
        endcase
    end

endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;




    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg busy_reg, busy_next;
    reg done_reg, done_next;
    reg [7:0] data_in_buf_reg, data_in_buf_next;
    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;




    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            bit_cnt_reg <= 1'b0;
            b_tick_cnt_reg <= 4'h0;
            busy_reg <= 1'b0;
            done_reg <= 1'b0;
            data_in_buf_reg <= 8'h00;

        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            bit_cnt_reg <= bit_cnt_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            busy_reg <= busy_next;
            done_reg <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        bit_cnt_next = bit_cnt_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        busy_next = busy_reg;
        done_next = done_reg;
        data_in_buf_next = data_in_buf_reg;


        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    n_state = START;
                    busy_next = 1'b1;
                    data_in_buf_next = tx_data;

                end
            end

            START: begin

                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 4'h0;
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end


            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1'b1;
                        n_state   = IDLE;

                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule







module b_tick (
    input clk,
    input rst,
    input [1:0] b_sel,
    output logic b_tick

);

    localparam BAUD_9600 = 100_000_000 / (9600 * 16);
    localparam BAUD_19200 = 100_000_000 / (19200 * 16);
    localparam BAUD_115200 = 100_000_000 / (115200 * 16);

    logic [9:0] max_count;
    reg   [9:0] counter_reg;

    always_comb begin
        max_count = BAUD_9600;
        case (b_sel)
            2'b00: max_count = BAUD_9600;
            2'b01: max_count = BAUD_19200;
            2'b10: max_count = BAUD_115200;
        endcase

    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 1'b0;
            b_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (max_count - 1)) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end



endmodule
