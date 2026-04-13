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
    input   logic                                   start_fc,

    input   logic  signed [WEIGHT_WIDTH-1:0]        weight_value_i,
    input   logic                                   weight_valid_i,

    input   logic  signed [WIDTH_OUT-1:0]           pool_value_i,
    input   logic                                   pool_valid_i,

    output  logic                                   en_fc_r,
    output  logic                                   en_pool_r,

    output  logic  signed [WIDTH_OUT*2-1:0]         fc_out_o [0:OBJECTS-1],
    output  logic                                   done_fc_o,
    output  logic         [$clog2(OBJECTS)-1:0]     class_idx_o,
    output  logic         [$clog2(FC_INPUTS)-1:0]   weight_idx_o,
    output  logic         [$clog2(FC_INPUTS)-1:0]   pool_idx_o
);

    logic [$clog2(FC_INPUTS)-1:0] data_idx;
    logic [$clog2(OBJECTS)-1:0]   neuron_idx;

    logic signed [WIDTH_OUT*2-1:0] sum;
    logic signed [WIDTH_OUT*2-1:0] fc_out_ff [0:OBJECTS-1];

    enum logic [2:0] {
        IDLE,
        INIT,
        REQ_DATA,
        WAIT_DATA,
        STORE,
        DONE
    } state;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            sum        <= '0;
            data_idx   <= '0;
            neuron_idx <= '0;
            done_fc_o  <= 1'b0;
            state      <= IDLE;

            for (int ii = 0; ii < OBJECTS; ii++) begin
                fc_out_ff[ii] <= '0;
            end
        end
        else begin
            case (state)

                IDLE: begin
                    done_fc_o <= 1'b0;
                    if (start_fc) begin
                        for (int ii = 0; ii < OBJECTS; ii++) begin
                            fc_out_ff[ii] <= '0;
                        end
                        neuron_idx <= '0;
                        state      <= INIT;
                    end
                end

                INIT: begin
                    sum      <= '0;
                    data_idx <= '0;
                    state    <= REQ_DATA;
                end

                REQ_DATA: begin
                    state <= WAIT_DATA;
                end

                WAIT_DATA: begin
                    if (weight_valid_i && pool_valid_i) begin
                        sum <= sum + pool_value_i * weight_value_i;

                        if (data_idx == FC_INPUTS-1) begin
                            state <= STORE;
                        end
                        else begin
                            data_idx <= data_idx + 1'b1;
                            state    <= REQ_DATA;
                        end
                    end
                end

                STORE: begin
                    fc_out_ff[neuron_idx] <= sum;

                    if (neuron_idx == OBJECTS-1) begin
                        state <= DONE;
                    end
                    else begin
                        neuron_idx <= neuron_idx + 1'b1;
                        state      <= INIT;
                    end
                end

                DONE: begin
                    done_fc_o  <= 1'b1;
                    neuron_idx <= '0;
                    state      <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always_comb begin
        for (int i = 0; i < OBJECTS; i++) begin
            fc_out_o[i] = fc_out_ff[i];
        end
    end

    assign class_idx_o  = neuron_idx;
    assign weight_idx_o = data_idx;
    assign pool_idx_o   = data_idx;

    assign en_fc_r      = (state == REQ_DATA);
    assign en_pool_r    = (state == REQ_DATA);

endmodule