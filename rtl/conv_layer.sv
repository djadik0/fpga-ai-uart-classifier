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
    output  logic  signed  [WIDTH_OUT-1:0]       out [0:NUM_FILTERS-1][0:SIZE_IMAGE - SIZE_MATRIX ][0:SIZE_IMAGE - SIZE_MATRIX ],
    
// память
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

// свертка
    input   logic                                done_mac,
    input   logic  signed  [WIDTH_OUT-1:0]       conv_result,
    
    output  logic          [WIDTH-1:0]           fragment_o  [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],
    output  logic  signed  [WIDTH-1:0]           ves         [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],
    output  logic                                start_mac
    );

    

    logic  [$clog2(SIZE_IMAGE)-1:0]    counter_y_frag; 
    logic  [$clog2(SIZE_IMAGE)-1:0]    counter_x_frag; 
    logic  [$clog2(SIZE_MATRIX)-1:0]   counter_y;
    logic  [$clog2(SIZE_MATRIX)-1:0]   counter_x;
    logic  signed  [WIDTH-1:0]         ves_ff         [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic  [WIDTH-1:0]                 fragment_ff    [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
    logic  signed  [WIDTH_OUT-1:0]     out_ff         [0:NUM_FILTERS-1][0:SIZE_IMAGE-SIZE_MATRIX ][0:SIZE_IMAGE-SIZE_MATRIX ];

    enum  { IDLE, 
    LOAD_FRAGMENT,
    WAIT_FRAGMENT, 
    LOAD_WEIGHTS, 
    WEIGHTS,
    RUN_MAC, 
    STORE_RESULT,
    NEXT,
    DONE }  state;

    always_ff @( posedge clk or negedge rst ) begin 
        if ( !rst ) begin
            state              <=  IDLE;
            counter_x          <=  '0;
            counter_y          <=  '0;
            counter_y_frag     <=  '0;
            counter_x_frag     <=  '0;
            en_o_weights       <=  '0;
            en_fragment        <=  '0;
            filter             <=  '0;
            done               <=  '0;
            start_mac          <=  '0;
            adres_x            <=  '0;
            adres_y            <=  '0;
            frag_x_o           <=  '0;
            frag_y_o           <=  '0;
            for ( int q=0; q<SIZE_MATRIX; q++ ) begin
              for ( int w=0; w<SIZE_MATRIX; w++) begin
                ves_ff[q][w]         <=  '0;
                fragment_ff[q][w]    <=  '0;
              end
            end
            for ( int f1 = 0; f1 < NUM_FILTERS; f1 ++) begin
              for ( int y1 = 0; y1 < SIZE_IMAGE - SIZE_MATRIX + 1; y1++) begin
                for (int x1 = 0; x1 < SIZE_IMAGE - SIZE_MATRIX + 1; x1++) begin
                  out_ff[f1][y1][x1] <= '0;
                end
              end
            end
        end
        else case ( state )
               IDLE: begin 
                 done   <=  1'b0;
                 if ( start ) begin
                   state           <=  LOAD_WEIGHTS;
                   counter_x       <=  '0;
                   counter_y       <=  '0;
                   counter_y_frag  <=  '0;
                   counter_x_frag  <=  '0;
                   en_o_weights    <=  '0;
                   filter          <=  '0;
                   start_mac       <=  '0;
                   adres_x         <=  '0;
                   adres_y         <=  '0;
                   frag_x_o        <=  '0;
                   frag_y_o        <=  '0;
                    for ( int q=0; q<SIZE_MATRIX; q++ ) begin
                      for ( int w=0; w<SIZE_MATRIX; w++) begin
                        ves_ff[q][w]         <=  '0;
                        fragment_ff[q][w]    <=  '0;
                      end
                    end
                    for ( int f = 0; f < NUM_FILTERS; f ++) begin
                      for ( int y = 0; y < SIZE_IMAGE - SIZE_MATRIX + 1; y++) begin
                        for (int x = 0; x < SIZE_IMAGE - SIZE_MATRIX + 1; x++) begin
                          out_ff[f][y][x] <= '0;
                        end
                      end
                    end
                 end
               end


               LOAD_WEIGHTS: begin 
                 if ( counter_y == SIZE_MATRIX-1 && counter_x == SIZE_MATRIX-1 ) begin 
                    if ( !weights_valid ) begin 
                      adres_x                        <=  counter_x;
                      adres_y                        <=  counter_y;
                      en_o_weights                   <=  1'b1;
                      state                          <=  WEIGHTS;
                    end
                 end
                 else if ( counter_x == SIZE_MATRIX-1 ) begin 
                    if ( !weights_valid ) begin
                        adres_x                          <=  counter_x;
                        adres_y                          <=  counter_y;
                        en_o_weights                     <=  1'b1;
                        state                            <=  WEIGHTS;
                    end
                 end
                 else if ( !weights_valid ) begin
                   adres_x                        <=  counter_x;
                   adres_y                        <=  counter_y;
                   en_o_weights                   <=  1'b1;
                   state                          <=  WEIGHTS;
                 end
               end

               WEIGHTS: begin 
                if ( counter_y == SIZE_MATRIX-1 && counter_x == SIZE_MATRIX-1 ) begin 
                   if ( weights_valid ) begin
                      en_o_weights                   <=  1'b0;
                      ves_ff[counter_y][counter_x]   <=  weights_i;                     
                      state                          <=  LOAD_FRAGMENT;
                    end
                 end
                else if ( counter_x == SIZE_MATRIX-1 ) begin 
                 if ( weights_valid ) begin
                      ves_ff [counter_y][counter_x]     <=  weights_i;
                      counter_y                         <=  counter_y + 1;
                      counter_x                         <=  '0;
                      en_o_weights                      <=  1'b0;
                      state                             <=  LOAD_WEIGHTS;
                    end
                 end 
                else if ( weights_valid ) begin 
                     ves_ff[counter_y][counter_x]  <=  weights_i; 
                     counter_x                      <=  counter_x + 1;
                     en_o_weights                   <=  1'b0;
                     state                         <=  LOAD_WEIGHTS;
                   end
               end


               LOAD_FRAGMENT: begin
                 frag_y_o     <=  counter_y_frag;
                 frag_x_o     <=  counter_x_frag;   
                 en_fragment  <=  1'b1; 
                state         <=  WAIT_FRAGMENT;
               end

               WAIT_FRAGMENT: begin
                if ( fragment_valid ) begin
                  en_fragment              <=  1'b0;
                for ( int ky=0; ky<SIZE_MATRIX; ky++ ) begin
                  for ( int kx=0; kx<SIZE_MATRIX; kx++) begin
                    fragment_ff[ky][kx]  <=  fragment_i[ky][kx];
                  end
                end
                state        <=  RUN_MAC;
                end
               end


               RUN_MAC: begin
                  en_o_weights  <=  '0;
                  start_mac     <=  1'b1;
                  state         <=  STORE_RESULT;   
               end

 
               STORE_RESULT: begin 
                start_mac    <=  1'b0;
                if ( done_mac ) begin
                   out_ff[filter][counter_y_frag][counter_x_frag]  <=  conv_result;
                   state                                           <=  NEXT;
                 end                                         
               end


                NEXT: begin
                    if (counter_x_frag < SIZE_IMAGE - SIZE_MATRIX ) begin  
                        counter_x_frag  <=  counter_x_frag + 1;
                        state           <=  LOAD_FRAGMENT;
                    end 
                    else if (counter_y_frag < SIZE_IMAGE - SIZE_MATRIX ) begin 
                        counter_x_frag  <=  '0;
                        counter_y_frag  <=  counter_y_frag + 1;
                        state           <=  LOAD_FRAGMENT;
                    end 
                    else if (filter < NUM_FILTERS-1) begin 
                        counter_x_frag  <=  '0;
                        counter_y_frag  <=  '0;
                        filter          <=  filter + 1;
                        counter_x       <=  '0;
                        counter_y       <=  '0;
                        state           <=  LOAD_WEIGHTS;
                    end else begin 
                        state           <=  DONE;
                    end
                end

               DONE: begin
                  done   <=  1'b1;
                  state  <=  IDLE;
               end


        endcase 

    end

    always_comb begin
      for ( int z=0; z<SIZE_IMAGE - SIZE_MATRIX + 1; z++) begin
        for ( int x=0; x<SIZE_IMAGE - SIZE_MATRIX + 1; x++) begin
          for ( int c=0; c<NUM_FILTERS; c++) begin
            out[c][z][x] = out_ff[c][z][x];
          end
        end
      end
    end

    always_comb begin
       for ( int ky=0; ky<SIZE_MATRIX; ky++) begin
         for ( int kx=0; kx<SIZE_MATRIX; kx++) begin
           ves[ky][kx]           =  ves_ff[ky][kx];
           fragment_o[ky][kx]    =  fragment_ff[ky][kx];
        end
      end
    end

endmodule
