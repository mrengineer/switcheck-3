`timescale 1 ns / 1 ps

module tb_axis_red_pitaya_adc;

  // параметры моделирования
  localparam real CLK_PERIOD = 8.0;      // тактовая частота 125 МГц
  localparam real CLK_FREQ   = 1.0e9 / CLK_PERIOD; 

  reg clk = 0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  // сигналы для DUT
  wire        adc_csn;
  reg  [15:0] adc_dat_a;
  reg  [15:0] adc_dat_b;

  wire        m_axis_tvalid;
  wire [31:0] m_axis_tdata;
  
  reg [16:0] trg_lvl;
  reg aresetn;

  // параметры сигналов
  real f_a = 1.0e4;   // 0.01 МГц
  real f_b = 2.0e4;   // 0.02 МГц

  integer offset = 8192;   // середина шкалы (14 бит)
  integer ampl   = 8191;   // амплитуда (почти вся шкала)

  real t_ns = 0.0; // текущее время

  // DUT
  axis_red_pitaya_adc dut (
    .aclk          (clk),
    .aresetn       (aresetn),
    .adc_csn       (adc_csn),
    .adc_dat_a     (adc_dat_a),
    .adc_dat_b     (adc_dat_b),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tdata  (m_axis_tdata),
    .trg_lvl       (trg_lvl)
  );
    real va, vb;
    integer da, db;
  // генерация входных сигналов (НЕ синтезируемая часть, только TB)
  
  
  always @(posedge clk) begin
    t_ns = t_ns + CLK_PERIOD;

    va = $sin(2.0*3.1415926535*f_a*(t_ns*1e-9));
    vb = $sin(2.0*3.1415926535*f_b*(t_ns*1e-9));

    da = offset + $rtoi(ampl * va);
    db = offset + $rtoi(ampl * vb);

    // пакуем в 16 бит (сэмплы в [15:2], младшие два бита 0)
    adc_dat_a <= {da[13:0], 2'b00};
    adc_dat_b <= {db[13:0], 2'b00};
  end

  // выводим часть результатов
  initial begin
    trg_lvl = 16'd300;  // <── вот установка  уровня
    
    aresetn = 1'b0;     // начинаем с ресета

    // держим ресет 10 тактов
    repeat (10) @(posedge clk);
    aresetn = 1'b1;     // снимаем ресет    
    
    $dumpfile("tb_axis_red_pitaya_adc.vcd");
    $dumpvars(0, tb_axis_red_pitaya_adc);

    repeat (10000) @(posedge clk); // 10000 тактов
    $finish;
  end

endmodule
