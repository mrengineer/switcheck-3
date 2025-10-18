
`timescale 1 ns / 1 ps

module axis_red_pitaya_adc #
(
  //parameter integer ADC_DATA_WIDTH = 14
)
(
  // System signals
  input  wire        aclk,

  // ADC signals
  output wire        adc_csn,
  input  wire [15:0] adc_dat_a,
  input  wire [15:0] adc_dat_b,

  // Master side
  output wire        m_axis_tvalid,
  output wire [31:0] m_axis_tdata
);
  localparam PADDING_WIDTH = 2;
  reg  [13:0] int_dat_a_reg;
  reg  [13:0] int_dat_b_reg;
  
  reg  [15:0] int_out_a_reg;
  reg  [15:0] int_out_b_reg;
   
  reg  [14:0] int_sum_reg;

  always @(posedge aclk)
  begin
    int_dat_a_reg <= adc_dat_a[15:2];
    int_dat_b_reg <= adc_dat_b[15:2];
    
    int_out_a_reg <= {{(PADDING_WIDTH+1){int_dat_a_reg[14-1]}}, ~int_dat_a_reg[14-2:0]};
    int_out_b_reg <= {{(PADDING_WIDTH+1){int_dat_b_reg[14-1]}}, ~int_dat_b_reg[14-2:0]};
   
    int_sum_reg <= 1;

  end

  assign adc_csn = 1'b1;

  assign m_axis_tvalid = 1'b1;

  assign m_axis_tdata = {int_out_b_reg, int_out_a_reg};

endmodule
