module uart_rx#(
  parameter  CLK_FREQ      =  50_000_000,
  parameter  BAUD_RATE     =  115200,
  parameter  CLKS_PER_BIT  =  CLK_FREQ / BAUD_RATE
    // 1 start bit  формат
    // 8 data bits
    // no parity
    // 1 stop bit
)
(

  input    logic            clk,
  input    logic            rst,
  input    logic            rx_i,

  output   logic            busy_o,     // Сигнал о том, что модуль занят приёмом данных
  output   logic            rx_valid_o, // Сигнал о том, что прием данных завершён
  output   logic [7:0]      rx_data_o  // Принятые данные

);

  logic  [3:0]  bit_idx;
  logic  [7:0]  data_ff;
  logic  [8:0]  clk_cnt;
  logic         rx_ff_1;
  logic         rx_ff_2;

  enum {IDLE,
    START,
    DATA,
    STOP,
    DONE } state;
    
    always_ff @( posedge clk or negedge rst ) begin
        if ( !rst ) begin 
            rx_ff_1  <=  1;
            rx_ff_2  <=  1;
        end else begin
            rx_ff_1  <=  rx_i;
            rx_ff_2  <=  rx_ff_1;
        end
    end


    always_ff @( posedge clk or negedge rst ) begin
        if ( !rst ) begin 
            state       <=  IDLE;
            clk_cnt     <=  '0;
            bit_idx     <=  '0;
            data_ff     <=  '0;
            rx_valid_o  <=  0;
            busy_o      <=  0;
        end

        else begin 
            case ( state )
                IDLE: begin
                    busy_o      <=  0;
                    rx_valid_o  <=  0;
                    if ( rx_ff_2 == 0) begin 
                        state    <=  START;
                        clk_cnt  <=  '0;
                    end
                end

                START: begin 
                    busy_o   <=  1;
                    clk_cnt  <=  clk_cnt + 1;
                    if ( clk_cnt == (CLKS_PER_BIT-1)/2 ) begin 
                        if ( rx_ff_2 == 0 ) begin
                            state    <=  DATA;
                            bit_idx  <=  '0;
                            clk_cnt  <=  '0;
                        end
                        else 
                            state    <=  IDLE;
                    end
                end
                

                DATA: begin
                    busy_o   <=  1;
                    clk_cnt  <=  clk_cnt + 1;
                    if ( clk_cnt == CLKS_PER_BIT/2 - 1 ) begin  
                        data_ff[bit_idx]  <=  rx_ff_2;
                    end
                    
                    if ( clk_cnt == CLKS_PER_BIT-1 && bit_idx == 4'd7 ) begin
                        clk_cnt           <=  '0;
                        state             <=  STOP;
                    end
                    else if ( clk_cnt == CLKS_PER_BIT-1 ) begin 
                        bit_idx           <=  bit_idx + 1;
                        clk_cnt           <=  '0;
                    end
                end

                STOP: begin
                    busy_o   <=  1;
                    clk_cnt  <=  clk_cnt + 1;
                    if ( clk_cnt == CLKS_PER_BIT-1 ) begin
                        if ( rx_ff_2 == 1 ) 
                            state  <=  DONE;
                        else 
                            state  <=  IDLE;
                    end
                end

                DONE: begin
                    busy_o      <=  0;
                    rx_valid_o  <=  1;
                    state       <=  IDLE;
                    clk_cnt     <=  '0;
                end


            endcase 

        end

    end

    assign rx_data_o  =  data_ff;


endmodule