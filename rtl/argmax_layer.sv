module argmax_layer#(
    parameter WIDTH       = 8,
    parameter WIDTH_OUT   = 4*WIDTH,
    parameter OBJECTS     = 10
) 
(

    input   logic                                clk,
    input   logic                                rst,
    input   logic                                start_arg,
    input   logic  signed [WIDTH_OUT*2-1:0]      fc_out_i [0:OBJECTS-1],

    output  logic         [$clog2(OBJECTS)-1:0]  otvet,
    output  logic                                done_arg

);

    logic  [$clog2(OBJECTS)-1:0]          otvet_ff;
    logic  signed [WIDTH_OUT*2-1:0]       max;
    logic  [$clog2(OBJECTS)-1:0]          max_idx;
    logic  [$clog2(OBJECTS)-1:0]          idx;
 
    enum{ IDLE,
    INIT,
    COMPARE,
    DONE } state;


    always_ff @( posedge clk or negedge rst ) begin
        if ( !rst ) begin
            idx       <=   0;
            state     <=  IDLE;
            max_idx   <=  '0;
            max       <=  '0;
            done_arg  <=   0;
            otvet_ff  <=  '0;
        end
        else case ( state )

        IDLE: begin 
            done_arg  <=  0;
            if ( start_arg ) begin
                state     <=  INIT;
            end
        end

        INIT: begin
            idx       <=  1;
            state     <=  COMPARE;
            max_idx   <=  '0;
            otvet_ff  <=  '0;
            max       <=  fc_out_i[0];
        end

        COMPARE: begin
            if ( max == fc_out_i[idx] ) begin
                if ( idx == OBJECTS-1 ) begin
                    state    <=  DONE;
                end else begin
                    idx      <=  idx + 1;
                end
            end
            else if ( idx == OBJECTS-1 ) begin 
                    if ( max  <  fc_out_i[idx] ) begin 
                        max       <=  fc_out_i[idx];
                        state     <=  DONE;
                        max_idx   <=  idx;
                    end
                    if ( max  >  fc_out_i[idx]) begin
                        state     <=  DONE;
                    end
            end
            else begin 
                    if ( max  <  fc_out_i[idx] ) begin 
                        max      <=  fc_out_i[idx];
                        idx      <=  idx + 1;
                        max_idx  <=  idx;
                    end
                    if ( max  >  fc_out_i[idx]) begin
                        idx      <=  idx + 1;
                    end
            end

            end


        DONE: begin
            done_arg  <=  1;
            otvet_ff  <=  max_idx;
            state     <=  IDLE;
        end

        endcase 

    end

    assign  otvet  =  otvet_ff;




endmodule