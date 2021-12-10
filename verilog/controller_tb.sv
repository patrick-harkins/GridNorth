
//`include "controller.sv"
//`include "controller_struct1.sv"
//`include "controller_struct2.sv"
`include "controller_struct3.sv"

`timescale 10ns/10ns

// The good thing about bees today is that they're pretty much unhackable

module controller_tb();

    logic clk;
    logic rst;
    logic start;
    logic potential_ovf;
    logic spike_on_axon;
    logic crossbar;
    logic in_ex;
    logic leak_sign;
    
    logic [1:0] s_output_potential;
    logic [1:0] s_adder;
    logic [3:0] neuron_addr;
    logic [3:0] axon_addr;
    logic spike_buffer_wen;
    logic output_spike_buffer_dout;
    logic output_spike_buffer_wen;
    logic potential_memory_wen;
    logic ready;

    integer exp_neuron_addr;
    integer exp_axon_addr;
    integer extra_cycles;

    logic [31:0] seed = 8;

    task goto_next_state();
        logic [31:0] random_bits;

        random_bits = $urandom;

        potential_ovf = random_bits[0];
        spike_on_axon = random_bits[1];
        crossbar = random_bits[2];
        in_ex = random_bits[3];
        leak_sign = random_bits[4];

        #2;

        $display("INPUTS: pot_ovf=%d, spike=%d, cross=%d, in_ex=%d, leak_sign=%d",
        potential_ovf, spike_on_axon, crossbar, in_ex, leak_sign);

        $display("OUTPUTS: s_out_pot=%d, s_add=%d, neur_addr=%d, axon_addr=%d, spk_buf_wen=%d, out_spk_buf_wen=%d, out_spk_buf_dout=%d, pot_mem_wen=%d, ready=%d",
        s_output_potential, s_adder, neuron_addr, axon_addr,
        spike_buffer_wen, output_spike_buffer_wen, output_spike_buffer_dout,
        potential_memory_wen, ready);
    endtask

    task _assert(logic condition, integer number);
        if (!condition) begin
            $display("ASSERTION FAILED #%d", number);
            $finish;
        end
    endtask

    controller control (
        .clk(clk),
        .rst(rst),
        .start(start),
        .potential_ovf(potential_ovf),
        .spike_on_axon(spike_on_axon),
        .crossbar(crossbar),
        .in_ex(in_ex),
        .leak_sign(leak_sign),
        .s_output_potential(s_output_potential),
        .s_adder(s_adder),
        .neuron_addr(neuron_addr),
        .axon_addr(axon_addr),
        .spike_buffer_wen(spike_buffer_wen),
        .output_spike_buffer_wen(output_spike_buffer_wen),
        .output_spike_buffer_dout(output_spike_buffer_dout),
        .potential_memory_wen(potential_memory_wen),
        .ready(ready)
    );

    always #5 clk = ~clk;

    initial begin
        $random(seed);

        clk = 0;
        rst = 1;

        #8; rst = 0; start = 1; goto_next_state();  // expected WAIT state

        _assert(spike_buffer_wen === 0,          182);
        _assert(output_spike_buffer_wen === 0,   183);
        _assert(potential_memory_wen === 0,      184);
        _assert(ready===1,                       185);

        // -----------------------------------------------------------------

        #8; start = 0; goto_next_state(); // expected state START
        _assert(spike_buffer_wen === 1,          0);

        // extra checks
        _assert(output_spike_buffer_wen === 0,   13);
        _assert(potential_memory_wen === 0,      14);
        _assert(ready===0,                       15);

        // -----------------------------------------------------------------
        

        for (exp_neuron_addr = 0; exp_neuron_addr < 16; exp_neuron_addr = exp_neuron_addr + 1) begin
            #8; goto_next_state(); // expected state LOAD
            _assert(s_output_potential === 1,                20);
            _assert(neuron_addr === exp_neuron_addr,         30);

            // extra checks
            _assert(spike_buffer_wen === 0,          32);
            _assert(output_spike_buffer_wen === 0,   33);
            _assert(potential_memory_wen === 0,      34);
            _assert(ready===0,                       35);

            // -----------------------------------------------------------------

            for (exp_axon_addr = 0; exp_axon_addr < 16; exp_axon_addr = exp_axon_addr + 1) begin
                #8; goto_next_state(); // expected state ACC
                _assert(axon_addr === exp_axon_addr,         40);
                
                if (in_ex) begin
                    _assert(s_adder === 0,                   50);
                end else begin
                    _assert(s_adder === 1,                   60);
                end

                if ((spike_on_axon && crossbar) && !(
                    (!potential_ovf && !in_ex) || // inhibit + no overflow == actual overflow
                    (potential_ovf && in_ex) // excite + overflow == actual overflow
                )) begin
                    _assert(s_output_potential === 3,        70);
                end else begin
                    _assert(s_output_potential === 0,        80);
                end

                // extra checks
                _assert(spike_buffer_wen === 0,          42);
                _assert(output_spike_buffer_wen === 0,   43);
                _assert(potential_memory_wen === 0,      44);
                _assert(ready===0,                       45);
            end

            // -----------------------------------------------------------------

            #8; goto_next_state(); // expected state ST_LEAK
            _assert(s_adder === 2,                       90);
            if (!(potential_ovf ^ leak_sign)) begin
                _assert(s_output_potential === 3,        100);
            end else begin
                _assert(s_output_potential === 0,        101);
            end

            // extra checks
            _assert(spike_buffer_wen === 0,          102);
            _assert(output_spike_buffer_wen === 0,   103);
            _assert(potential_memory_wen === 0,      104);
            _assert(ready===0,                       105);

            // -----------------------------------------------------------------

            #8; goto_next_state(); // expected state ST_THRESH
            _assert(s_adder === 3,                       110);

            if (potential_ovf) begin
                _assert(s_output_potential === 3,        120);
            end else begin
                _assert(s_output_potential === 0,        130);
            end

            if (potential_ovf) begin
                _assert(output_spike_buffer_dout === 1,  140);
            end else begin
                _assert(output_spike_buffer_dout === 0,  150);
            end
            _assert(output_spike_buffer_wen === 1,   151);

            // extra checks
            _assert(spike_buffer_wen === 0,          152);
            _assert(potential_memory_wen === 0,      154);
            _assert(ready===0,                       155);

            // -----------------------------------------------------------------

            #8; goto_next_state(); // expected state ST_LOOP
            _assert(potential_memory_wen === 1,          160);
            _assert(neuron_addr === exp_neuron_addr,     170);

            // extra checks
            _assert(s_output_potential === 0,        171);
            _assert(spike_buffer_wen === 0,          172);
            _assert(output_spike_buffer_wen === 0,   173);
            _assert(ready===0,                       175);
        end

        for (extra_cycles = 0; extra_cycles < 20; extra_cycles = extra_cycles + 1) begin
            #8; goto_next_state(); // expected state ST_WAIT

            // extra checks
            _assert(spike_buffer_wen === 0,          182);
            _assert(output_spike_buffer_wen === 0,   183);
            _assert(potential_memory_wen === 0,      184);
            _assert(ready===1,                       185);
        end

        $display("\nSIMULATION PASSED!");
        $finish;
    end

endmodule