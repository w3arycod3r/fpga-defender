// Source: https://github.com/hildebrandmw/de10lite-hdl

module spi #(
        // Number of bits per transaction
        parameter DATASIZE = 8,
        parameter CLK_FREQUENCY = 50_000_000,
        parameter SPI_FREQUENCY = 2_000_000,
        // Number of NS to stay idle before next 
        parameter IDLE_NS = 200
    ) (
        // Host side signals
        input   reset_n,
        input   clk,
        // Transaction request signals.
        input                       tx_request,
        input   [DATASIZE-1:0]      tx_data,
        input                       rx_request,
        output logic [DATASIZE-1:0] rx_data,
        output logic                rx_valid,
        output logic                ack_request,
        output logic                active,
        // SPI Side signals
        output logic spi_sdi,
        input        spi_sdo,
        output logic spi_csn,
        output logic spi_clk
    );

    // Number of clock cycles to remain idle. Need to cast to longint to avoid
    // overflow.
    localparam longint CLOCK_COUNT = IDLE_NS * CLK_FREQUENCY;
    localparam IDLE_CLOCKS =  CLOCK_COUNT / 1_000_000_000; 

    logic [$clog2(IDLE_CLOCKS)-1:0] idlecount, idlecount_next;

    // -------- //
    // CLOCKING //
    // -------- //
    // Clock divider to time the output clock.
    localparam CLK_COUNT = CLK_FREQUENCY / (2 * SPI_FREQUENCY);
    logic [$clog2(CLK_COUNT)-1:0] clk_counter;

    logic spi_clk_enable, spi_clk_last, spi_clk_falling, spi_clk_rising;
    always_ff @(posedge clk) begin
        if (spi_clk_enable) begin
            if (clk_counter == 0) begin
                // Toggle SPI clock
                spi_clk <= ~spi_clk;
                clk_counter <= CLK_COUNT - 1'b1;
            end else begin
                clk_counter <= clk_counter - 1'b1;
            end
        end else begin
            spi_clk <= 1'b1;
            // By starting the counter at 0, we have an instant falling edge
            // when spi_clk_enable is asserted.
            clk_counter <= 0;
        end
        // Record last value for event detection.
        spi_clk_last <= spi_clk;
    end

    assign spi_clk_falling = (spi_clk == 1'b0) && (spi_clk_last == 1'b1);
    assign spi_clk_rising = (spi_clk == 1'b1) && (spi_clk_last == 1'b0);

    // ------------------------ //
    // Misc combinational logic //
    // ------------------------ //

    logic pending_request;
    assign pending_request = tx_request | rx_request;

    // --------------------- //
    // State Machine Signals //
    // --------------------- //
    typedef enum logic [1:0] {IDLE, TO_ACTIVE, ACTIVE, TO_IDLE} state_t;
    state_t state, state_next;

    logic [$clog2(DATASIZE)-1:0] count, count_next;
    logic spi_csn_next, spi_sdi_next, rx_valid_next;

    // Signals to store the request signals.
    logic save_requests, tx_request_r, rx_request_r; 
    logic [DATASIZE-1:0] tx_data_r;
    logic [DATASIZE-1:0] rx_data_next;

    // Memory element update
    always_ff @(posedge clk) begin
        // Resettable flops
        if (reset_n == 1'b0) begin
            state <= IDLE;
            spi_csn <= 1'b1;
            spi_sdi <= 1'b1;
            idlecount <= 0;
        end else begin
            state <= state_next;
            spi_csn <= spi_csn_next;
            spi_sdi <= spi_sdi_next;
            idlecount <= idlecount_next;
        end

        // Nonresettable flops
        count <= count_next;
        rx_data <= rx_data_next;
        rx_valid <= rx_valid_next;

        // Save inputs
        if (save_requests) begin
            tx_request_r = tx_request;
            tx_data_r = tx_data;
            rx_request_r = rx_request;
        end 
    end

    // Next state logic
    always_comb begin
        // Default next states
        state_next = state;
        count_next = count;

        spi_sdi_next = spi_sdi;
        spi_csn_next = 1'b1;

        rx_data_next = rx_data;
        rx_valid_next = 1'b0;

        idlecount_next = idlecount;

        // Default combinational output
        save_requests = 1'b0; 
        spi_clk_enable = 1'b0;
        ack_request = 1'b0;
        active = 1'b1;
        
        // Logic
        case (state)
            IDLE: begin
                active = 1'b0;
                if (pending_request && (idlecount == 0)) begin
                    save_requests = 1'b1;
                    // Assert chip select.
                    spi_csn_next = 1'b0; 

                    state_next = TO_ACTIVE;
                end

                if (idlecount > 0) begin
                    idlecount_next = idlecount - 1'b1;
                end
            end

            TO_ACTIVE: begin
                // Keep chip select asserted.
                spi_csn_next = 1'b0; 
                spi_clk_enable = 1'b1;
                // Acknowledge that the request has begun.
                ack_request = 1'b1;
                count_next = DATASIZE - 1'b1;
                state_next = ACTIVE; 
            end

            ACTIVE: begin
                spi_csn_next = 1'b0;
                spi_clk_enable = 1'b1;

                // Write on falling edges
                if (tx_request_r && spi_clk_falling) begin
                    spi_sdi_next = tx_data_r[count];
                end

                // Read on rising edges
                if (rx_request_r && spi_clk_rising) begin
                    rx_data_next = {rx_data[DATASIZE-2:0], spi_sdo};
                end 

                // Update counter on rising edges of the SPI clock. Since the
                // clock line begins high, this will result in an equal number
                // of negative edges and positive edges.
                if (spi_clk_rising) begin
                    // Check if performing another transaction.
                    if (count == 0) begin
                        // Indicate that read data is valid.
                        if (rx_request_r) begin
                            rx_valid_next = 1'b1;
                        end 

                        // If there is a pending request, acknowledge it.
                        if (pending_request) begin
                            save_requests = 1'b1;
                            state_next = TO_ACTIVE;
                        end else begin
                            state_next = TO_IDLE;
                        end
                    end else begin
                        count_next = count - 1'b1;
                    end

                end 
            end

            // SPI Clock should already be high since count in the previous
            // state is incremented on the rising edge of the clock.
            TO_IDLE: begin
                spi_csn_next = 1'b0;
                spi_sdi_next = 1'b1;
                idlecount_next = IDLE_CLOCKS - 1'b1;
                state_next = IDLE;
            end
        endcase
    end
endmodule // spi