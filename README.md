# 🚀 RV32I & AMBA APB Bus Multi-Cycle Processor Design
> **온디바이스 AI 반도체 설계 1기** 프로젝트 (2026.03)

## 👥 팀원 소개 (Team Members)
* **강동우**: APB GPIO & APB FND 설계 및 검증
* **신성민**: APB Master, BRAM 설계 및 검증, FPGA Implementation
* **전정묵**: Multi-cycle RV32I Core 설계 및 검증, 전체 프로젝트 총괄
* **최수영**: APB UART 설계 및 검증

## 📝 프로젝트 개요 (Project Overview)
본 프로젝트는 **32Bit RISC-V 명령어 체계의 Data Path를 설계**하고, AMBA APB 버스 프로토콜을 이용해 **소프트웨어가 하드웨어(Peripheral)를 제어하는 CPU 메커니즘을 검증**하는 것을 목표로 합니다. Multi-cycle 아키텍처를 적용하여 복잡한 명령어를 효율적으로 처리하며, Memory-Mapped I/O (MMIO) 방식을 통해 다양한 주변장치(GPIO, FND, UART)를 성공적으로 제어합니다.

---

## 🏗️ 전체 시스템 구조 (System Architecture)

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 6쪽의 '전체 Block Diagram' 및 25쪽의 'Device Memory Space' 이미지를 캡처하여 삽입하세요. -->
> *(예시) ![System Architecture](./images/system_architecture.png)*

* **CPU**: RV32I Multi-cycle Processor
* **Bus**: AMBA APB Bus (Master & Address Decoder)
* **Slaves**: BRAM, GPIO, FND, UART

---

## 🧠 RV32I Multi-Cycle Core (전정묵)

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 7쪽의 'ASM Architecture' 및 Data Path 구조도 이미지를 삽입하세요. -->
> *(예시) ![ASM Architecture](./images/asm_architecture.png)*

* **지원 명령어**: 
  * S-Type (Word, Half, Byte Store)
  * B-Type (조건 분기 - BEQ, BNE 등)
  * IL-Type (Immediate Load)
  * J-Type (무조건 분기 - JAL, JALR)
* **주요 특징**: Multi-cycle 기반의 FSM 설계로 명령어의 효율적 분해 및 실행

---

## 🚌 APB Master & BRAM (신성민)

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 27쪽 'Master Block Diagram' 및 28쪽 'APB Master FSM' 이미지를 삽입하세요. -->
> *(예시) ![APB Master FSM](./images/apb_master_fsm.png)*

* APB 버스 마스터 제어기 (FSM 기반) 및 주소 디코더(Address Decoder) 구현
* 다중 슬레이브 통신 검증 (랜덤 요청, 데이터 입력, Wait State 제어)
* C-Code 기반 BRAM Load/Store 동작 완벽 연동

---

## 💡 APB GPIO & FND (강동우)

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 43~45쪽 'GPIO & FND Block Diagram' 이미지를 삽입하세요. -->
> *(예시) ![GPIO Block Diagram](./images/gpio_block_diagram.png)*

* 입력(GPI)/출력(GPO) 방향 제어 및 마스킹(Masking)이 가능한 안전한 레지스터 매핑
* FND(7-Segment) 디스플레이 출력을 위한 전용 APB 슬레이브 모듈 설계
* SW(C-Code)를 통한 스위치 입력 확인 및 LED/FND 실시간 제어 검증

---

## 🔌 APB UART (최수영)

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 54쪽 'UART Block Diagram' 및 55쪽 'Port Configuration Register' 이미지를 삽입하세요. -->
> *(예시) ![UART Configuration](./images/uart_config.png)*

* **기능**: PC와의 비동기 직렬 통신(RX/TX) 및 수신 데이터 안전성을 위한 RX FIFO 버퍼 구현
* **레지스터 구성**: CTL, BAUD, STATUS, TX_DATA, RX_DATA
* **동작 시나리오**: 
  1. GPIO 스위치(SW[0])를 통해 UART 활성화 제어
  2. PC로부터 데이터 수신 (RX_DONE 플래그 확인)
  3. 수신된 데이터를 내부 FND/LED에 반영
  4. 받은 데이터를 다시 PC로 송신 (TX Loopback 테스트 통과)

---

## 💻 소프트웨어 제어 시나리오 및 FPGA 검증

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 65쪽 'Initialization & 동작 시나리오 흐름도'를 삽입하세요. -->
> *(예시) ![SW Scenario](./images/sw_scenario.png)*

1. 주변장치 맵핑 및 초기화
2. SW[0] 상태 확인 (0일 경우 LED/FND 스위치 직접 제어)
3. SW[0] == 1일 경우 UART 모드 진입 (PC 입력 대기)
4. 수신 데이터를 바탕으로 하드웨어 제어 및 응답 송신

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 66쪽 'Working Video' 캡처본이나 구동 GIF를 삽입하세요. -->
> *(예시) ![FPGA Working](./images/fpga_working.gif)*

---

## 🛠️ 개발 환경 (Environment)
* **Language**: SystemVerilog, C
* **Simulation & Synthesis**: Xilinx Vivado
* **Target Board**: Digilent Basys-3 (Artix-7 FPGA)

---

## 🤔 결론 및 고찰 (Discussion)

<!-- 📸 [이미지 삽입 가이드] 여기에 PPT 69쪽 'Implementation Delay Analysis' 관련 다이어그램이나 Timing Report 캡처를 삽입하세요. -->
> *(예시) ![Timing Analysis](./images/timing_analysis.png)*

* **Implementation 딜레이 분석**: Multi-cycle 프로세서와 APB 버스 연동 시 라우팅(Routing) 및 물리적 배치에 따른 신호 지연(Delay) 발생 원인 분석
* **타이밍 최적화**: 클럭 도메인 동기화(Synchronizer) 및 레지스터 최적화를 통한 메타스테빌리티 방지와 안정적 하드웨어 구동 달성

---
*ⓒ 2026. On-device AI Semiconductor Design Course Project.*
