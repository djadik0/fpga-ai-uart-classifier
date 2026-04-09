module top_module #(
    parameter SIZE_MATRIX   =  4,
    parameter WIDTH         =  8,
    parameter SIZE_IMAGE    =  64,
    parameter NUM_FILTERS   =  4,
    parameter WIDTH_OUT     =  4*WIDTH,
    parameter POOL_SIZE     =  2,
    parameter STRIDE        =  2,  
    parameter CONV_SIZE     =  SIZE_IMAGE - SIZE_MATRIX + 1,
    parameter SIZE_OUT      =  (CONV_SIZE - POOL_SIZE)/STRIDE + 1,
    parameter OBJECTS       =  10,
    parameter FC_INPUTS     =  3600,
    parameter WEIGHT_WIDTH  =  8
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic load_mode,

    output logic done_arg,
    output logic [$clog2(OBJECTS)-1:0]     class_id,

    // input  logic [$clog2(NUM_FILTERS)-1:0] load_filter,
    // input  logic [$clog2(SIZE_MATRIX)-1:0] load_adres_x,
    // input  logic [$clog2(SIZE_MATRIX)-1:0] load_adres_y,
    // input  logic                           load_en_weights,
    // input  logic                           load_we_weights,
    // input  logic  signed  [WIDTH-1:0]      load_weights_data,

    input  logic                           load_en_image,
    input  logic                           load_we_image,
    input  logic [WIDTH-1:0]               load_image_data,
    input  logic [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_y,
    input  logic [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_x
);

    logic                           done_conv;
    logic [$clog2(SIZE_MATRIX)-1:0] conv_adres_x;
    logic [$clog2(SIZE_MATRIX)-1:0] conv_adres_y;
    logic                           conv_en_weights;

    logic                           conv_en_fragment;
    logic [$clog2(SIZE_IMAGE)-1:0]  conv_frag_y;
    logic [$clog2(SIZE_IMAGE)-1:0]  conv_frag_x;
    logic  signed  [WIDTH_OUT-1:0]    out_conv [0:NUM_FILTERS-1][0:SIZE_IMAGE-SIZE_MATRIX][0:SIZE_IMAGE-SIZE_MATRIX];

    logic  signed  [WIDTH-1:0]      mem_weights_out;
    logic                           mem_weights_valid;

    logic [WIDTH-1:0]               mem_fragment_out [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic                           mem_fragment_valid;

    logic [$clog2(NUM_FILTERS)-1:0] conv_filter;


    logic                           mac_start;
    logic                           mac_done;
    logic [WIDTH-1:0]               mac_A [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic  signed  [WIDTH-1:0]      mac_B [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic  signed  [WIDTH_OUT-1:0]  mac_result;


    logic [$clog2(NUM_FILTERS)-1:0]    mem_filter;


    logic [$clog2(SIZE_MATRIX)-1:0]    mem_adres_x;
    logic [$clog2(SIZE_MATRIX)-1:0]    mem_adres_y;
    logic                              mem_en_weights;
    logic                              mem_we_weights;
    logic  signed  [WIDTH-1:0]         mem_weights_data;

    logic                              mem_en_image;
    logic                              mem_we_image;
    logic [WIDTH-1:0]                  mem_image_data;
    logic [$clog2(SIZE_IMAGE)-1:0]     mem_image_adres_y;
    logic [$clog2(SIZE_IMAGE)-1:0]     mem_image_adres_x;
    
    logic  signed [WIDTH_OUT*2-1:0]    fc_out_o[0:OBJECTS-1];
    logic                              done_fc_o;  
    
    logic  signed  [WEIGHT_WIDTH-1:0]  weight_value;
    logic   [$clog2(OBJECTS)-1:0]      class_idx;
    logic   [$clog2(FC_INPUTS)-1:0]    weight_idx;

    logic  signed  [WIDTH_OUT-1:0]     pooling_matrix_o[0:NUM_FILTERS-1][0:SIZE_OUT-1][0:SIZE_OUT-1];


    always_comb begin

        mem_filter        = '0;
        mem_adres_x       = '0;
        mem_adres_y       = '0;
        mem_en_weights    = 1'b0;
        mem_we_weights    = 1'b0;
        mem_weights_data  = '0;

        mem_en_image      = 1'b0;
        mem_we_image      = 1'b0;
        mem_image_data    = '0;
        mem_image_adres_y = '0;
        mem_image_adres_x = '0;

        if (load_mode) begin
   
            // mem_filter        = load_filter;
            // mem_adres_x       = load_adres_x;
            // mem_adres_y       = load_adres_y;
            // mem_en_weights    = load_en_weights;
            // mem_we_weights    = load_we_weights;
            // mem_weights_data  = load_weights_data;

            mem_en_image      = load_en_image;
            mem_we_image      = load_we_image;
            mem_image_data    = load_image_data;
            mem_image_adres_y = load_image_adres_y;
            mem_image_adres_x = load_image_adres_x;
        end
        else begin

            mem_filter        = conv_filter;
            mem_adres_x       = conv_adres_x;
            mem_adres_y       = conv_adres_y;
            mem_en_weights    = conv_en_weights;
            mem_we_weights    = 1'b0;
            mem_weights_data  = '0;

            mem_en_image      = 1'b0;
            mem_we_image      = 1'b0;
            mem_image_data    = '0;
            mem_image_adres_y = '0;
            mem_image_adres_x = '0;
        end
    end


    memory_buffer #(
        .WIDTH(WIDTH),
        .SIZE_IMAGE(SIZE_IMAGE),
        .SIZE_MATRIX(SIZE_MATRIX),
        .NUM_FILTERS(NUM_FILTERS)
    ) u_memory_buffer (
        .clk(clk),
        .rst(rst),

        .filter(mem_filter),

        .adres_x(mem_adres_x),
        .adres_y(mem_adres_y),
        .en_i_weights(mem_en_weights),
        .we_i_weights(mem_we_weights),
        .weights_data(mem_weights_data),
        .weights_out(mem_weights_out),
        .weights_valid(mem_weights_valid),

        .en_i_image(mem_en_image),
        .we_i_image(mem_we_image),
        .image_data(mem_image_data),
        .image_adres_y(mem_image_adres_y),
        .image_adres_x(mem_image_adres_x),
        .image_pixel_out(),

        .en_fragment(conv_en_fragment),
        .frag_y_i(conv_frag_y),
        .frag_x_i(conv_frag_x),
        .frag_out(mem_fragment_out),
        .fragment_valid(mem_fragment_valid)
    );

    conv_layer #(
        .SIZE_MATRIX(SIZE_MATRIX),
        .WIDTH(WIDTH),
        .SIZE_IMAGE(SIZE_IMAGE),
        .WIDTH_OUT(WIDTH_OUT),
        .NUM_FILTERS(NUM_FILTERS)
    ) u_conv_layer (
        .clk(clk),
        .rst(rst),
        .start(start && !load_mode),
        .done(done_conv),
        .out(out_conv),

        .weights_i(mem_weights_out),
        .weights_valid(mem_weights_valid),
        .adres_x(conv_adres_x),
        .adres_y(conv_adres_y),
        .en_o_weights(conv_en_weights),
        .filter(conv_filter),

        .fragment_valid(mem_fragment_valid),
        .fragment_i(mem_fragment_out),
        .en_fragment(conv_en_fragment),
        .frag_y_o(conv_frag_y),
        .frag_x_o(conv_frag_x),

        .done_mac(mac_done),
        .conv_result(mac_result),

        .fragment_o(mac_A),
        .ves(mac_B),
        .start_mac(mac_start)
    );

    pooling_layer #(
        .SIZE_MATRIX(SIZE_MATRIX),
        .WIDTH(WIDTH),
        .WIDTH_OUT(WIDTH_OUT),
        .STRIDE(STRIDE),
        .CONV_SIZE(CONV_SIZE),
        .SIZE_OUT(SIZE_OUT),
        .POOL_SIZE(POOL_SIZE),
        .NUM_FILTERS(NUM_FILTERS)
    ) u_pooling_layer(
        .conv_matrix_i(out_conv),
        .pooling_matrix_o(pooling_matrix_o)
    );


    conv_mac #(
        .SIZE_MATRIX(SIZE_MATRIX),
        .WIDTH(WIDTH),
        .RESULT(WIDTH_OUT)
    ) u_conv_mac (
        .clk(clk),
        .rst(rst),
        .start(mac_start),
        .done(mac_done),
        .A(mac_A),
        .B(mac_B),
        .result(mac_result)
    );


    fc_layer u_fc_layer(
        .clk(clk),
        .rst(rst),
        .pooling_matrix_i(pooling_matrix_o),
        .start_fc(done_conv),
        .fc_out_o(fc_out_o),
        .done_fc_o(done_fc_o),
        .weight_value_i(weight_value),
        .class_idx_o(class_idx),
        .weight_idx_o(weight_idx)
    );

    fc_weight_memory u_fc_weight_memory(
        .class_idx(class_idx),
        .weight_idx(weight_idx),
        .weight_value_o(weight_value)
    );

    argmax_layer u_argmax_layer(
        .clk(clk),
        .rst(rst),
        .start_arg(done_fc_o),
        .fc_out_i(fc_out_o),
        .otvet(class_id),
        .done_arg(done_arg)
    );



endmodule