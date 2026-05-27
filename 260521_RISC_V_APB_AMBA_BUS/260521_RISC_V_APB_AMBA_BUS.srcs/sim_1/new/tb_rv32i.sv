`timescale 1ns / 1ps

// ============================================================
//  RV32I MCU Testbench
//  DUT: rv32i_mcu (rv32i_top.sv)
//
//  테스트 항목:
//    T1  1~10 합산 → FND = 55            (ALU, 루프, WB)
//    T2  GPO Walking LED                  (APB write, SLL)
//    T3  GPO + FND 바이너리 카운터 0~15   (동시 쓰기)
//    T4  GPI(0xA5) → GPO 에코             (APB read)
//    T5  GPIO 양방향 (0xAA / 0x55 출력)   (inout 트라이스테이트)
//    T6  FND 0~99 카운트                  (연속 write)
//    T7  UART TX "Hello RV32I\r\n"        (115200 baud, TX_DATA/CTL)
//    T8  APB 프로토콜 자동 감시            (SETUP→ACCESS 순서)
//    T9  RST 초기화                        (PC=0 확인)
//
//  호환 시뮬레이터: Vivado Sim, VCS, ModelSim, Xcelium
//  (iverilog 부분 호환 – fork/join_any 지원 시뮬레이터 권장)
// ============================================================

module tb_rv32i_mcu;

    // ── 클럭/리셋 ──────────────────────────────
    localparam CLK_PERIOD = 10;   // 10ns = 100MHz

    logic        clk;
    logic        rst;

    // ── DUT 포트 ───────────────────────────────
    wire  [15:0] GPIO;
    logic [ 7:0] GPI;
    logic        Uart_rx;
    wire         Uart_tx;
    wire  [ 7:0] GPO;
    wire  [ 3:0] fnd_digit;
    wire  [ 7:0] fnd_data;

    // GPIO 상위 8비트: TB에서 드라이브 (입력 모드 테스트)
    logic [15:0] gpio_drive_val;
    logic [15:0] gpio_drive_en;   // 1=TB 드라이브

    genvar gi;
    generate
        for (gi = 0; gi < 16; gi++) begin : gpio_bidir
            assign GPIO[gi] = gpio_drive_en[gi] ? gpio_drive_val[gi] : 1'bz;
        end
    endgenerate

    // ── 테스트 카운터 ──────────────────────────
    integer pass_cnt;
    integer fail_cnt;
    integer apb_err_cnt;

    // ── DUT 인스턴스 ───────────────────────────
    rv32i_mcu DUT (
        .clk      (clk),
        .rst      (rst),
        .GPIO     (GPIO),
        .GPI      (GPI),
        .Uart_rx  (Uart_rx),
        .Uart_tx  (Uart_tx),
        .GPO      (GPO),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

    // ── APB 내부 신호 (계층 참조) ──────────────
    wire [31:0] w_paddr   = DUT.paddr;
    wire [31:0] w_pwdata  = DUT.PWDATA;
    wire        w_pwrite  = DUT.pwrite;
    wire        w_penable = DUT.penable;
    wire        w_psel0   = DUT.psel0;
    wire        w_psel1   = DUT.psel1;
    wire        w_psel2   = DUT.psel2;
    wire        w_psel3   = DUT.psel3;
    wire        w_psel4   = DUT.psel4;
    wire        w_psel5   = DUT.psel5;
    wire        w_bus_w_req = DUT.bus_w_req;
    wire        w_bus_r_req = DUT.bus_r_req;
    wire [31:0] w_bus_rdata = DUT.bus_rdata;

    // ── 주변장치 내부 레지스터 (계층 참조) ───────
    wire [ 7:0] gpo_ctl    = DUT.U_APB_GPO.GPO_CTL_REG;
    wire [ 7:0] gpo_odata  = DUT.U_APB_GPO.GPO_ODATA_REG;
    wire [ 7:0] gpi_ctl    = DUT.U_APB_GPI.GPI_CTL_REG;
    wire [15:0] gpio_ctl   = DUT.U_APB_GPIO.GPIO_CTL_REG;
    wire [15:0] gpio_odata = DUT.U_APB_GPIO.GPIO_ODATA_REG;
    wire [15:0] gpio_idata = DUT.U_APB_GPIO.GPIO_IDATA_REG;
    wire [15:0] fnd_reg    = DUT.U_APB_FND.GPIO_O_REG;
    wire [ 7:0] uart_txd   = DUT.U_APB_UART.UART_TX_DATA_REG;
    wire [ 1:0] uart_baud  = DUT.U_APB_UART.UART_BAUD_REG;
    wire [31:0] uart_stat  = DUT.U_APB_UART.UART_STATUS_REG;

    // ── 클럭 생성 ──────────────────────────────
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ── 초기값 ─────────────────────────────────
    initial begin
        Uart_rx       = 1'b1;    // UART idle = 1
        GPI           = 8'hA5;   // GPI 고정 입력
        gpio_drive_val = 16'h5A00; // GPIO 상위 8비트 TB 드라이브
        gpio_drive_en  = 16'hFF00; // 상위만 TB 드라이브
        pass_cnt      = 0;
        fail_cnt      = 0;
        apb_err_cnt   = 0;
    end

    // ===========================================================
    //  태스크: 클럭 대기
    // ===========================================================
    task wait_clk;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
        end
    endtask

    // ===========================================================
    //  태스크: PASS/FAIL 출력
    // ===========================================================
    task check;
        input [255:0] test_name;  // string as bit vector
        input [31:0]  got;
        input [31:0]  expected;
        begin
            if (got === expected) begin
                $display("[PASS] %s  got=0x%08X", test_name, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] %s  got=0x%08X  exp=0x%08X",
                         test_name, got, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task check_mask;
        input [255:0] test_name;
        input [31:0]  got;
        input [31:0]  mask;
        input [31:0]  expected;
        begin
            if ((got & mask) === (expected & mask)) begin
                $display("[PASS] %s  got=0x%08X (mask=0x%08X)", test_name, got, mask);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] %s  got=0x%08X  exp=0x%08X (mask=0x%08X)",
                         test_name, got, expected, mask);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ===========================================================
    //  APB 프로토콜 모니터 (백그라운드 always 블록)
    //  SETUP(psel=1, penable=0) → ACCESS(psel=1, penable=1) 순서 검사
    // ===========================================================
    reg  apb_in_setup;
    wire apb_psel_any = w_psel0 | w_psel1 | w_psel2 |
                        w_psel3 | w_psel4 | w_psel5;

    initial apb_in_setup = 1'b0;

    always @(posedge clk) begin
        if (!rst) begin
            if (apb_psel_any && !w_penable)
                apb_in_setup <= 1'b1;
            else if (apb_psel_any && w_penable) begin
                if (!apb_in_setup) begin
                    $display("[WARN] t=%0t APB ACCESS without SETUP!", $time);
                    apb_err_cnt = apb_err_cnt + 1;
                end
                apb_in_setup <= 1'b0;
            end else
                apb_in_setup <= 1'b0;
        end
    end

    // ===========================================================
    //  APB 버스 트레이스 (`define VERBOSE 시 활성화)
    // ===========================================================
