module uart_image_loader#(
    parameter WIDTH         =  8,
    parameter SIZE_IMAGE    =  64
)
(
  input   logic                           clk,
  input   logic                           rst,
  input   logic                           start_load_i,

  input   logic                           rx_valid_i, 
  input   logic [7:0]                     rx_data_i,

  output  logic                           busy_o,
  output  logic                           image_done_o,
  
  output  logic                           load_mode_o,
  output  logic                           load_en_image_o,
  output  logic                           load_we_image_o,
  output  logic [WIDTH-1:0]               load_image_data_o,
  output  logic [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_y_o,
  output  logic [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_x_o
);

    logic [$clog2(SIZE_IMAGE)-1:0]             x_idx;
    logic [$clog2(SIZE_IMAGE)-1:0]             y_idx;

    enum{ IDLE,
    LOAD,
    DONE } state;

    always_ff @( posedge clk or negedge rst ) begin
        if ( !rst ) begin 
            x_idx                 <=  '0;
            y_idx                 <=  '0;
            state                 <=  IDLE;
            load_en_image_o       <=  0;
            load_we_image_o       <=  0;
            load_image_data_o     <=  '0;
            load_image_adres_x_o  <=  '0;
            load_image_adres_y_o  <=  '0;
            busy_o                <=  0;
            image_done_o          <=  0;
            load_mode_o           <=  0;
        end
        else begin
            case ( state )

                IDLE: begin
                    load_mode_o   <=  0;
                    busy_o        <=  0;
                    image_done_o  <=  0;
                    if ( start_load_i ) begin
                        x_idx      <=  '0;
                        y_idx      <=  '0;
                        state      <=  LOAD;
                    end
                end

                LOAD: begin
                    load_mode_o       <=  1;
                    busy_o            <=  1;
                    load_en_image_o   <=  0;
                    load_we_image_o   <=  0;
                    if ( rx_valid_i ) begin 
                        load_en_image_o       <=  1;
                        load_we_image_o       <=  1;
                        load_image_data_o     <=  rx_data_i;
                        load_image_adres_x_o  <=  x_idx;
                        load_image_adres_y_o  <=  y_idx;
                        if ( x_idx == SIZE_IMAGE-1 && y_idx == SIZE_IMAGE-1)
                            state  <=  DONE;
                        else if ( x_idx < SIZE_IMAGE-1 )
                            x_idx  <=  x_idx + 1;
                        else if ( x_idx == SIZE_IMAGE-1 ) begin
                            y_idx  <=  y_idx + 1;
                            x_idx  <=  '0;
                        end 
                    end
                end

                DONE: begin 
                    image_done_o      <=  1;
                    busy_o            <=  0;
                    load_mode_o       <=  0;
                    load_en_image_o   <=  0;
                    load_we_image_o   <=  0;
                    state             <=  IDLE;
                end 
            endcase 
        end
    end

endmodule