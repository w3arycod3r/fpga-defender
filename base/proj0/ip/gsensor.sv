// Source: https://github.com/hildebrandmw/de10lite-hdl

module gsensor #(
        parameter CLK_FREQUENCY = 50_000_000,
        parameter SPI_FREQUENCY = 2_000_000,
        parameter IDLE_NS = 200,
        parameter UPDATE_FREQUENCY = 50
    )(
        input reset_n,
        input clk,
        output logic data_valid,
        output logic [15:0] data_x,
        output logic [15:0] data_y,
        output logic [15:0] data_z,

        // SPI Signals
        output SPI_SDI,
        input SPI_SDO,
        output SPI_CSN,
        output SPI_CLK
    );

    // Update ticker
    localparam UPDATE_CLOCK_COUNT = CLK_FREQUENCY / UPDATE_FREQUENCY;
    logic [$clog2(UPDATE_CLOCK_COUNT)-1:0] update_clock_counter = 0;
    logic update;

    always_ff @(posedge clk) begin
        if (update_clock_counter == 0) begin
            update_clock_counter <= UPDATE_CLOCK_COUNT - 1'b1;
            update <= 1'b1;
        end else begin
            update_clock_counter <= update_clock_counter - 1'b1;
            update <= 1'b0;
        end
    end


    // Opcodes
    typedef enum logic [2:0] {
        // Read 8 bits from the SPI
        READ,
        // Write 8 bits to the SPI
        WRITE,
        // Wait for SPI serdes to go idle.
        WAIT_FOR_IDLE,
        // Wait until update signal
        WAIT_FOR_UPDATE,
        // Jump to address
        JUMP,
        // Notify data valid.
        NOTIFY
    } opcode_t;

    // Instruction struct
    typedef struct packed {
        opcode_t opcode;
        logic [7:0] immediate;
    } instruction_t;

    localparam logic WRITE_BIT = 1'b0;
    localparam logic READ_BIT = 1'b1;
    localparam logic SINGLE_ACTION = 1'b0;
    localparam logic MULTI_ACTION = 1'b1;

    // Write Reg Address 
    localparam   BW_RATE         = 6'h2c;
    localparam   POWER_CONTROL   = 6'h2d;
    localparam   DATA_FORMAT     = 6'h31;
    localparam   INT_ENABLE      = 6'h2E;
    localparam   INT_MAP         = 6'h2F;
    localparam   THRESH_ACT      = 6'h24;
    localparam   THRESH_INACT    = 6'h25;
    localparam   TIME_INACT      = 6'h26;
    localparam   ACT_INACT_CTL   = 6'h27;
    localparam   THRESH_FF       = 6'h28;
    localparam   TIME_FF         = 6'h29;

    // This method of initialization might not work ...
    localparam NUM_INSTRUCTIONS = 44;
    logic [$clog2(NUM_INSTRUCTIONS)-1:0] pc, pc_next;

    instruction_t current_instruction;
    opcode_t current_opcode;

    instruction_t spi_program [0:NUM_INSTRUCTIONS-1];
    initial begin
        spi_program = '{
            // -- Initialization routine
            // Set activation threshold
            {WRITE, {WRITE_BIT, SINGLE_ACTION, THRESH_ACT}},
            {WRITE, 8'h20},
            {WAIT_FOR_IDLE, 8'h00},
            // Set inactivation threshold
            {WRITE, {WRITE_BIT, SINGLE_ACTION, THRESH_INACT}},
            {WRITE, 8'h03},
            {WAIT_FOR_IDLE, 8'h00},
            // Set inactive timeout
            {WRITE, {WRITE_BIT, SINGLE_ACTION, TIME_INACT}},
            {WRITE, 8'h01},
            {WAIT_FOR_IDLE, 8'h00},
            // set Acitavation detection to DC Coupled, inactivate ac coupled
            // configure all axes to be active
            {WRITE, {WRITE_BIT, SINGLE_ACTION, ACT_INACT_CTL}},
            {WRITE, 8'h7f},
            {WAIT_FOR_IDLE, 8'h00},
            // Initialise freefall detection to recommended value
            {WRITE, {WRITE_BIT, SINGLE_ACTION, THRESH_FF}},
            {WRITE, 8'h09},
            {WAIT_FOR_IDLE, 8'h00},
            // Initialize freefall time to recommended value
            {WRITE, {WRITE_BIT, SINGLE_ACTION, TIME_FF}},
            {WRITE, 8'h46},
            {WAIT_FOR_IDLE, 8'h00},
            // Output Rate: 50 Hz
            {WRITE, {WRITE_BIT, SINGLE_ACTION, BW_RATE}},
            {WRITE, 8'h09},
            {WAIT_FOR_IDLE, 8'h00},
            // Enable interrupts on activity only
            {WRITE, {WRITE_BIT, SINGLE_ACTION, INT_ENABLE}},
            {WRITE, 8'h10},
            {WAIT_FOR_IDLE, 8'h00},
            // Send the interrupt to pin INT2
            {WRITE, {WRITE_BIT, SINGLE_ACTION, INT_MAP}},
            {WRITE, 8'h10},
            {WAIT_FOR_IDLE, 8'h00},
            // Configure for 4-wire SPI mode
            {WRITE, {WRITE_BIT, SINGLE_ACTION, DATA_FORMAT}},
            {WRITE, 8'h00},
            {WAIT_FOR_IDLE, 8'h00},
            // Configure chip to AUTO_SLEEP during inactivity
            {WRITE, {WRITE_BIT, SINGLE_ACTION, POWER_CONTROL}},
            {WRITE, 8'h08},
            {WAIT_FOR_IDLE, 8'h00},

            // -- Main read loop --
            // Wait for update signal
            {WAIT_FOR_UPDATE, 8'h00}, 
            // read data
            {WRITE, {READ_BIT, MULTI_ACTION, 6'h32}},
            {READ, 8'h00},
            {READ, 8'h01},
            {READ, 8'h02},
            {READ, 8'h03},
            {READ, 8'h04},
            {READ, 8'h05},
            // Wait for last read data to become available.
            {WAIT_FOR_IDLE, 8'h00},
            {NOTIFY, 8'h00},
            // Jump to address 33 (start of main loop)
            {JUMP, 8'd33}
        };
    end

    // ---------------------- //
    // Instantiate SPI Serdes //
    // ---------------------- //
    logic [7:0] tx_data, rx_data;    
    logic tx_request, rx_request, rx_valid, ack_request, active;

    assign tx_data = current_instruction.immediate;

    spi #(
        .CLK_FREQUENCY(CLK_FREQUENCY),
        .SPI_FREQUENCY(SPI_FREQUENCY),
        .IDLE_NS(IDLE_NS)
    ) u0 (
        .reset_n    (reset_n),
        .clk        (clk),
        .tx_request (tx_request),
        .tx_data    (tx_data),
        .rx_request (rx_request),
        .rx_data    (rx_data),
        .rx_valid   (rx_valid),
        .ack_request(ack_request),
        .active     (active),
        // spi signal passthrough
        .spi_sdi    (SPI_SDI),
        .spi_sdo    (SPI_SDO),
        .spi_csn    (SPI_CSN),
        .spi_clk    (SPI_CLK)
    );


    // --------- //
    // Processor //
    // --------- //

    // RX Monitor
    logic monitor_rx;
    logic monitor_rx_r;
    logic [7:0] address;
    logic [7:0] memory [5:0];

    always_ff @(posedge clk) begin
        // Set and clear monitor_rx flag
        if (monitor_rx) begin
            address <= current_instruction.immediate;
            monitor_rx_r <= 1'b1;
        end else if (rx_valid) begin
            monitor_rx_r <= 1'b0;
        end

        // If waiting for request, save data to the saved address.
        if (rx_valid && monitor_rx_r) begin
            memory[address] <= rx_data;
        end
    end

    // Unpack memory
    assign data_x = {memory[1], memory[0]};
    assign data_y = {memory[3], memory[2]};
    assign data_z = {memory[5], memory[4]};

    // Processor implementation
    always_ff @(posedge clk) begin  
        pc <= pc_next;
        current_instruction <= spi_program[pc_next];
    end

    always_comb begin
        // Default initial values
        if (reset_n == 1'b0) begin
            pc_next = 0;
        end else begin
            pc_next = pc;
        end

        // Default outputs
        tx_request = 1'b0; 
        rx_request = 1'b0;
        data_valid = 1'b0;
        monitor_rx = 1'b0;

        // Convenience assignments
        current_opcode = current_instruction.opcode;

        case (current_opcode)
            READ: begin
                rx_request = 1'b1;
                if (ack_request) begin
                    monitor_rx = 1'b1;
                    pc_next = pc + 1'b1;
                end
            end

            WRITE: begin
                tx_request = 1'b1;
                // Increment PC if TX is acknowledged.
                if (ack_request) begin
                    pc_next = pc + 1'b1;
                end
            end

            WAIT_FOR_IDLE: begin
                if (active == 1'b0) begin
                    pc_next = pc + 1'b1;
                end
            end

            WAIT_FOR_UPDATE: begin
                if (update) begin
                    pc_next = pc + 1'b1;
                end
            end

            JUMP: begin
                pc_next = current_instruction.immediate;
            end

            NOTIFY: begin
                data_valid = 1'b1;
                pc_next = pc + 1'b1;
            end
        endcase
    end
endmodule