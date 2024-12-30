module bitcoin_miner (
    input wire clk,
    input wire reset,
    input wire rx,
    output wire tx,
    output wire ready_led,
    output wire mining_led,
    output wire done_led
);
    // UART parameters
    parameter CLK_FREQ = 50000000; // 50 MHz
    parameter BAUD_RATE = 115200;
    parameter UART_DIV = CLK_FREQ / BAUD_RATE;
    parameter SHA_CORE_COUNT = 10;
    parameter SHA_CORE_END = SHA_CORE_COUNT - 1;
    parameter STATE_READY = 2'b00;
    parameter STATE_MINING = 2'b01;
    parameter STATE_DONE = 2'b10;

    // UART signals
    wire [7:0] uart_rx_data;
    wire uart_rx_ready;
    wire uart_tx_busy;
    reg [7:0] uart_tx_data;
    reg uart_tx_start;

    // LED State
    reg [1:0] led_state = STATE_READY;

    // Bitcoin mining signals
    reg [31:0] nonce;
    reg [255:0] target;
    reg mining;
    reg [639:0] data; // 80 bytes for block header
    reg [7:0] block_header [0:79]; // 80 bytes for block header
    integer i;
    reg [1:0] nonce_byte_index; // Index to track which byte of nonce to send

    reg [31:0] nonce_offset [0:SHA_CORE_END];
    reg sha256_start [0:SHA_CORE_END];
    wire sha256_ready [0:SHA_CORE_END];
    wire [255:0] hash [0:SHA_CORE_END];

    // UART receiver
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .reset(!reset),
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
        .reset(!reset),
        .data_in(uart_tx_data),
        .tx_start(uart_tx_start),
        .tx(tx),
        .tx_busy(uart_tx_busy)
    );

    // Instantiate 20 SHA-256 modules
    genvar sha_gen_index;
    generate
        for (sha_gen_index = 0; sha_gen_index < SHA_CORE_COUNT; sha_gen_index = sha_gen_index + 1) begin : sha256_instances
            sha256 sha256_inst (
                .clk(clk),
                .reset(!reset),
                .start(sha256_start[sha_gen_index]),
                .data({block_header[0], block_header[1], block_header[2], block_header[3], block_header[4], block_header[5], block_header[6], block_header[7], block_header[8], block_header[9], block_header[10], block_header[11], block_header[12], block_header[13], block_header[14], block_header[15], block_header[16], block_header[17], block_header[18], block_header[19], block_header[20], block_header[21], block_header[22], block_header[23], block_header[24], block_header[25], block_header[26], block_header[27], block_header[28], block_header[29], block_header[30], block_header[31], block_header[32], block_header[33], block_header[34], block_header[35], block_header[36], block_header[37], block_header[38], block_header[39], block_header[40], block_header[41], block_header[42], block_header[43], block_header[44], block_header[45], block_header[46], block_header[47], block_header[48], block_header[49], block_header[50], block_header[51], block_header[52], block_header[53], block_header[54], block_header[55], block_header[56], block_header[57], block_header[58], block_header[59], block_header[60], block_header[61], block_header[62], block_header[63], block_header[64], block_header[65], block_header[66], block_header[67], block_header[68], block_header[69], block_header[70], block_header[71], block_header[72], block_header[73], block_header[74], block_header[75], nonce + sha_gen_index}),
                .hash(hash[sha_gen_index]),
                .ready(sha256_ready[sha_gen_index])
            );
        end
    endgenerate

    // Mining process
    always @(posedge clk or negedge reset) begin
        integer start_index;
        if (!reset) begin
            nonce <= 32'b0;
            mining <= 1'b0;
            uart_tx_start <= 1'b0;
            for (start_index = 0; start_index < SHA_CORE_COUNT; start_index = start_index + 1) begin
                sha256_start[start_index] <= 1'b0;
            end
            i <= 0;
            nonce_byte_index <= 2'b0;
            led_state <= STATE_READY;
        end else if (uart_rx_ready) begin
            // Receive block header
            block_header[i] <= uart_rx_data;
            i <= i + 1;
            if (i == 79) begin
                // Start mining when full block header is received
                mining <= 1'b1;
                nonce <= 32'b0;
                led_state <= STATE_MINING;
                i <= 0;
                for (start_index = 0; start_index < SHA_CORE_COUNT; start_index = start_index + 1) begin
                    sha256_start[start_index] <= 1'b1;
                end
            end
        end else if (mining) begin
            integer sha_index;
				integer inner_sha_index;
            for (sha_index = 0; sha_index < SHA_CORE_COUNT; sha_index = sha_index + 1) begin
                if (sha256_ready[sha_index]) begin
                    sha256_start[sha_index] <= 1'b0;
                    if (hash[sha_index] < target) begin
                        // Found a valid nonce
                        mining <= 1'b0;
                        nonce_byte_index <= 2'b0;
                        uart_tx_data <= (nonce + sha_index) & 8'hFF; // Send the first byte of nonce
                        uart_tx_start <= 1'b1;
                    end else begin
                        // Increment nonce and continue mining
                        nonce <= nonce + SHA_CORE_COUNT;
								
                        for (inner_sha_index = 0; inner_sha_index < SHA_CORE_COUNT; inner_sha_index = inner_sha_index + 1) begin
                            sha256_start[inner_sha_index] <= 1'b1;
                        end
                    end
                end
            end
        end else if (uart_tx_start && !uart_tx_busy) begin
            uart_tx_start <= 1'b0; // Clear tx_start after transmission
            led_state <= STATE_DONE;
            if (nonce_byte_index < 3) begin
                nonce_byte_index <= nonce_byte_index + 1;
                case (nonce_byte_index)
                    2'b00: uart_tx_data <= nonce[7:0];
                    2'b01: uart_tx_data <= nonce[15:8];
                    2'b10: uart_tx_data <= nonce[23:16];
                endcase // Send the next byte of nonce
                uart_tx_start <= 1'b1;
            end
        end
    end

    assign ready_led = !(led_state == STATE_READY);
    assign mining_led = !(led_state == STATE_MINING);
    assign done_led = !(led_state == STATE_DONE);
endmodule