`ifdef VERBOSE
    always @(posedge clk) begin
        if (!rst && w_penable) begin
            if (w_pwrite)
                $display("[APB-W] t=%0t addr=0x%08X wdata=0x%08X sel=%b%b%b%b%b%b",
                    $time, w_paddr, w_pwdata,
                    w_psel5,w_psel4,w_psel3,w_psel2,w_psel1,w_psel0);
            else
                $display("[APB-R] t=%0t addr=0x%08X rdata=0x%08X sel=%b%b%b%b%b%b",
                    $time, w_paddr, w_bus_rdata,
                    w_psel5,w_psel4,w_psel3,w_psel2,w_psel1,w_psel0);
        end
    end
`endif

    // ===========================================================
    //  UART TX 모니터 (병렬 스레드)
    //  Uart_tx 라인을 감시, 수신 바이트를 디코딩 후 출력
    //  115200 baud, CLK=100MHz → 1bit ≈ 868 클럭
    // ===========================================================
    localparam UART_BIT_CLK = 868;

    reg [7:0] uart_mon_buf [0:63];
    integer   uart_mon_ptr;
    initial   uart_mon_ptr = 0;

    // "Hello RV32I\r\n" = 14 바이트
    initial begin : uart_monitor_thread
        integer bi;
        reg [7:0] rbyte;
        integer   num_bytes;
        num_bytes = 14;

        repeat (num_bytes) begin
            // start bit 감지 (Uart_tx 1→0)
            @(negedge Uart_tx);
            // start bit 중앙으로 이동
            #(CLK_PERIOD * UART_BIT_CLK / 2);
            rbyte = 8'h00;
            for (bi = 0; bi < 8; bi = bi + 1) begin
                #(CLK_PERIOD * UART_BIT_CLK);
                rbyte[bi] = Uart_tx;
            end
            // stop bit
            #(CLK_PERIOD * UART_BIT_CLK);
            $display("[UART-MON] byte[%0d] = 0x%02X '%s'",
                uart_mon_ptr, rbyte,
                (rbyte >= 8'h20 && rbyte <= 8'h7E) ? $sformatf("%c", rbyte) : ".");
            if (uart_mon_ptr < 64) begin
                uart_mon_buf[uart_mon_ptr] = rbyte;
                uart_mon_ptr = uart_mon_ptr + 1;
            end
        end

        // "Hello RV32I\r\n" 검증
        begin
            // "H"=0x48
            if (uart_mon_buf[0] === 8'h48) begin
                $display("[PASS] UART 첫 바이트 'H' (0x48) 확인");
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] UART 첫 바이트 got=0x%02X exp=0x48", uart_mon_buf[0]);
                fail_cnt = fail_cnt + 1;
            end
            // "\r"=0x0D, "\n"=0x0A
            if (uart_mon_buf[12] === 8'h0D && uart_mon_buf[13] === 8'h0A) begin
                $display("[PASS] UART 마지막 \\r\\n (0x0D 0x0A) 확인");
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] UART \\r\\n got=0x%02X 0x%02X exp=0x0D 0x0A",
                         uart_mon_buf[12], uart_mon_buf[13]);
                fail_cnt = fail_cnt + 1;
            end
        end
    end

    // ===========================================================
    //  메인 테스트 시퀀스
    // ===========================================================
    integer timeout;

    initial begin
        $display("====================================================");
        $display("  RV32I MCU Testbench  (CLK=100MHz)");
        $display("  mem file: APB_TEST_C.mem");
        $display("====================================================");

        // ── 리셋 ──
        rst = 1'b1;
        wait_clk(10);
        rst = 1'b0;
        $display("\n[RST] 해제 완료, 시뮬레이션 시작");

        // ==========================================================
        //  TEST 9: RST 직후 PC = 0 확인
        // ==========================================================
        $display("\n--- [T9] RST 후 PC 초기화 ---");
        wait_clk(2);
        check("PC after RST", DUT.instr_addr, 32'h0);

        // ==========================================================
        //  TEST 1: 1~10 합산 → FND_REG = 55
        //  startup → main 진입 → LUI+SW → delay(200) → GPO 설정 순
        //  FND 레지스터(GPIO_O_REG)에 55 쓰일 때까지 대기
        // ==========================================================
        $display("\n--- [T1] 1~10 합산, FND=55 ---");
        timeout = 0;
        while (fnd_reg !== 16'd55 && timeout < 100_000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= 100_000)
            $display("[FAIL] T1: FND=55 타임아웃 (%0d clk)", timeout);
        else
            check("FND_REG = 55", {16'h0, fnd_reg}, 32'd55);

        // ==========================================================
        //  TEST 2: GPO Walking LED
        //  GPO_CTL=0xFF → ODATA: 0x01→0x02→...→0x80→0xFF→0x00
        // ==========================================================
        $display("\n--- [T2] GPO Walking LED ---");

        // CTL = 0xFF 대기
        timeout = 0;
        while (gpo_ctl !== 8'hFF && timeout < 200_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPO_CTL = 0xFF", {24'h0, gpo_ctl}, 32'hFF);

        // Walking 0x01
        timeout = 0;
        while (gpo_odata !== 8'h01 && timeout < 200_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPO Walking = 0x01", {24'h0, gpo_odata}, 32'h01);

        // Walking 0x80
        timeout = 0;
        while (gpo_odata !== 8'h80 && timeout < 1_500_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPO Walking = 0x80", {24'h0, gpo_odata}, 32'h80);

        // 전체 ON = 0xFF
        timeout = 0;
        while (gpo_odata !== 8'hFF && timeout < 200_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPO Walking = 0xFF (전체 ON)", {24'h0, gpo_odata}, 32'hFF);

        // 전체 OFF = 0x00
        timeout = 0;
        while (gpo_odata !== 8'h00 && timeout < 200_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPO Walking = 0x00 (전체 OFF)", {24'h0, gpo_odata}, 32'h00);

        // ==========================================================
        //  TEST 3: GPO + FND 바이너리 카운터 (0~15)
        //  GPO_ODATA == FND_REG 동일 값인지 샘플링 확인
        // ==========================================================
        $display("\n--- [T3] GPO+FND 바이너리 카운터 ---");
        begin
            integer match;
            integer samp;
            // cnt=5 구간 대기
            timeout = 0;
            while (gpo_odata !== 8'h05 && timeout < 2_000_000) begin
                @(posedge clk); timeout = timeout + 1;
            end
            match = 0;
            for (samp = 0; samp < 8; samp = samp + 1) begin
                wait_clk(1);
                if (gpo_odata[3:0] === fnd_reg[3:0])
                    match = match + 1;
            end
            if (match >= 5) begin
                $display("[PASS] GPO == FND 카운터 동기 (%0d/8 samples)", match);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] GPO != FND 카운터 (%0d/8 samples)", match);
                fail_cnt = fail_cnt + 1;
            end
        end

        // ==========================================================
        //  TEST 4: GPI(0xA5) → GPO 에코
        // ==========================================================
        $display("\n--- [T4] GPI(0xA5) → GPO 에코 ---");
        GPI = 8'hA5;
        timeout = 0;
        while (gpo_odata !== 8'hA5 && timeout < 3_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPI Echo: GPO_ODATA = 0xA5", {24'h0, gpo_odata}, 32'hA5);
        check("GPI Echo: FND = 0xA5",       {16'h0, fnd_reg},   32'hA5);

        // GPI 값 변경
        GPI = 8'h3C;
        timeout = 0;
        while (gpo_odata !== 8'h3C && timeout < 500_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPI Echo: GPO_ODATA = 0x3C (입력변경)", {24'h0, gpo_odata}, 32'h3C);

        // ==========================================================
        //  TEST 5: GPIO 양방향
        //  DUT 하위 8비트 출력 0xAA, 상위 8비트 TB에서 0x5A 드라이브
        // ==========================================================
        $display("\n--- [T5] GPIO 양방향 ---");
        // CTL = 0x00FF 대기
        timeout = 0;
        while (gpio_ctl !== 16'h00FF && timeout < 5_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPIO_CTL = 0x00FF (하위=out, 상위=in)",
              {16'h0, gpio_ctl}, 32'h00FF);

        // ODATA = 0x00AA 대기
        timeout = 0;
        while (gpio_odata !== 16'h00AA && timeout < 500_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPIO_ODATA = 0x00AA", {16'h0, gpio_odata}, 32'h00AA);

        // 상위 8비트 입력 확인 (TB에서 0x5A 드라이브)
        wait_clk(10);
        check_mask("GPIO_IDATA[15:8] = 0x5A (TB 드라이브)",
                   {16'h0, gpio_idata}, 32'h0000FF00, 32'h00005A00);

        // ODATA = 0x0055 패턴 반전
        timeout = 0;
        while (gpio_odata !== 16'h0055 && timeout < 500_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("GPIO_ODATA = 0x0055 (패턴반전)", {16'h0, gpio_odata}, 32'h0055);

        // ==========================================================
        //  TEST 6: FND 0~99 카운트
        // ==========================================================
        $display("\n--- [T6] FND 카운트 0~99 ---");
        timeout = 0;
        while (fnd_reg !== 16'd20 && timeout < 8_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("FND count = 20", {16'h0, fnd_reg}, 32'd20);

        timeout = 0;
        while (fnd_reg !== 16'd70 && timeout < 8_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("FND count = 70", {16'h0, fnd_reg}, 32'd70);

        // ==========================================================
        //  TEST 7: UART TX 설정 확인
        //  (실제 바이트 수신은 uart_monitor_thread에서 병렬 처리)
        // ==========================================================
        $display("\n--- [T7] UART TX 설정 확인 ---");
        timeout = 0;
        while (uart_baud !== 2'b10 && timeout < 15_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("UART BAUD_REG = 2 (115200baud)", {30'h0, uart_baud}, 32'd2);

        // TX_DATA_REG = 'H' (0x48) 대기
        timeout = 0;
        while (uart_txd !== 8'h48 && timeout < 2_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("UART TX_DATA = 'H' (0x48)", {24'h0, uart_txd}, 32'h48);

        // Uart_tx start bit 감지
        timeout = 0;
        while (Uart_tx !== 1'b0 && timeout < 5_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        if (timeout < 5_000_000) begin
            $display("[PASS] Uart_tx: start bit 감지");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] Uart_tx: start bit 미감지 (타임아웃)");
            fail_cnt = fail_cnt + 1;
        end

        // ==========================================================
        //  TEST 8: APB 프로토콜 오류 누적 결과
        // ==========================================================
        $display("\n--- [T8] APB 프로토콜 ---");
        if (apb_err_cnt === 0) begin
            $display("[PASS] APB 프로토콜 위반 없음");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] APB 프로토콜 위반 %0d건", apb_err_cnt);
            fail_cnt = fail_cnt + 1;
        end

        // ==========================================================
        //  FINAL: 종료 루프 확인 (GPO=0xFF, FND=55)
        // ==========================================================
        $display("\n--- [FINAL] 종료 상태 확인 ---");
        timeout = 0;
        while (!(gpo_odata === 8'hFF && fnd_reg === 16'd55) && timeout < 30_000_000) begin
            @(posedge clk); timeout = timeout + 1;
        end
        check("FINAL GPO_ODATA = 0xFF", {24'h0, gpo_odata}, 32'hFF);
        check("FINAL FND_REG   = 55",   {16'h0, fnd_reg},   32'd55);

        // UART 모니터 완료 대기
        wait_clk(UART_BIT_CLK * 12 * 14);   // 14 bytes worth

        // ==========================================================
        //  결과 요약
        // ==========================================================
        $display("\n====================================================");
        $display("  시뮬레이션 완료  @%0t", $time);
        $display("  PASS : %0d", pass_cnt);
        $display("  FAIL : %0d", fail_cnt);
        if (fail_cnt === 0)
            $display("  ★ ALL TESTS PASSED ★");
        else
            $display("  ✗ %0d TEST(S) FAILED — 위 로그 확인", fail_cnt);
        $display("====================================================");

        $finish;
    end

    // ===========================================================
    //  파형 덤프 (VCD)
    // ===========================================================
    initial begin
        $dumpfile("tb_rv32i_mcu.vcd");
        $dumpvars(0, tb_rv32i_mcu);
    end

    // ===========================================================
    //  전역 타임아웃 500ms
    // ===========================================================
    initial begin
        #500_000_000;
        $display("[TIMEOUT] 500ms 초과, 강제 종료");
        $display("  PASS=%0d  FAIL=%0d (미완)", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
