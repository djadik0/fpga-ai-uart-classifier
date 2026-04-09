module fc_layer#(
    parameter SIZE_MATRIX     =  4,
    parameter WIDTH           =  8,
    parameter SIZE_IMAGE      =  64,
    parameter WIDTH_OUT       =  4*WIDTH,
    parameter NUM_FILTERS     =  4,
    parameter POOL_SIZE       =  2,
    parameter STRIDE          =  2,  
    parameter CONV_SIZE       =  SIZE_IMAGE - SIZE_MATRIX + 1,
    parameter SIZE_OUT        =  (CONV_SIZE - POOL_SIZE)/STRIDE + 1,
    parameter OBJECTS         =  10,
    parameter FC_INPUTS       =  NUM_FILTERS * SIZE_OUT * SIZE_OUT,
    parameter WEIGHT_WIDTH    =  8
)
(
    input   logic                                   clk,
    input   logic                                   rst,
    input   logic  signed  [WIDTH_OUT-1:0]          pooling_matrix_i   [0:NUM_FILTERS-1][0:SIZE_OUT-1][0:SIZE_OUT-1],
    input   logic                                   start_fc,
    input   logic  signed  [WEIGHT_WIDTH-1:0]       weight_value_i,

    output  logic  signed  [WIDTH_OUT*2-1:0]        fc_out_o     [0:OBJECTS-1],
    output  logic                                   done_fc_o,
    output  logic          [$clog2(OBJECTS)-1:0]    class_idx_o,
    output  logic          [$clog2(FC_INPUTS)-1:0]  weight_idx_o
    );


    logic  [$clog2(FC_INPUTS)-1:0]    weight_idx;
    logic  [$clog2(OBJECTS)-1:0]      neuron_idx;

    assign  class_idx_o   =  neuron_idx;
    assign  weight_idx_o  =  weight_idx;

    logic  signed [WIDTH_OUT*2-1:0]     sum;
    logic  signed [WIDTH_OUT*2-1:0]     fc_out_ff  [0:OBJECTS-1];
    logic  [$clog2(NUM_FILTERS)-1:0]  f_idx;
    logic  [$clog2(SIZE_OUT)-1:0]     y_idx;
    logic  [$clog2(SIZE_OUT)-1:0]     x_idx;


    enum { IDLE,
    INIT,
    CALC,
    STORE,
    DONE } state;

    always_ff @( posedge clk or negedge rst ) begin 
        if ( !rst ) begin 
            sum         <=  0;
            f_idx       <=  0;
            y_idx       <=  0;
            x_idx       <=  0;
            neuron_idx  <=  0;
            done_fc_o   <=  0;
            state       <=  IDLE;
            weight_idx  <=  0;
            for ( int ii=0; ii<OBJECTS; ii++) begin
                fc_out_ff[ii]  <=  0;
            end
        end 

        else case ( state ) 
            IDLE: begin
                done_fc_o   <=  0;
                if ( start_fc ) begin 
                    for ( int iii=0; iii<OBJECTS; iii++) begin
                        fc_out_ff[iii]  <=  0;
                    end
                    state  <= INIT;
                end
            end

            INIT: begin 
                weight_idx  <=  0;
                sum         <=  0;
                f_idx       <=  0;
                y_idx       <=  0;
                x_idx       <=  0;
                state       <=  CALC;
            end

            CALC: begin 
                if ( y_idx == SIZE_OUT-1 && x_idx == SIZE_OUT-1 && f_idx == NUM_FILTERS-1 ) begin
                    sum         <=  sum + pooling_matrix_i[f_idx][y_idx][x_idx] * weight_value_i;
                    state       <=  STORE;
                end
                else if ( y_idx == SIZE_OUT-1 && x_idx == SIZE_OUT-1 && f_idx != NUM_FILTERS-1 ) begin 
                    y_idx       <=  0;
                    x_idx       <=  0;
                    sum         <=  sum + pooling_matrix_i[f_idx][y_idx][x_idx] * weight_value_i;
                    f_idx       <=  f_idx + 1;
                    weight_idx  <=  weight_idx + 1;
                end
                else if ( x_idx == SIZE_OUT-1 ) begin 
                    x_idx       <=  0;
                    y_idx       <=  y_idx + 1;
                    sum         <=  sum + pooling_matrix_i[f_idx][y_idx][x_idx] * weight_value_i;
                    weight_idx  <=  weight_idx + 1;
                end
                else begin 
                    weight_idx  <=  weight_idx + 1;
                    x_idx       <=  x_idx + 1; 
                    sum         <=  sum + pooling_matrix_i[f_idx][y_idx][x_idx] * weight_value_i;
                end
            end

            STORE: begin 
                if ( neuron_idx == OBJECTS-1 ) begin
                    fc_out_ff[neuron_idx]  <=  sum;
                    state                  <=  DONE;
                end else begin
                    fc_out_ff[neuron_idx]  <=  sum;
                    neuron_idx             <=  neuron_idx + 1;
                    state                  <=  INIT;
                end
            end

            DONE: begin 
                done_fc_o   <=  1'b1;
                state       <=  IDLE;
                neuron_idx  <=  0;
            end
           

        endcase 
    end


    always_comb begin
        for ( int i=0; i<OBJECTS; i++) begin
            fc_out_o[i]  =  fc_out_ff[i];
        end
    end


endmodule

