`timescale 1ns/1ps

module tb_ai_top;

    localparam int WIDTH         = 8;
    localparam int SIZE_IMAGE    = 64;
    localparam int OBJECTS       = 10;
    localparam int CLK_FREQ      = 50_000_000;
    localparam int BAUD_RATE     = 115200;
    localparam int CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam [7:0] CMD_START   = 8'hA5;

    logic clk;
    logic rst;
    logic rx_i;
    logic tx_o;

    logic        tx_rx_busy;
    logic        tx_rx_valid;
    logic [7:0]  tx_rx_data;

    ai_top #(
        .WIDTH(WIDTH),
        .SIZE_IMAGE(SIZE_IMAGE),
        .OBJECTS(OBJECTS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx_i(rx_i),
        .tx_o(tx_o)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx_decoder (
        .clk(clk),
        .rst(rst),
        .rx_i(tx_o),
        .busy_o(tx_rx_busy),
        .rx_valid_o(tx_rx_valid),
        .rx_data_o(tx_rx_data)
    );

    always #10 clk = ~clk;

    task automatic uart_send_byte(input [7:0] data);
        int i;
    begin
        rx_i = 1'b1;
        repeat (2) @(posedge clk);

        rx_i = 1'b0;
        repeat (CLKS_PER_BIT) @(posedge clk);

        for (i = 0; i < 8; i = i + 1) begin
            rx_i = data[i];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end

        rx_i = 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
    end
    endtask

    task automatic send_command_start_image;
    begin
        $display("TX->DUT command 0xA5");
        uart_send_byte(CMD_START);
    end
    endtask

    task automatic send_image_all_ones;
        int y, x;
    begin
        $display("TX->DUT image #1: all pixels = 1");
        for (y = 0; y < SIZE_IMAGE; y = y + 1) begin
            for (x = 0; x < SIZE_IMAGE; x = x + 1) begin
                uart_send_byte(8'd1);
            end
        end
    end
    endtask

    task automatic send_image_checkerboard_01;
        int y, x;
        reg [7:0] pix;
    begin
        $display("TX->DUT image #2: checkerboard 0/1");
        for (y = 0; y < SIZE_IMAGE; y = y + 1) begin
            for (x = 0; x < SIZE_IMAGE; x = x + 1) begin
                pix = (((x + y) % 2) == 0) ? 8'd1 : 8'd0;
                uart_send_byte(pix);
            end
        end
    end
    endtask

    task automatic wait_and_check_result(input [7:0] expected_class, input [255:0] label);
    begin
        $display("Waiting UART response for %0s ...", label);
        @(posedge tx_rx_valid);
        #1;

        $display("DUT->TX result byte = 0x%02h (%0d) for %0s",
                  tx_rx_data, tx_rx_data, label);

        if (tx_rx_data !== expected_class) begin
            $fatal(1, "FAIL: %0s result = %0d, expected %0d",
                   label, tx_rx_data, expected_class);
        end

        $display("internal done_arg=%0b class_id=%0d", dut.done_arg, dut.class_id);
    end
    endtask

    always @(posedge tx_rx_valid) begin
        $display("decoded UART TX byte = 0x%02h", tx_rx_data);
    end

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        rx_i = 1'b1; 

        repeat (10) @(posedge clk);
        rst = 1'b1;
        repeat (20) @(posedge clk);

        send_command_start_image();
        send_image_all_ones();
        wait_and_check_result(8'd9, "image #1");

        repeat (2000) @(posedge clk);

        send_command_start_image();
        send_image_checkerboard_01();
        wait_and_check_result(8'd9, "image #2");

        $display("PASS: ai_top processed both UART images correctly");
        $finish;
    end

endmodule