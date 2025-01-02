`timescale 1ns / 1ps

module uart_tx_tb;

    // Inputs
    reg clk;
    reg reset;
    reg [7:0] data_in;
    reg tx_start;

    // Outputs
    wire tx;
    wire tx_busy;

    // Instantiate the UART transmitter module
    uart_tx uut (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .tx_start(tx_start),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    // Clock generation
    always #10 clk = ~clk; // 50 MHz clock

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        data_in = 8'b0;
        tx_start = 0;

        // Wait for global reset
        #20;
        reset = 0;

        // Send a byte
        #20;
        data_in = 8'hA5; // Example data
        tx_start = 1;
        #20;
        tx_start = 0;

        // Wait for transmission to complete
        wait (!tx_busy);

        // Send another byte
        #100000; // Wait some time before sending the next byte
        data_in = 8'h3C; // Example data
        tx_start = 1;
        #20;
        tx_start = 0;

        // Wait for transmission to complete
        wait (!tx_busy);

        // End the simulation
        $finish;
    end

endmodule