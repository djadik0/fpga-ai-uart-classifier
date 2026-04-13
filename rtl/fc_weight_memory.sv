module fc_weight_memory #(
    parameter OBJECTS = 10,
    parameter FC_INPUTS = 3600,
    parameter WEIGHT_WIDTH = 8
)(
    input   logic                              clk,
    input   logic                              rst,
    
    input   logic                              en_fc_r,
    input   logic   [$clog2(OBJECTS)-1:0]      class_idx,
    input   logic   [$clog2(FC_INPUTS)-1:0]    weight_idx,
    output  logic   signed [WEIGHT_WIDTH-1:0]  weight_value_o,
    output  logic                              weight_valid_o
);

    localparam TOTAL_WEIGHTS = OBJECTS * FC_INPUTS;

    logic signed [WEIGHT_WIDTH-1:0]  weight_value_ff;

    (* rom_style = "block" *)
    logic signed [WEIGHT_WIDTH-1:0] weights [0:TOTAL_WEIGHTS-1];
    logic [$clog2(TOTAL_WEIGHTS)-1:0] flat_idx;

    initial begin
        $readmemh("fc_weight.mem", weights);
    end


    assign  flat_idx  =  class_idx * FC_INPUTS + weight_idx;

    always_ff @(posedge clk or negedge rst ) begin
        if ( !rst ) begin
            weight_value_ff  <=  '0;
            weight_valid_o   <=  0;
        end 
        else if ( en_fc_r ) begin 
            weight_value_ff  <=  weights[flat_idx];
            weight_valid_o   <=  1;
        end
        else 
            weight_valid_o  <=  0;
    end

    assign weight_value_o  =  weight_value_ff;

endmodule