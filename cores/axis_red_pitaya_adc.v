
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
  
  reg [31:0] int_m_axis_tdata;
     
  reg signed [16:0] sum_signed;   
  reg [16:0] int_sum_reg;
  reg [16:0] int_p_sum_reg;
  
  reg f_send;
  reg [8:0] burst_counter; 
  reg [59:0] samples_counter;
  
  //Для отправки счетчика
  reg [59:0] series_start;  //Хранит значение счетчика когда стартовала серия
  reg [32:0] series_counter;    //Номер семпла в серии
    

  always @(posedge aclk or negedge aresetn)
  begin
    if (!aresetn) begin
        burst_counter   <= 0;
        f_send          <= 0;
        series_counter  <= 0;
        int_out_a_reg   <= 0;
        int_out_b_reg   <= 0;
        samples_counter <= 0;
        series_start    <= 0;
        int_m_axis_tdata <=0;

    end else begin
        samples_counter <= samples_counter+1;
        
        int_dat_a_reg <= adc_dat_a[15:2];
        int_dat_b_reg <= adc_dat_b[15:2];
        
        int_out_a_reg <= {{(3){int_dat_a_reg[14-1]}}, ~int_dat_a_reg[14-2:0]};                
        int_out_b_reg <= {{(3){int_dat_b_reg[14-1]}}, ~int_dat_b_reg[14-2:0]};
       
        
       
        // сумма как signed
        sum_signed = $signed(int_out_a_reg) - $signed(int_out_b_reg);    

        int_p_sum_reg <= int_sum_reg;
        int_sum_reg <= sum_signed[16] ? -sum_signed : sum_signed;       // берем модуль (по модулю, unsigned)
        
        if (f_send) begin
            //int_m_axis_tdata <= {int_out_b_reg, int_out_a_reg};
            
            if (series_counter == 1)
            begin
                int_m_axis_tdata <= {{32'd1}};
                series_counter <= series_counter + 1;
                burst_counter <= burst_counter + 1;
            end

            else if (series_counter == 2)
            begin
                int_m_axis_tdata <= {{32'd2}};
                series_counter <= series_counter + 1;
                burst_counter <= burst_counter + 1;
            end
            else
            begin                                            
                if (int_sum_reg > trg_lvl) begin   //для обеспечения burst. Надо слать кратно 16
                    int_m_axis_tdata <= {32'd3};
                    series_counter <= series_counter + 1;
                    burst_counter <= burst_counter + 1;
                end else begin 
                    if (burst_counter != 0)
                    begin
                        int_m_axis_tdata <= {32'd4};
                        series_counter <= series_counter + 1;
                        burst_counter <= burst_counter + 1;                        
                    end else begin
                        int_m_axis_tdata <= {32'd5};
                        series_counter <= 0;
                        f_send <= 0;                        
                    end
                end                
            end                    

        end else begin            
            //if (int_sum_reg >= trg_lvl && int_p_sum_reg < trg_lvl) begin
            if (int_sum_reg >= trg_lvl) begin
               f_send       <= 1;
               series_start <= samples_counter;
               series_counter <= 1;
            end
            else
            begin
                int_m_axis_tdata <= {{32'd0}};
            end
        end 
        
     end
  end

  assign adc_csn = 1'b1;

  assign m_axis_tvalid = f_send;

  assign m_axis_tdata = int_m_axis_tdata;

endmodule
