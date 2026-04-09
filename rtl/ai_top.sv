module ai_top#(
    parameter WIDTH         =  8,
    parameter SIZE_IMAGE    =  64,
    parameter OBJECTS       =  10
)(

  input   logic  clk,
  input   logic  rst,
  input   logic  rx_i,

  output  logic  tx_o

);

  logic                            rx_busy_o;

  logic                            start_tx_i;
  logic  [7:0]                     tx_data_i;
  logic                            tx_busy_o;
  logic                            tx_done_o;

  logic                            start_load_img;
  logic                            rx_valid_i;
  logic  [7:0]                     rx_data_i;
  logic                            load_busy_o;
  logic                            image_done_o;
  logic                            load_mode_o;
  logic                            load_en_image_o;
  logic                            load_we_image_o;
  logic  [7:0]                     load_image_data_o;
  logic  [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_y_o;
  logic  [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_x_o;

  logic                            start_AI;
  logic  [$clog2(OBJECTS)-1:0]     class_id;
  logic                            done_arg;

  uart_rx u_uart_rx (
    .clk(clk),
    .rst(rst),
    .rx_i(rx_i),
    .busy_o(rx_busy_o),
    .rx_valid_o(rx_valid_i), 
    .rx_data_o(rx_data_i)
  );
    
  uart_tx u_uart_tx(
    .clk(clk),
    .rst(rst),
    .start_tx_i(start_tx_i),
    .tx_data_i(tx_data_i),
    .tx_o(tx_o), 
    .busy_o(tx_busy_o),
    .tx_done_o(tx_done_o)
  );


  uart_image_loader u_uart_image_loader(
    .clk(clk),
    .rst(rst),
    .start_load_i(start_load_img),
    .rx_valid_i(rx_valid_i),
    .rx_data_i(rx_data_i), 
    .busy_o(load_busy_o),
    .image_done_o(image_done_o),
    .load_mode_o(load_mode_o),
    .load_en_image_o(load_en_image_o),
    .load_we_image_o(load_we_image_o),
    .load_image_data_o(load_image_data_o), 
    .load_image_adres_y_o(load_image_adres_y_o),
    .load_image_adres_x_o(load_image_adres_x_o)
  );


  top_module u_top_module(
    .clk(clk),
    .rst(rst),
    .start(start_AI),
    .load_mode(load_mode_o),
    .load_en_image(load_en_image_o),
    .load_we_image(load_we_image_o),
    .load_image_data(load_image_data_o), 
    .load_image_adres_y(load_image_adres_y_o),
    .load_image_adres_x(load_image_adres_x_o),
    .class_id(class_id),
    .done_arg(done_arg)
  );

  enum{ WAIT_CMD,
    START_LOAD,
    LOAD_IMAGE,
    START_AI,
    WAIT_AI,
    START_TX,
    WAIT_TX } state;

    always_ff @( posedge clk or negedge rst ) begin
        if ( !rst ) begin 
            state           <=  WAIT_CMD;
            start_load_img  <=  0;
            start_AI        <=  0;
            start_tx_i      <=  0;
            tx_data_i       <=  0;
        end

        else begin 

            start_load_img  <=  0;
            start_AI        <=  0;
            start_tx_i      <=  0;
            
            case ( state ) 

            WAIT_CMD: begin 
                if ( rx_valid_i && rx_data_i == 8'b10100101 ) begin
                    start_load_img  <=  1;
                    state           <=  START_LOAD;
                end
            end

            START_LOAD: begin
                start_load_img  <=  0;
                state           <=  LOAD_IMAGE; 
            end

            LOAD_IMAGE: begin
                if ( image_done_o ) begin 
                    start_AI  <=  1;
                    state     <=  START_AI;
                end
            end

            START_AI: begin 
                start_AI  <=  0;
                state     <=  WAIT_AI;
            end

            WAIT_AI: begin 
                if ( done_arg ) begin
                    tx_data_i   <=  class_id;
                    start_tx_i  <=  1;
                    state       <=  START_TX;
                end
            end

            START_TX: begin 
                start_tx_i  <=  0;
                state       <=  WAIT_TX;    
            end

            WAIT_TX: begin 
                if ( tx_done_o ) 
                    state  <=  WAIT_CMD;
            end 

        endcase
        end
    end

endmodule