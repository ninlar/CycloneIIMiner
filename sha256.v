module sha256 (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [639:0] data, // 80 bytes = 640 bits
    output reg [255:0] hash,
    output reg ready
);

    // Initial hash values
    reg [31:0] H [0:7];
    initial begin
        H[0] = 32'h6a09e667;
        H[1] = 32'hbb67ae85;
        H[2] = 32'h3c6ef372;
        H[3] = 32'ha54ff53a;
        H[4] = 32'h510e527f;
        H[5] = 32'h9b05688c;
        H[6] = 32'h1f83d9ab;
        H[7] = 32'h5be0cd19;
    end

    // Working variables
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] W [0:63];
    reg [6:0] t;
    reg [2:0] state;
	 
    reg [31:0] T1, T2;
    reg [31:0] K;

    integer i;
	 
	 // State encoding
    localparam IDLE = 3'b000,
               INIT = 3'b001,
               LOAD = 3'b010,
               COMPRESS = 3'b011,
               FINALIZE = 3'b100,
               DONE = 3'b101;

    // SHA-256 compression function
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            hash <= 256'b0;
            ready <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        // Initialize working variables
                        a = H[0];
                        b = H[1];
                        c = H[2];
                        d = H[3];
                        e = H[4];
                        f = H[5];
                        g = H[6];
                        h = H[7];
                        t = 0;
                        state <= INIT;
                    end
                end
                INIT: begin
                    // Prepare message schedule for the first 512-bit chunk
                    for (i = 0; i < 16; i = i + 1) begin
                        W[i] = data[639 - i*32 -: 32];
                    end
                    for (i = 16; i < 64; i = i + 1) begin
                        W[i] = (W[i-16] + ((W[i-15] >> 7) | (W[i-15] << (32-7))) + ((W[i-15] >> 18) | (W[i-15] << (32-18))) + (W[i-15] >> 3)) +
                               (((W[i-2] >> 17) | (W[i-2] << (32-17))) + ((W[i-2] >> 19) | (W[i-2] << (32-19))) + (W[i-2] >> 10)) + W[i-7];
                    end
                    t = 0;
                    state <= COMPRESS;
                end
                COMPRESS: begin
                    // Main loop for the first 512-bit chunk
                    if (t < 64) begin
                        case (t)
                            0: K = 32'h428a2f98; 1: K = 32'h71374491; 2: K = 32'hb5c0fbcf; 3: K = 32'he9b5dba5;
                            4: K = 32'h3956c25b; 5: K = 32'h59f111f1; 6: K = 32'h923f82a4; 7: K = 32'hab1c5ed5;
                            8: K = 32'hd807aa98; 9: K = 32'h12835b01; 10: K = 32'h243185be; 11: K = 32'h550c7dc3;
                            12: K = 32'h72be5d74; 13: K = 32'h80deb1fe; 14: K = 32'h9bdc06a7; 15: K = 32'hc19bf174;
                            16: K = 32'he49b69c1; 17: K = 32'hefbe4786; 18: K = 32'h0fc19dc6; 19: K = 32'h240ca1cc;
                            20: K = 32'h2de92c6f; 21: K = 32'h4a7484aa; 22: K = 32'h5cb0a9dc; 23: K = 32'h76f988da;
                            24: K = 32'h983e5152; 25: K = 32'ha831c66d; 26: K = 32'hb00327c8; 27: K = 32'hbf597fc7;
                            28: K = 32'hc6e00bf3; 29: K = 32'hd5a79147; 30: K = 32'h06ca6351; 31: K = 32'h14292967;
                            32: K = 32'h27b70a85; 33: K = 32'h2e1b2138; 34: K = 32'h4d2c6dfc; 35: K = 32'h53380d13;
                            36: K = 32'h650a7354; 37: K = 32'h766a0abb; 38: K = 32'h81c2c92e; 39: K = 32'h92722c85;
                            40: K = 32'ha2bfe8a1; 41: K = 32'ha81a664b; 42: K = 32'hc24b8b70; 43: K = 32'hc76c51a3;
                            44: K = 32'hd192e819; 45: K = 32'hd6990624; 46: K = 32'hf40e3585; 47: K = 32'h106aa070;
                            48: K = 32'h19a4c116; 49: K = 32'h1e376c08; 50: K = 32'h2748774c; 51: K = 32'h34b0bcb5;
                            52: K = 32'h391c0cb3; 53: K = 32'h4ed8aa4a; 54: K = 32'h5b9cca4f; 55: K = 32'h682e6ff3;
                            56: K = 32'h748f82ee; 57: K = 32'h78a5636f; 58: K = 32'h84c87814; 59: K = 32'h8cc70208;
                            60: K = 32'h90befffa; 61: K = 32'ha4506ceb; 62: K = 32'hbef9a3f7; 63: K = 32'hc67178f2;
                        endcase
                        T1 = h + (e >> 6 | e << (32-6)) + (e >> 11 | e << (32-11)) + (e >> 25 | e << (32-25)) + (e & f) ^ (~e & g) + K + W[t];
                        T2 = (a >> 2 | a << (32-2)) + (a >> 13 | a << (32-13)) + (a >> 22 | a << (32-22)) + (a & b) ^ (a & c) ^ (b & c);
                        h = g;
                        g = f;
                        f = e;
                        e = d + T1;
                        d = c;
                        c = b;
                        b = a;
                        a = T1 + T2;
                        t = t + 1;
                    end else begin
                        state <= FINALIZE;
                    end
                end
                FINALIZE: begin
                    // Compute the final hash value for the first chunk
                    H[0] = H[0] + a;
                    H[1] = H[1] + b;
                    H[2] = H[2] + c;
                    H[3] = H[3] + d;
                    H[4] = H[4] + e;
                    H[5] = H[5] + f;
                    H[6] = H[6] + g;
                    H[7] = H[7] + h;

                    // Output the hash value
                    hash = {H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]};
                    ready <= 1'b1;
                    state <= DONE;
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule