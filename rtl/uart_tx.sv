module uart_tx#(
  parameter  CLK_FREQ      =  50_000_000,
  parameter  BAUD_RATE     =  115200,
  parameter  CLKS_PER_BIT  =  CLK_FREQ / BAUD_RATE)
(
  input   logic            clk,
  input   logic            rst,
  input   logic            start_tx_i,  
  input   logic  [7:0]     tx_data_i,

  output  logic            tx_o,
  output  logic            busy_o,
  output  logic            tx_done_o

);
  logic  [3:0]  bit_idx;
  logic  [7:0]  data_ff;
  logic  [8:0]  clk_cnt;

  enum { IDLE,
    START,
    DATA,
    STOP,
    DONE } state;

   always_ff @( posedge clk or negedge rst ) begin
        if ( !rst ) begin 
            state       <=  IDLE;
            clk_cnt     <=  '0;
            bit_idx     <=  '0;
            data_ff     <=  '0;
            busy_o      <=  0;
            tx_o        <=  1;
            tx_done_o   <=  0;
        end

        else begin 
            case ( state )
                IDLE: begin
                    tx_o       <=  1;
                    busy_o     <=  0;
                    tx_done_o  <=  0;
                    if ( start_tx_i == 1 ) begin
                        bit_idx  <=  '0; 
                        data_ff  <=  tx_data_i;
                        clk_cnt  <=  '0;
                        state    <=  START;
                    end
                end

                START: begin 
                    tx_o     <=  0;
                    busy_o   <=  1;
                    clk_cnt  <=  clk_cnt + 1;
                    if ( clk_cnt == CLKS_PER_BIT-1 ) begin 
                        state    <=  DATA;
                        clk_cnt  <=  '0;
                    end
                end

                DATA: begin
                    busy_o   <=  1;
                    clk_cnt  <=  clk_cnt + 1;
                    tx_o     <=  data_ff[bit_idx];
                    if ( clk_cnt == CLKS_PER_BIT-1 && bit_idx == 4'd7 ) begin
                        clk_cnt  <=  '0;
                        state    <=  STOP;
                    end
                    else if ( clk_cnt == CLKS_PER_BIT-1 ) begin 
                            bit_idx  <=  bit_idx + 1;
                            clk_cnt  <=  '0;
                    end
                end

                STOP: begin
                    busy_o   <=  1;
                    clk_cnt  <=  clk_cnt + 1;
                    tx_o     <=  1;
                    if ( clk_cnt == CLKS_PER_BIT-1 ) 
                            state  <=  DONE;
                end

                DONE: begin
                    busy_o      <=  0;
                    tx_o        <=  1;
                    state       <=  IDLE;
                    clk_cnt     <=  '0;
                    tx_done_o   <=  1;
                end

            endcase 

        end

    end


endmodule