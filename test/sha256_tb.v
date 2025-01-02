`timescale 1ns / 1ps

module sha256_tb;

    // Inputs
    reg clk;
    reg reset;
    reg start;
    reg [639:0] data;

    // Outputs
    wire ready;
    wire [255:0] hash;

    // Instantiate the SHA-256 module
    sha256 uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .data(data),
        .ready(ready),
        .hash(hash)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        start = 0;
        data = 640'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018; // "abc" with padding

        // Wait for global reset
        #10;
        reset = 0;

        // Start the SHA-256 computation
        #10;
        start = 1;
        #10;
        start = 0;

        // Wait for the computation to complete
        wait (ready);

        // Display the result
        $display("Hash: %h", hash);

        // End the simulation
        $finish;
    end

endmodule