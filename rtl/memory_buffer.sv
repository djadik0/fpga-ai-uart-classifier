module memory_buffer#(
    parameter WIDTH           =  8,
    parameter SIZE_IMAGE      =  64,
    parameter SIZE_MATRIX     =  4,
    parameter NUM_FILTERS     =  4  
)
(
    input   logic                       clk,
    input   logic                       rst,
    

    input   logic  [$clog2(NUM_FILTERS)-1:0]    filter,


    input   logic  [$clog2(SIZE_MATRIX)-1:0]    adres_x,
    input   logic  [$clog2(SIZE_MATRIX)-1:0]    adres_y,
    input   logic                               en_i_weights,  
    input   logic                               we_i_weights, 
    input   logic  signed  [WIDTH-1:0]          weights_data,
    output  logic  signed  [WIDTH-1:0]          weights_out,
    output  logic                               weights_valid,
    

    input   logic                               en_i_image,     
    input   logic                               we_i_image,   
    input   logic  [WIDTH-1:0]                  image_data,
    input   logic  [$clog2(SIZE_IMAGE)-1:0]     image_adres_y,
    input   logic  [$clog2(SIZE_IMAGE)-1:0]     image_adres_x,
    output  logic  [WIDTH-1:0]                  image_pixel_out,
  
    input   logic                               en_fragment,  
    input   logic  [$clog2(SIZE_IMAGE)-1:0]     frag_y_i,
    input   logic  [$clog2(SIZE_IMAGE)-1:0]     frag_x_i,                      
    output  logic  [WIDTH-1:0]                  frag_out[0:SIZE_MATRIX-1][0:SIZE_MATRIX-1],        
    output  logic                               fragment_valid


    );

  logic signed  [WIDTH-1:0]  weights_memory  [0:NUM_FILTERS-1][0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
  logic signed  [WIDTH-1:0]  weights_ff;
  logic                      weights_valid_ff;

  logic         [WIDTH-1:0]  image_memory    [0:SIZE_IMAGE-1][0:SIZE_IMAGE-1];
  logic         [WIDTH-1:0]  image_ff;
  logic         [WIDTH-1:0]  frag_ff         [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
  logic                      fragment_valid_ff;
  
  initial begin
    $readmemh("buffer_weight.mem", weights_memory);
  end

  always_ff @(posedge clk or negedge rst) begin 
    if ( !rst ) begin
      weights_ff        <=  '0;
      weights_valid_ff  <=  1'b0;
    end
    else if ( en_i_weights ) begin
           if (we_i_weights) begin
             weights_memory[filter][adres_y][adres_x]  <=  weights_data;
             weights_valid_ff  <=  1'b0;
           end
         else begin
           weights_ff          <=  weights_memory[filter][adres_y][adres_x];
           weights_valid_ff    <=  1'b1;
         end
    end
    else 
        weights_valid_ff   <=  1'b0;
  end

  always_ff @(posedge clk or negedge rst) begin
    if ( !rst ) begin
      image_ff    <=  '0;
      for ( int ii=0; ii<SIZE_IMAGE; ii++) begin
        for ( int jj=0; jj<SIZE_IMAGE; jj++) begin
          image_memory[ii][jj]  <= '0;
        end
      end
    end
    else if ( en_i_image ) begin
           if ( we_i_image )
             image_memory[image_adres_y][image_adres_x]  <=  image_data;
         else
           image_ff  <= image_memory[image_adres_y][image_adres_x];
        end
  end 

  always_ff @(posedge clk or negedge rst) begin
    if ( !rst ) begin
      fragment_valid_ff  <=  1'b0;
      for (int ky = 0; ky < SIZE_MATRIX; ky++) begin
        for (int kx = 0; kx < SIZE_MATRIX; kx++) begin
          frag_ff[ky][kx]    <=  '0;
        end
      end
    end
    else if ( en_fragment ) begin
      fragment_valid_ff  <= 1'b1;
      for (int ky = 0; ky < SIZE_MATRIX; ky++) begin
        for (int kx = 0; kx < SIZE_MATRIX; kx++) begin
          frag_ff[ky][kx]  <= image_memory[frag_y_i + ky][frag_x_i + kx];
        end
      end
    end
    else 
        fragment_valid_ff  <= 1'b0;
  end

  assign  fragment_valid   =  fragment_valid_ff;
  assign  weights_valid    =  weights_valid_ff;
  assign  image_pixel_out  =  image_ff;
  assign  weights_out      =  weights_ff;
  
  always_comb begin
    for (int kyy = 0; kyy < SIZE_MATRIX; kyy++) begin
      for (int kxx = 0; kxx < SIZE_MATRIX; kxx++) begin
        frag_out[kyy][kxx] =  frag_ff[kyy][kxx];
      end
    end
  end


endmodule
