module conv_mac #( 
    parameter SIZE_MATRIX     =  4,
    parameter WIDTH           =  8,
    parameter RESULT          =  4*WIDTH
)
(
    input  logic                       clk,
    input  logic                       rst,
    input  logic                       start,
    output logic                       done,

    input  logic          [WIDTH-1:0]   A  [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],

    input  logic  signed  [WIDTH-1:0]   B  [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],

    output logic  signed  [RESULT-1:0]  result
);

  logic  signed  [RESULT-1:0]                           result_ff;
  logic          [$clog2(SIZE_MATRIX*SIZE_MATRIX)-1:0]  k;
  logic  signed  [WIDTH:0]                              A_signed  [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];



  always_comb begin
    for (int i=0; i<SIZE_MATRIX; i++) begin
      for (int j=0; j<SIZE_MATRIX; j++) begin
        A_signed[i][j]  =  {1'b0, A[i][j]};
      end
    end
  end


  enum  { STARTING, 
  MAC,
  EXIT,
  STOP }  state;

  always_ff @( posedge clk or negedge rst ) begin 
    if ( !rst ) begin
            k          <=  0;
            done       <=  0;
            state      <=  STARTING;
            result_ff  <=  '0;
        end

    else case ( state )
        STARTING: if ( start ) begin
              result_ff  <=  0;
              k          <=  0;
              state      <=  MAC;
              done       <=  0;
          end

        MAC: begin
              if ( k == SIZE_MATRIX*SIZE_MATRIX-1) begin 
                state      <=  EXIT;
                result_ff  <=  result_ff + A_signed[k / SIZE_MATRIX][k % SIZE_MATRIX] * B[k / SIZE_MATRIX][k % SIZE_MATRIX];
              end else if ( k < SIZE_MATRIX*SIZE_MATRIX-1 ) begin
                result_ff  <=  result_ff + A_signed[k / SIZE_MATRIX][k % SIZE_MATRIX] * B[k / SIZE_MATRIX][k % SIZE_MATRIX];
                k          <=  k + 1;
              end
            end

        EXIT: begin
          done   <=  1;
          state  <=  STOP; 
       end

        STOP: begin
          done   <=  0;
          state  <=  STARTING; 
        end

    endcase 

  end

  assign  result  =  result_ff;


endmodule