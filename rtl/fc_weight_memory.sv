module fc_weight_memory #(
    parameter OBJECTS = 10,
    parameter FC_INPUTS = 3600,
    parameter WEIGHT_WIDTH = 8
)(
    input   logic   [$clog2(OBJECTS)-1:0]      class_idx,
    input   logic   [$clog2(FC_INPUTS)-1:0]    weight_idx,

    output  logic   signed [WEIGHT_WIDTH-1:0]  weight_value_o
);


    logic signed [WEIGHT_WIDTH-1:0] weights [0:OBJECTS-1][0:FC_INPUTS-1];

    initial begin
        $readmemh("fc_weight.mem", weights);
    end

    assign weight_value_o = weights[class_idx][weight_idx];


endmodule