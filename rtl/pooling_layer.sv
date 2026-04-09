module pooling_layer#(
    parameter SIZE_MATRIX     =  4,
    parameter WIDTH           =  8,
    parameter SIZE_IMAGE      =  64,
    parameter WIDTH_OUT       =  4*WIDTH,
    parameter NUM_FILTERS     =  4,
    parameter POOL_SIZE       =  2,
    parameter STRIDE          =  2,  // шаг 
    parameter CONV_SIZE       =  SIZE_IMAGE - SIZE_MATRIX + 1,
    parameter SIZE_OUT        =  (CONV_SIZE - POOL_SIZE)/STRIDE + 1
)
(
    input   logic  signed  [WIDTH_OUT-1:0]         conv_matrix_i      [0:NUM_FILTERS-1][0:CONV_SIZE-1 ][0:CONV_SIZE-1 ],

    output  logic  signed  [WIDTH_OUT-1:0]         pooling_matrix_o   [0:NUM_FILTERS-1][0:SIZE_OUT-1][0:SIZE_OUT-1]

    );

    logic  signed  [WIDTH_OUT-1:0]         max;
    
    always_comb begin
        // for (int ff=0; ff < NUM_FILTERS; ff++ ) begin
        //     for ( int yy=0; yy < SIZE_OUT; yy++ ) begin
        //         for ( int xx=0; xx < SIZE_OUT; xx++) begin
        //             pooling_matrix_o[ff][yy][xx]  = '0;
        //         end
        //     end
        // end 
        // if ( done_conv_i ) begin
            for (int f=0; f < NUM_FILTERS; f++ ) begin
                for ( int y=0, y_n=0; y <= CONV_SIZE-POOL_SIZE; y = y + STRIDE, y_n = y_n + 1 ) begin
                    for ( int x=0, x_n=0; x <= CONV_SIZE-POOL_SIZE; x = x + STRIDE, x_n = x_n + 1 ) begin
                        max = conv_matrix_i[f][y][x];

                        if (max < conv_matrix_i[f][y][x+1])
                            max = conv_matrix_i[f][y][x+1];

                        if (max < conv_matrix_i[f][y+1][x])
                            max = conv_matrix_i[f][y+1][x];

                        if (max < conv_matrix_i[f][y+1][x+1])
                            max = conv_matrix_i[f][y+1][x+1];
                        pooling_matrix_o[f][y_n][x_n]  =  max;
                    end
                end
            end
        end


endmodule
