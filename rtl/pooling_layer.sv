module pooling_layer#(
    parameter SIZE_MATRIX     =  4,
    parameter WIDTH           =  8,
    parameter SIZE_IMAGE      =  64,
    parameter WIDTH_OUT       =  4*WIDTH,
    parameter NUM_FILTERS     =  4,
    parameter POOL_SIZE       =  2,
    parameter STRIDE          =  2,
    parameter CONV_SIZE       =  SIZE_IMAGE - SIZE_MATRIX + 1,
    parameter SIZE_OUT        =  (CONV_SIZE - POOL_SIZE)/STRIDE + 1,
    parameter POOL_TOTAL      =  NUM_FILTERS * SIZE_OUT * SIZE_OUT,
    parameter POOL_ADDR_W     =  $clog2(POOL_TOTAL)
)
(
    input   logic                                clk,
    input   logic                                rst,
    input   logic                                start,

    input   logic                                conv_valid_i,
    input   logic  signed [WIDTH_OUT-1:0]        conv_data_i,
    input   logic  [$clog2(NUM_FILTERS)-1:0]     conv_filter_i,
    input   logic  [$clog2(SIZE_IMAGE)-1:0]      conv_y_i,
    input   logic  [$clog2(SIZE_IMAGE)-1:0]      conv_x_i,

    input   logic                                pool_rd_en_i,
    input   logic  [POOL_ADDR_W-1:0]             pool_rd_addr_i,
    output  logic  signed [WIDTH_OUT-1:0]        pool_rd_data_o,
    output  logic                                pool_rd_valid_o,

    output  logic                                done
);

    logic signed [WIDTH_OUT-1:0] top_row_max [0:SIZE_OUT-1];
    logic signed [WIDTH_OUT-1:0] bottom_left_ff;

    (* ram_style = "block" *)
    logic [WIDTH_OUT-1:0] pool_mem [0:POOL_TOTAL-1];

    logic [$clog2(SIZE_OUT)-1:0] pool_y_idx;
    logic [$clog2(SIZE_OUT)-1:0] pool_x_idx;

    logic                        pool_wr_en;
    logic [POOL_ADDR_W-1:0]      pool_wr_addr;
    logic signed [WIDTH_OUT-1:0] pool_wr_data;

    assign pool_y_idx = conv_y_i >> 1;
    assign pool_x_idx = conv_x_i >> 1;

    function automatic [POOL_ADDR_W-1:0] pool_index(
        input logic [$clog2(NUM_FILTERS)-1:0] f,
        input logic [$clog2(SIZE_OUT)-1:0]    y,
        input logic [$clog2(SIZE_OUT)-1:0]    x
    );
        pool_index = f * SIZE_OUT * SIZE_OUT + y * SIZE_OUT + x;
    endfunction

    function automatic signed [WIDTH_OUT-1:0] max2(
        input signed [WIDTH_OUT-1:0] a,
        input signed [WIDTH_OUT-1:0] b
    );
        begin
            if (a > b) max2 = a;
            else       max2 = b;
        end
    endfunction

    always_comb begin
        pool_wr_en   = 1'b0;
        pool_wr_addr = pool_index(conv_filter_i, pool_y_idx, pool_x_idx);
        pool_wr_data = '0;

        if (conv_valid_i &&
            (conv_y_i < CONV_SIZE-1) &&
            (conv_x_i < CONV_SIZE-1) &&
            (conv_y_i[0] == 1'b1) &&
            (conv_x_i[0] == 1'b1)) begin

            pool_wr_en   = 1'b1;
            pool_wr_data = max2(
                top_row_max[pool_x_idx],
                max2(bottom_left_ff, conv_data_i)
            );
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            done           <= 1'b0;
            bottom_left_ff <= '0;
            for (int i = 0; i < SIZE_OUT; i++) begin
                top_row_max[i] <= '0;
            end
        end
        else begin
            done <= 1'b0;

            if (start) begin
                bottom_left_ff <= '0;
                for (int i = 0; i < SIZE_OUT; i++) begin
                    top_row_max[i] <= '0;
                end
            end
            else if (conv_valid_i) begin
                if ((conv_y_i < CONV_SIZE-1) && (conv_x_i < CONV_SIZE-1)) begin
                    if (conv_y_i[0] == 1'b0) begin
                        if (conv_x_i[0] == 1'b0) begin
                            top_row_max[pool_x_idx] <= conv_data_i;
                        end
                        else begin
                            top_row_max[pool_x_idx] <= max2(top_row_max[pool_x_idx], conv_data_i);
                        end
                    end
                    else begin
                        if (conv_x_i[0] == 1'b0) begin
                            bottom_left_ff <= conv_data_i;
                        end
                    end
                end

                if ((conv_filter_i == NUM_FILTERS-1) &&
                    (conv_y_i == CONV_SIZE-1) &&
                    (conv_x_i == CONV_SIZE-1)) begin
                    done <= 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (pool_wr_en) begin
            pool_mem[pool_wr_addr] <= pool_wr_data;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            pool_rd_data_o  <= '0;
            pool_rd_valid_o <= 1'b0;
        end
        else begin
            pool_rd_valid_o <= pool_rd_en_i;
            if (pool_rd_en_i) begin
                pool_rd_data_o <= pool_mem[pool_rd_addr_i];
            end
        end
    end

endmodule