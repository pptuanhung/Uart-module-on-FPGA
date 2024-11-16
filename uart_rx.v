module uart  
#(parameter DBIT=8, SB_TICK=16)  
 (input wire clk, reset,  
  input wire rx, s_tick,  
  output reg rx_done_tick,  
  output reg [7:0] dout,  
  output reg check_parity  
);  

    localparam [2:0]  
        idle = 3'b000,  
        start = 3'b001,  
        data = 3'b010,  
        parity = 3'b011,  
        stop = 3'b100;  

    reg [2:0] state_reg, state_next;   
    reg [3:0] s_reg, s_next;   
    reg [2:0] n_reg, n_next;  
    reg [7:0] b_reg, b_next;  
    reg xor_parity;  

    // State update on clock edge  
    always @(posedge clk or negedge reset) begin  
        if (!reset) begin   
            state_reg <= idle; // Initial state: idle  
            s_reg <= 0; // S_tick = 0  
            n_reg <= 0; // Number of bits received  
            b_reg <= 0; // Received data  
        end else begin  
            state_reg <= state_next;  
            s_reg <= s_next;  
            n_reg <= n_next;  
            b_reg <= b_next;  
        end  
    end  

    // Next state logic and data path function  
    always @(*) begin  
        // Default state  
        state_next = state_reg;  
        rx_done_tick = 1'b0;  
        s_next = s_reg;  
        n_next = n_reg;  
        b_next = b_reg;  

        // FSM  
        case (state_reg)  
            idle: begin  
                if (~rx) begin  
                    state_next = start;  
                    s_next = 0;  
                end  
            end  
            
            start: begin  
                if (s_tick) begin  
                    if (s_reg == 7) begin // Bit delay  
                        state_next = data;  
                        s_next = 0;  
                        n_next = 0;  
                    end else begin  
                        s_next = s_reg + 1;  
                    end  
                end  
            end  
            
            data: begin  
                if (s_tick) begin  
                    if (s_reg == 15) begin  
                        s_next = 0;  
                        b_next = {rx, b_reg[7:1]};  
                        if (n_reg == (DBIT - 1)) begin  
                            state_next = parity;   
                        end else begin  
                            n_next = n_reg + 1;  
                        end  
                    end else begin  
                        s_next = s_reg + 1;  
                    end  
                end  
            end  
            
            parity: begin  
                if (s_tick) begin  
                    if (s_reg == DBIT - 1) begin  
                        s_next = 0;  
                        xor_parity = b_reg[0] ^ b_reg[1] ^ b_reg[2] ^ b_reg[3] ^   
                                     b_reg[4] ^ b_reg[5] ^ b_reg[6] ^ b_reg[7];  
                        check_parity = (xor_parity == rx);  
                        if (check_parity == 1'b1) begin  
                            state_next = stop;  
                        end else begin  
                            state_next = idle;  
                        end  
                    end else begin  
                        s_next = s_reg + 1;  
                    end  
                end  
            end  
            
            stop: begin  
                if (s_tick) begin  
                    if (s_reg == (SB_TICK - 1)) begin  
                        rx_done_tick = 1'b1;  
                        state_next = idle;  
                    end else begin  
                        s_next = s_reg + 1;  
                    end  
                end  
            end  
        endcase  
    end  

    // Output assignment  
    always @(*) begin  
        dout = b_reg;   
    end  
    
endmodule