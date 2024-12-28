module bitcoin_miner (
    input wire clk,
    input wire reset,
    input wire rx,
    output wire tx
);
    // UART parameters
    parameter CLK_FREQ = 50000000; // 50 MHz
    parameter BAUD_RATE = 115200;
    parameter UART_DIV = CLK_FREQ / BAUD_RATE;

    // UART signals
    wire [7:0] uart_rx_data;
    wire uart_rx_ready;
    wire uart_tx_busy;
    reg [7:0] uart_tx_data;
    reg uart_tx_start;

    // Bitcoin mining signals
    reg [31:0] nonce;
    wire [255:0] hash;
    wire sha256_ready;
    reg [255:0] target;
    reg mining;
    reg [639:0] data; // 80 bytes for block header
    reg [7:0] block_header [0:79]; // 80 bytes for block header
    integer i;
    reg [1:0] nonce_byte_index; // Index to track which byte of nonce to send

    // UART receiver
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(uart_rx_data),
        .rx_ready(uart_rx_ready)
    );

    // UART transmitter
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .reset(reset),
        .data_in(uart_tx_data),
        .tx_start(uart_tx_start),
        .tx(tx),
        .tx_busy(uart_tx_busy)
    );

    // SHA-256 instance
    reg sha256_start;
    sha256 sha256_inst (
        .clk(clk),
        .reset(reset),
        .start(sha256_start),
        .data(data),
        .hash(hash),
        .ready(sha256_ready)
    );

    // Mining process
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            nonce <= 32'b0;
            mining <= 1'b0;
            uart_tx_start <= 1'b0;
            sha256_start <= 1'b0;
            i <= 0;
            nonce_byte_index <= 2'b0;
        end else if (uart_rx_ready) begin
            // Receive block header
            block_header[i] <= uart_rx_data;
            i <= i + 1;
            if (i == 79) begin
                // Start mining when full block header is received
                mining <= 1'b1;
                data <= {block_header[0], block_header[1], block_header[2], block_header[3], block_header[4], block_header[5], block_header[6], block_header[7], block_header[8], block_header[9], block_header[10], block_header[11], block_header[12], block_header[13], block_header[14], block_header[15], block_header[16], block_header[17], block_header[18], block_header[19]};
                nonce <= 32'b0;
                i <= 0;
                sha256_start <= 1'b1;
            end
        end else if (mining) begin
            if (sha256_ready) begin
                sha256_start <= 1'b0;
                if (hash < target) begin
                    // Found a valid nonce
                    mining <= 1'b0;
                    nonce_byte_index <= 2'b0;
                    uart_tx_data <= nonce[7:0]; // Send the first byte of nonce
                    uart_tx_start <= 1'b1;
                end else begin
                    // Increment nonce and continue mining
                    nonce <= nonce + 1;
                    data <= {block_header[0], block_header[1], block_header[2], block_header[3], block_header[4], block_header[5], block_header[6], block_header[7], block_header[8], block_header[9], block_header[10], block_header[11], block_header[12], block_header[13], block_header[14], block_header[15], block_header[16], block_header[17], block_header[18], block_header[19], nonce};
                    sha256_start <= 1'b1;
                end
            end
        end else if (uart_tx_start && !uart_tx_busy) begin
            uart_tx_start <= 1'b0; // Clear tx_start after transmission
            if (nonce_byte_index < 3) begin
                nonce_byte_index <= nonce_byte_index + 1;
                case (nonce_byte_index)
                    2'b00: uart_tx_data <= nonce[15:8]; // Send the second byte of nonce
                    2'b01: uart_tx_data <= nonce[23:16]; // Send the third byte of nonce
                    2'b10: uart_tx_data <= nonce[31:24]; // Send the fourth byte of nonce
                endcase
                uart_tx_start <= 1'b1;
            end
        end
    end
endmodule