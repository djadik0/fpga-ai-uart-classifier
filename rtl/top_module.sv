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
    parameter FC_INPUTS     =  NUM_FILTERS * SIZE_OUT * SIZE_OUT,
    parameter WEIGHT_WIDTH  =  8
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic load_mode,

    output logic done_arg,
    output logic [$clog2(OBJECTS)-1:0] class_id,

    input  logic                           load_en_image,
    input  logic                           load_we_image,
    input  logic [WIDTH-1:0]               load_image_data,
    input  logic [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_y,
    input  logic [$clog2(SIZE_IMAGE)-1:0]  load_image_adres_x
);

    logic done_conv;
    logic done_pool;
    logic done_fc_o;
    logic done_arg_int;

    logic start_conv;
    logic start_pool;
    logic start_fc;

    logic [$clog2(SIZE_MATRIX)-1:0] conv_adres_x;
    logic [$clog2(SIZE_MATRIX)-1:0] conv_adres_y;
    logic                           conv_en_weights;
    logic [$clog2(NUM_FILTERS)-1:0] conv_filter;

    logic conv_en_fragment;
    logic [$clog2(SIZE_IMAGE)-1:0] conv_frag_y;
    logic [$clog2(SIZE_IMAGE)-1:0] conv_frag_x;

    logic conv_valid_s;
    logic signed [WIDTH_OUT-1:0] conv_data_s;
    logic [$clog2(NUM_FILTERS)-1:0] conv_filter_s;
    logic [$clog2(SIZE_IMAGE)-1:0] conv_y_s;
    logic [$clog2(SIZE_IMAGE)-1:0] conv_x_s;

    logic signed [WIDTH-1:0] mem_weights_out;
    logic mem_weights_valid;

    logic [WIDTH-1:0] mem_fragment_out [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic mem_fragment_valid;

    logic mac_start;
    logic mac_done;
    logic [WIDTH-1:0] mac_A [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic signed [WIDTH-1:0] mac_B [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic signed [WIDTH_OUT-1:0] mac_result;

    logic [$clog2(NUM_FILTERS)-1:0] mem_filter;
    logic [$clog2(SIZE_MATRIX)-1:0] mem_adres_x;
    logic [$clog2(SIZE_MATRIX)-1:0] mem_adres_y;
    logic mem_en_weights;
    logic mem_we_weights;
    logic signed [WIDTH-1:0] mem_weights_data;

    logic mem_en_image;
    logic mem_we_image;
    logic [WIDTH-1:0] mem_image_data;
    logic [$clog2(SIZE_IMAGE)-1:0] mem_image_adres_y;
    logic [$clog2(SIZE_IMAGE)-1:0] mem_image_adres_x;

    logic signed [WIDTH_OUT-1:0] pool_value;
    logic pool_valid;
    logic en_pool_r;
    logic [$clog2(FC_INPUTS)-1:0] pool_idx;

    logic signed [WIDTH_OUT*2-1:0] fc_out_o [0:OBJECTS-1];

    logic signed [WEIGHT_WIDTH-1:0] weight_value;
    logic weight_valid;
    logic en_fc_r;
    logic [$clog2(OBJECTS)-1:0] class_idx;
    logic [$clog2(FC_INPUTS)-1:0] weight_idx;

    enum logic [1:0] {
        TM_IDLE,
        TM_WAIT_POOL,
        TM_WAIT_FC,
        TM_WAIT_ARG
    } state;

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
            mem_en_image      = load_en_image;
            mem_we_image      = load_we_image;
            mem_image_data    = load_image_data;
            mem_image_adres_y = load_image_adres_y;
            mem_image_adres_x = load_image_adres_x;
        end
        else begin
            mem_filter     = conv_filter;
            mem_adres_x    = conv_adres_x;
            mem_adres_y    = conv_adres_y;
            mem_en_weights = conv_en_weights;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state      <= TM_IDLE;
            start_conv <= 1'b0;
            start_pool <= 1'b0;
            start_fc   <= 1'b0;
        end
        else begin
            start_conv <= 1'b0;
            start_pool <= 1'b0;
            start_fc   <= 1'b0;

            case (state)
                TM_IDLE: begin
                    if (start && !load_mode) begin
                        start_conv <= 1'b1;
                        start_pool <= 1'b1;
                        state      <= TM_WAIT_POOL;
                    end
                end

                TM_WAIT_POOL: begin
                    if (done_pool) begin
                        start_fc <= 1'b1;
                        state    <= TM_WAIT_FC;
                    end
                end

                TM_WAIT_FC: begin
                    if (done_fc_o) begin
                        state <= TM_WAIT_ARG;
                    end
                end

                TM_WAIT_ARG: begin
                    if (done_arg_int) begin
                        state <= TM_IDLE;
                    end
                end

                default: state <= TM_IDLE;
            endcase
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
        .start(start_conv),
        .done(done_conv),

        .conv_valid_o(conv_valid_s),
        .conv_data_o(conv_data_s),
        .conv_filter_o(conv_filter_s),
        .conv_y_o(conv_y_s),
        .conv_x_o(conv_x_s),

        .weights_i(mem_weights_out),
        .weights_valid(mem_weights_valid),
        .adres_x(conv_adres_x),
        .adres_y(conv_adres_y),
        .en_o_weights(conv_en_weights),

        .fragment_valid(mem_fragment_valid),
        .fragment_i(mem_fragment_out),
        .en_fragment(conv_en_fragment),
        .frag_y_o(conv_frag_y),
        .frag_x_o(conv_frag_x),

        .filter(conv_filter),
        .done_mac(mac_done),
        .conv_result(mac_result),

        .fragment_o(mac_A),
        .ves(mac_B),
        .start_mac(mac_start)
    );

    pooling_layer #(
        .SIZE_MATRIX(SIZE_MATRIX),
        .WIDTH(WIDTH),
        .SIZE_IMAGE(SIZE_IMAGE),
        .WIDTH_OUT(WIDTH_OUT),
        .NUM_FILTERS(NUM_FILTERS),
        .POOL_SIZE(POOL_SIZE),
        .STRIDE(STRIDE),
        .CONV_SIZE(CONV_SIZE),
        .SIZE_OUT(SIZE_OUT)
    ) u_pooling_layer (
        .clk(clk),
        .rst(rst),
        .start(start_pool),

        .conv_valid_i(conv_valid_s),
        .conv_data_i(conv_data_s),
        .conv_filter_i(conv_filter_s),
        .conv_y_i(conv_y_s),
        .conv_x_i(conv_x_s),

        .pool_rd_en_i(en_pool_r),
        .pool_rd_addr_i(pool_idx),
        .pool_rd_data_o(pool_value),
        .pool_rd_valid_o(pool_valid),

        .done(done_pool)
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

    fc_layer #(
        .SIZE_MATRIX(SIZE_MATRIX),
        .WIDTH(WIDTH),
        .SIZE_IMAGE(SIZE_IMAGE),
        .WIDTH_OUT(WIDTH_OUT),
        .NUM_FILTERS(NUM_FILTERS),
        .POOL_SIZE(POOL_SIZE),
        .STRIDE(STRIDE),
        .CONV_SIZE(CONV_SIZE),
        .SIZE_OUT(SIZE_OUT),
        .OBJECTS(OBJECTS),
        .FC_INPUTS(FC_INPUTS),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) u_fc_layer (
        .clk(clk),
        .rst(rst),
        .start_fc(start_fc),

        .weight_value_i(weight_value),
        .weight_valid_i(weight_valid),

        .pool_value_i(pool_value),
        .pool_valid_i(pool_valid),

        .en_fc_r(en_fc_r),
        .en_pool_r(en_pool_r),

        .fc_out_o(fc_out_o),
        .done_fc_o(done_fc_o),
        .class_idx_o(class_idx),
        .weight_idx_o(weight_idx),
        .pool_idx_o(pool_idx)
    );

    fc_weight_memory #(
        .OBJECTS(OBJECTS),
        .FC_INPUTS(FC_INPUTS),
        .WEIGHT_WIDTH(WEIGHT_WIDTH)
    ) u_fc_weight_memory (
        .clk(clk),
        .rst(rst),
        .en_fc_r(en_fc_r),
        .class_idx(class_idx),
        .weight_idx(weight_idx),
        .weight_value_o(weight_value),
        .weight_valid_o(weight_valid)
    );

    argmax_layer #(
        .WIDTH(WIDTH),
        .WIDTH_OUT(WIDTH_OUT),
        .OBJECTS(OBJECTS)
    ) u_argmax_layer (
        .clk(clk),
        .rst(rst),
        .start_arg(done_fc_o),
        .fc_out_i(fc_out_o),
        .otvet(class_id),
        .done_arg(done_arg_int)
    );

    assign done_arg = done_arg_int;

endmodule