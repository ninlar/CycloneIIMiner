`timescale 1ns / 1ps

module uart_rx_tb;

    // Inputs
    reg clk;
    reg reset;
    reg rx;

    // Outputs
    wire [7:0] data_out;
    wire rx_ready;

    // Instantiate the UART receiver module
    uart_rx uut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(data_out),
        .rx_ready(rx_ready)
    );

    // Clock generation
    always #10 clk = ~clk; // 50 MHz clock

    // Task to send a byte over UART
    task send_byte;
        input [7:0] byte;
        integer i;
        begin
            // Start bit
            rx = 0;
            #(8680); // 1/115200 baud rate * 10^9 ns

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i];
                #(8680);
            end

            // Stop bit
            rx = 1;
            #(8680);
        end
    endtask

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        rx = 1;

        // Wait for global reset
        #20;
        reset = 0;

        // Send a byte
        #20;
        send_byte(8'hA5); // Example data

        // Wait for the reception to complete
        wait (rx_ready);

        // Display the received data
        $display("Received Data: %h", data_out);

        // Send another byte
        #100000; // Wait some time before sending the next byte
        send_byte(8'h3C); // Example data

        // Wait for the reception to complete
        wait (rx_ready);

        // Display the received data
        $display("Received Data: %h", data_out);

        // End the simulation
        $finish;
    end

endmodule