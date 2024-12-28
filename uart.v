module uart_tx (
    input wire clk,
    input wire reset,
    input wire [7:0] data_in,
    input wire tx_start,
    output reg tx,
    output reg tx_busy
);
    parameter CLK_FREQ = 50000000; // 50 MHz
    parameter BAUD_RATE = 115200;
    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    reg [3:0] bit_index;
    reg [15:0] clk_count;
    reg [7:0] tx_shift_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx <= 1'b1;
            tx_busy <= 1'b0;
            bit_index <= 4'b0;
            clk_count <= 16'b0;
            tx_shift_reg <= 8'b0;
        end else begin
            if (tx_start && !tx_busy) begin
                tx_busy <= 1'b1;
                tx_shift_reg <= data_in;
                bit_index <= 4'b0;
                clk_count <= 16'b0;
                tx <= 1'b0; // Start bit
            end else if (tx_busy) begin
                if (clk_count < BIT_PERIOD - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 16'b0;
                    if (bit_index < 8) begin
                        tx <= tx_shift_reg[bit_index];
                        bit_index <= bit_index + 1;
                    end else begin
                        tx <= 1'b1; // Stop bit
                        tx_busy <= 1'b0;
                    end
                end
            end
        end
    end
endmodule

module uart_rx (
    input wire clk,
    input wire reset,
    input wire rx,
    output reg [7:0] data_out,
    output reg rx_ready
);
    parameter CLK_FREQ = 50000000; // 50 MHz
    parameter BAUD_RATE = 115200;
    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    reg [3:0] bit_index;
    reg [15:0] clk_count;
    reg [7:0] rx_shift_reg;
    reg rx_busy;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_ready <= 1'b0;
            bit_index <= 4'b0;
            clk_count <= 16'b0;
            rx_shift_reg <= 8'b0;
            rx_busy <= 1'b0;
        end else begin
            if (!rx_busy && !rx) begin
                rx_busy <= 1'b1;
                clk_count <= BIT_PERIOD / 2; // To sample in the middle of the bit
            end else if (rx_busy) begin
                if (clk_count < BIT_PERIOD - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 16'b0;
                    if (bit_index < 8) begin
                        rx_shift_reg[bit_index] <= rx;
                        bit_index <= bit_index + 1;
                    end else begin
                        data_out <= rx_shift_reg;
                        rx_ready <= 1'b1;
                        rx_busy <= 1'b0;
                        bit_index <= 4'b0;
                    end
                end
            end else begin
                rx_ready <= 1'b0;
            end
        end
    end
endmodule
