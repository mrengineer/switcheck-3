
`timescale 1 ns / 1 ps

module axis_red_pitaya_adc #
(
  //parameter integer ADC_DATA_WIDTH = 14
)
(
  // System signals
  input  wire        aclk,
  input  wire        aresetn,      // Active-low reset  

  // ADC signals
  output wire        adc_csn,
  input  wire [15:0] adc_dat_a,
  input  wire [15:0] adc_dat_b,
  
  input  wire [16:0] trg_lvl,

  // Master side
  output wire        m_axis_tvalid,
  output wire [31:0] m_axis_tdata
);
  
  reg  [13:0] int_dat_a_reg;
  reg  [13:0] int_dat_b_reg;
  
  reg signed  [15:0] int_out_a_reg;
  reg signed  [15:0] int_out_b_reg;
     
  reg signed [16:0] sum_signed;   
  reg  [16:0] int_sum_reg;
  
  reg f_send;
  reg [31:0] send_counter;
   
    

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn) begin
        send_counter <= 0;
        f_send       <= 0;

    end else begin
  
        int_dat_a_reg <= adc_dat_a[15:2];
        int_dat_b_reg <= adc_dat_b[15:2];
        
        int_out_a_reg <= {{(3){int_dat_a_reg[14-1]}}, ~int_dat_a_reg[14-2:0]};
        int_out_b_reg <= {{(3){int_dat_b_reg[14-1]}}, ~int_dat_b_reg[14-2:0]};
       
        // сумма как signed
        sum_signed = $signed(int_out_a_reg) + $signed(int_out_b_reg);    
        int_sum_reg <= sum_signed[16] ? -sum_signed : sum_signed;       // берем модуль (по модулю, unsigned)
        
        if (f_send) begin            
            if (send_counter == ((4096*1024)-1)) begin
                f_send <= 0;
                send_counter <= 0;
            end else begin
                send_counter <= send_counter + 1;
            end            
        end else begin                                
            if (int_sum_reg >= trg_lvl) begin
               f_send <= 1;
               send_counter <= 0;
            end
        end 
        
     end
  end

  assign adc_csn = 1'b1;

  assign m_axis_tvalid = f_send; // 1'b1;

  assign m_axis_tdata = {int_out_b_reg, int_out_a_reg};

endmodule
