module conv_layer#(
    parameter SIZE_MATRIX     =  4,
    parameter WIDTH           =  8,
    parameter SIZE_IMAGE      =  64,
    parameter WIDTH_OUT       =  4*WIDTH,
    parameter NUM_FILTERS     =  4
)
(
    input   logic                                clk,
    input   logic                                rst,
    input   logic                                start,
    output  logic                                done,

    output  logic                                conv_valid_o,
    output  logic  signed  [WIDTH_OUT-1:0]       conv_data_o,
    output  logic  [$clog2(NUM_FILTERS)-1:0]     conv_filter_o,
    output  logic  [$clog2(SIZE_IMAGE)-1:0]      conv_y_o,
    output  logic  [$clog2(SIZE_IMAGE)-1:0]      conv_x_o,

    input   logic  signed  [WIDTH-1:0]           weights_i,
    input   logic                                weights_valid,
    output  logic  [$clog2(SIZE_MATRIX)-1:0]     adres_x,
    output  logic  [$clog2(SIZE_MATRIX)-1:0]     adres_y,
    output  logic                                en_o_weights,

    input   logic                                fragment_valid,
    input   logic  [WIDTH-1:0]                   fragment_i  [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],
    output  logic                                en_fragment,
    output  logic  [$clog2(SIZE_IMAGE)-1:0]      frag_y_o,
    output  logic  [$clog2(SIZE_IMAGE)-1:0]      frag_x_o,

    output  logic  [$clog2(NUM_FILTERS)-1:0]     filter,

    input   logic                                done_mac,
    input   logic  signed  [WIDTH_OUT-1:0]       conv_result,

    output  logic          [WIDTH-1:0]           fragment_o  [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],
    output  logic  signed  [WIDTH-1:0]           ves         [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],
    output  logic                                start_mac
);

    localparam CONV_SIZE = SIZE_IMAGE - SIZE_MATRIX + 1;

    logic [$clog2(SIZE_IMAGE)-1:0]  counter_y_frag;
    logic [$clog2(SIZE_IMAGE)-1:0]  counter_x_frag;
    logic [$clog2(SIZE_MATRIX)-1:0] counter_y;
    logic [$clog2(SIZE_MATRIX)-1:0] counter_x;

    logic signed [WIDTH-1:0]        ves_ff      [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic [WIDTH-1:0]               fragment_ff [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];

    enum logic [3:0] {
        IDLE,
        LOAD_W_REQ,
        LOAD_W_WAIT,
        LOAD_F_REQ,
        LOAD_F_WAIT,
        RUN_MAC,
        WAIT_MAC,
        ADVANCE,
        DONE_ST
    } state;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state        <= IDLE;
            counter_x    <= '0;
            counter_y    <= '0;
            counter_x_frag <= '0;
            counter_y_frag <= '0;
            en_o_weights <= 1'b0;
            en_fragment  <= 1'b0;
            filter       <= '0;
            done         <= 1'b0;
            start_mac    <= 1'b0;
            adres_x      <= '0;
            adres_y      <= '0;
            frag_x_o     <= '0;
            frag_y_o     <= '0;

            conv_valid_o  <= 1'b0;
            conv_data_o   <= '0;
            conv_filter_o <= '0;
            conv_y_o      <= '0;
            conv_x_o      <= '0;
        end
        else begin
            done         <= 1'b0;
            en_o_weights <= 1'b0;
            en_fragment  <= 1'b0;
            start_mac    <= 1'b0;
            conv_valid_o <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        counter_x      <= '0;
                        counter_y      <= '0;
                        counter_x_frag <= '0;
                        counter_y_frag <= '0;
                        filter         <= '0;
                        state          <= LOAD_W_REQ;
                    end
                end

                LOAD_W_REQ: begin
                    adres_x      <= counter_x;
                    adres_y      <= counter_y;
                    en_o_weights <= 1'b1;
                    state        <= LOAD_W_WAIT;
                end

                LOAD_W_WAIT: begin
                    if (weights_valid) begin
                        ves_ff[counter_y][counter_x] <= weights_i;

                        if ((counter_y == SIZE_MATRIX-1) && (counter_x == SIZE_MATRIX-1)) begin
                            state <= LOAD_F_REQ;
                        end
                        else begin
                            if (counter_x == SIZE_MATRIX-1) begin
                                counter_x <= '0;
                                counter_y <= counter_y + 1'b1;
                            end
                            else begin
                                counter_x <= counter_x + 1'b1;
                            end
                            state <= LOAD_W_REQ;
                        end
                    end
                end

                LOAD_F_REQ: begin
                    frag_y_o    <= counter_y_frag;
                    frag_x_o    <= counter_x_frag;
                    en_fragment <= 1'b1;
                    state       <= LOAD_F_WAIT;
                end

                LOAD_F_WAIT: begin
                    if (fragment_valid) begin
                        for (int ky = 0; ky < SIZE_MATRIX; ky++) begin
                            for (int kx = 0; kx < SIZE_MATRIX; kx++) begin
                                fragment_ff[ky][kx] <= fragment_i[ky][kx];
                            end
                        end
                        state <= RUN_MAC;
                    end
                end

                RUN_MAC: begin
                    start_mac <= 1'b1;
                    state     <= WAIT_MAC;
                end

                WAIT_MAC: begin
                    if (done_mac) begin
                        conv_valid_o  <= 1'b1;
                        conv_data_o   <= conv_result;
                        conv_filter_o <= filter;
                        conv_y_o      <= counter_y_frag;
                        conv_x_o      <= counter_x_frag;
                        state         <= ADVANCE;
                    end
                end

                ADVANCE: begin
                    if (counter_x_frag < CONV_SIZE-1) begin
                        counter_x_frag <= counter_x_frag + 1'b1;
                        state          <= LOAD_F_REQ;
                    end
                    else if (counter_y_frag < CONV_SIZE-1) begin
                        counter_x_frag <= '0;
                        counter_y_frag <= counter_y_frag + 1'b1;
                        state          <= LOAD_F_REQ;
                    end
                    else if (filter < NUM_FILTERS-1) begin
                        filter         <= filter + 1'b1;
                        counter_x      <= '0;
                        counter_y      <= '0;
                        counter_x_frag <= '0;
                        counter_y_frag <= '0;
                        state          <= LOAD_W_REQ;
                    end
                    else begin
                        done  <= 1'b1;
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always_comb begin
        for (int ky = 0; ky < SIZE_MATRIX; ky++) begin
            for (int kx = 0; kx < SIZE_MATRIX; kx++) begin
                ves[ky][kx]        = ves_ff[ky][kx];
                fragment_o[ky][kx] = fragment_ff[ky][kx];
            end
        end
    end

endmodule