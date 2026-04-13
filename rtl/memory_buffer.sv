module memory_buffer#(
    parameter WIDTH           =  8,
    parameter SIZE_IMAGE      =  64,
    parameter SIZE_MATRIX     =  4,
    parameter NUM_FILTERS     =  4
)
(
    input   logic                               clk,
    input   logic                               rst,

    input   logic  [$clog2(NUM_FILTERS)-1:0]    filter,

    input   logic  [$clog2(SIZE_MATRIX)-1:0]    adres_x,
    input   logic  [$clog2(SIZE_MATRIX)-1:0]    adres_y,
    input   logic                               en_i_weights,
    input   logic                               we_i_weights,
    input   logic  signed [WIDTH-1:0]           weights_data,
    output  logic  signed [WIDTH-1:0]           weights_out,
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

  localparam int TOTAL_WEIGHTS = NUM_FILTERS * SIZE_MATRIX * SIZE_MATRIX;
  localparam int IMAGE_DEPTH   = SIZE_IMAGE * SIZE_IMAGE;
  localparam int FRAG_TOTAL    = SIZE_MATRIX * SIZE_MATRIX;
  localparam int FRAG_CNT_W    = $clog2(FRAG_TOTAL + 1);
  localparam int IMAGE_ADDR_W  = $clog2(IMAGE_DEPTH);


  (* ram_style = "distributed" *)
  logic signed [WIDTH-1:0] weights_memory [0:TOTAL_WEIGHTS-1];

  logic signed [WIDTH-1:0] weights_ff;
  logic                    weights_valid_ff;


  (* ram_style = "block" *)
  logic [WIDTH-1:0] image_memory [0:IMAGE_DEPTH-1];

  logic [WIDTH-1:0] frag_ff [0:SIZE_MATRIX-1][0:SIZE_MATRIX-1];
  logic             fragment_valid_ff;

  logic                              frag_busy_ff;
  logic [FRAG_CNT_W-1:0]             issue_cnt_ff;
  logic [FRAG_CNT_W-1:0]             recv_cnt_ff;

  logic [$clog2(SIZE_IMAGE)-1:0]     frag_base_y_ff;
  logic [$clog2(SIZE_IMAGE)-1:0]     frag_base_x_ff;

  logic                              rd_en_ff;
  logic [IMAGE_ADDR_W-1:0]           rd_addr_ff;
  logic [WIDTH-1:0]                  rd_data_ff;
  logic                              rd_valid_ff;

  logic [$clog2(SIZE_MATRIX)-1:0]    store_y_ff;
  logic [$clog2(SIZE_MATRIX)-1:0]    store_x_ff;

  function automatic int unsigned weight_index(
      input logic [$clog2(NUM_FILTERS)-1:0] f,
      input logic [$clog2(SIZE_MATRIX)-1:0] y,
      input logic [$clog2(SIZE_MATRIX)-1:0] x
  );
    weight_index = f * SIZE_MATRIX * SIZE_MATRIX + y * SIZE_MATRIX + x;
  endfunction

  function automatic int unsigned image_index(
      input int unsigned y,
      input int unsigned x
  );
    image_index = y * SIZE_IMAGE + x;
  endfunction

  initial begin
    $readmemh("buffer_weight.mem", weights_memory);
  end


  always_ff @(posedge clk) begin
    if (en_i_weights && we_i_weights) begin
      weights_memory[weight_index(filter, adres_y, adres_x)] <= weights_data;
    end
  end

  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      weights_ff       <= '0;
      weights_valid_ff <= 1'b0;
    end
    else if (en_i_weights && !we_i_weights) begin
      weights_ff       <= weights_memory[weight_index(filter, adres_y, adres_x)];
      weights_valid_ff <= 1'b1;
    end
    else begin
      weights_valid_ff <= 1'b0;
    end
  end



  always_ff @(posedge clk) begin
    if (en_i_image && we_i_image) begin
      image_memory[image_index(image_adres_y, image_adres_x)] <= image_data;
    end
  end


  assign image_pixel_out = '0;


  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      fragment_valid_ff <= 1'b0;
      frag_busy_ff      <= 1'b0;
      issue_cnt_ff      <= '0;
      recv_cnt_ff       <= '0;
      frag_base_y_ff    <= '0;
      frag_base_x_ff    <= '0;
      rd_en_ff          <= 1'b0;
      rd_addr_ff        <= '0;
      rd_data_ff        <= '0;
      rd_valid_ff       <= 1'b0;
      store_y_ff        <= '0;
      store_x_ff        <= '0;

      for (int ky = 0; ky < SIZE_MATRIX; ky++) begin
        for (int kx = 0; kx < SIZE_MATRIX; kx++) begin
          frag_ff[ky][kx] <= '0;
        end
      end
    end
    else begin
      fragment_valid_ff <= 1'b0;


      if (rd_en_ff) begin
        rd_data_ff <= image_memory[rd_addr_ff];
      end
      rd_valid_ff <= rd_en_ff;
      rd_en_ff    <= 1'b0;


      if (rd_valid_ff) begin
        frag_ff[store_y_ff][store_x_ff] <= rd_data_ff;

        if (recv_cnt_ff == FRAG_TOTAL-1) begin
          fragment_valid_ff <= 1'b1;
          frag_busy_ff      <= 1'b0;
        end

        recv_cnt_ff <= recv_cnt_ff + 1'b1;
      end


      if (!frag_busy_ff) begin
        if (en_fragment) begin
          frag_busy_ff   <= 1'b1;
          issue_cnt_ff   <= '0;
          recv_cnt_ff    <= '0;
          frag_base_y_ff <= frag_y_i;
          frag_base_x_ff <= frag_x_i;
        end
      end
      else begin
        if (issue_cnt_ff < FRAG_TOTAL) begin
          rd_en_ff   <= 1'b1;
          rd_addr_ff <= image_index(
              frag_base_y_ff + (issue_cnt_ff / SIZE_MATRIX),
              frag_base_x_ff + (issue_cnt_ff % SIZE_MATRIX)
          );

          store_y_ff <= issue_cnt_ff / SIZE_MATRIX;
          store_x_ff <= issue_cnt_ff % SIZE_MATRIX;

          issue_cnt_ff <= issue_cnt_ff + 1'b1;
        end
      end
    end
  end

  assign fragment_valid = fragment_valid_ff;
  assign weights_valid  = weights_valid_ff;
  assign weights_out    = weights_ff;

  always_comb begin
    for (int kyy = 0; kyy < SIZE_MATRIX; kyy++) begin
      for (int kxx = 0; kxx < SIZE_MATRIX; kxx++) begin
        frag_out[kyy][kxx] = frag_ff[kyy][kxx];
      end
    end
  end

endmodule