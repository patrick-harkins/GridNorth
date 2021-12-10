// Basic TrueNorth-inspired SNN core (GridNorth?)
// 16 neurons, 4-bit potentials, virtual crossbar interconnect
// Basic I/O provided by spike buffer

module core(input clk,
	    input rst,
	    input start,
	    input crossbar_wen,
	    input [3:0] crossbar_waddr,
	    input in_ex_wen,
	    input spike_in_wen,
	    input [15:0] spike_in_din,
	    input [15:0] in_ex_din,
	    input [21:0] crossbar_din,
	    output ready,
	    output [15:0] spike_buffer);
   wire [1:0] s_output_potential, s_adder;
   wire [3:0] input_potential, output_potential, threshold;
   wire [1:0] leak;
   wire potential_ovf, leak_sign;
   wire spike_on_axon, crossbar, in_ex;
   wire [3:0] neuron_addr, axon_addr;
   wire output_spike_buffer_wen, output_spike_buffer_dout;
   wire [15:0] output_spike_buffer, to_spike_buffer;
   wire spike_buffer_wen;
   wire [15:0] spike_buffer_out;
   wire potential_memory_wen;
   wire [15:0] in_ex_16;
   wire [15:0] spike_in;

   datapath datapath0(
      .clk                (clk),
      .input_potential    (input_potential),
      .leak               (leak),
      .threshold          (threshold),
      .s_output_potential (s_output_potential),
      .s_adder            (s_adder),
      .output_potential   (output_potential),
      .overflow           (potential_ovf),
		.leak_sign          (leak_sign)
   );

   controller control0(
      .clk                      (clk),
      .rst                      (rst),
      .start                    (start),
      .potential_ovf            (potential_ovf),
		.leak_sign                (leak_sign),
      .spike_on_axon            (spike_on_axon),
      .crossbar                 (crossbar),
      .in_ex                    (in_ex),
      .s_output_potential       (s_output_potential),
      .s_adder                  (s_adder),
      .neuron_addr              (neuron_addr),
      .axon_addr                (axon_addr),
      .spike_buffer_wen         (spike_buffer_wen),
      .output_spike_buffer_wen  (output_spike_buffer_wen),
      .output_spike_buffer_dout (output_spike_buffer_dout),
      .potential_memory_wen     (potential_memory_wen),
      .ready                    (ready)
   );

   output_spike_buffer output_spike_buf0(
      .clk (clk),
      .rst (rst),
      .wen (output_spike_buffer_wen),
      .din (output_spike_buffer_dout),
      .d   (output_spike_buffer)
   );

   or16 input_spike_or(to_spike_buffer, output_spike_buffer, spike_in);

   reg16_enr spike_buffer0(
      .clk (clk),
      .rst (rst),
      .wen (spike_buffer_wen),
      .d   (to_spike_buffer),
      .q   (spike_buffer)
   );

   mux_16x1 spike_buffer_mux(spike_on_axon, spike_buffer, axon_addr);

   reg16_enr in_ex_buffer(
      .clk (clk),
      .rst (rst),
      .wen (in_ex_wen),
      .d (in_ex_din),
      .q (in_ex_16)
   );

   mux_16x1 in_ex_buffer_mux(in_ex, in_ex_16, axon_addr);

   reg16_enr spike_in0(
      .clk (clk),
      .rst (rst),
      .wen (spike_in_wen),
      .d   (spike_in_din),
      .q   (spike_in)
   );

   crossbar_memory cross_mem0(
      .clk         (clk),
      .wen         (crossbar_wen),
      .waddr       (crossbar_waddr),
      .din         (crossbar_din),
      .neuron_addr (neuron_addr),
      .axon_addr   (axon_addr),
      .crossbar    (crossbar),
      .threshold   (threshold),
      .leak        (leak)
   );

   potential_memory pot_mem0(
      .clk   (clk),
      .rst   (rst),
      .wen   (potential_memory_wen),
      .waddr (neuron_addr),
      .din   (output_potential),
      .raddr (neuron_addr),
      .dout  (input_potential)
   );
endmodule

module datapath(input clk,
			  input [3:0] input_potential,
			  input [1:0] leak,
			  input [3:0] threshold,
			  input [1:0] s_output_potential,
			  input [1:0] s_adder,
			  output [3:0] output_potential,
			  output overflow,
			  output leak_sign
	       );
	assign leak_sign = leak[1];
   // 2x120 + 1x126 + 1x104 = 470 transistors
   wire [3:0] adder_in, adder_out, out_pot_mux_out;
   // 0: 4'b0001 (this is the enhance option, adding one)
   // 1: 4'b1111 (this is the inhibit option, subtracting one)
   // 2: leak (the signed leak value, for calculating the neuron leak)
   // 3: threshold (for comparing the neuron potential to the threshold)
   mux4_4x1 adder_input_mux(adder_in, 4'b0001, 4'b1111, {leak[1], leak[1], leak},
			    threshold, s_adder);
   cr_adder4 adder0(adder_out, overflow, adder_in, output_potential);
   // 0: output from the adder
   // 1: input_potential (for loading the original potential into the register)
   // 2: 4'b0000 (for resetting the potential to zero after firing)
   // 3: output_potential- so no enable is required on the register
   mux4_4x1 output_potential_mux(out_pot_mux_out,
				 output_potential,
				 input_potential,
				 4'b0000,
				 adder_out,
				 s_output_potential);
   reg4 output_potential_reg(output_potential, clk, out_pot_mux_out);
endmodule

module controller(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic potential_ovf,
    input  logic spike_on_axon,
    input  logic crossbar,
    input  logic in_ex,
    input  logic leak_sign,
    output logic [1:0] s_output_potential,
    output logic [1:0] s_adder,
    output logic [3:0] neuron_addr,
    output logic [3:0] axon_addr,
    output logic spike_buffer_wen,
    output logic output_spike_buffer_wen,
    output logic output_spike_buffer_dout,
    output logic potential_memory_wen,
    output logic ready
    );
    // 682 transistors

    logic s_neuron_addr, s_axon_addr;
    logic en_neuron_addr, en_axon_addr;

    logic state_WAIT, state_WAIT_next;
    logic state_START, state_START_next;
    logic state_LOAD, state_LOAD_next;
    logic state_ACC, state_ACC_next;
    logic state_LEAK, state_LEAK_next;
    logic state_THRESH, state_THRESH_next;
    logic state_LOOP, state_LOOP_next;

    logic rst_inv;
    logic start_inv;
    logic neuron_addr_max_inv;
    logic axon_addr_max_inv;
    logic spike_inv;
    logic in_ex_inv;
    logic state_ACC_inv;
    logic state_START_inv;
    logic state_LOAD_inv;
    logic state_LOOP_inv;
    logic state_THRESH_inv;
    logic state_LEAK_inv;

    logic n0_0, n0_1, n0_2, n0_3, n0_4, n0_5, n0_6, n0_7, n0_8, n0_9;
    logic n1_0, n1_1, n1_2, n1_3, n1_4, n1_5, n1_6, n1_7, n1_8;
    logic n2_0, n2_1, n2_2, n2_3, n2_4, n2_5, n2_6, n2_7, n2_8;

    // possibly move to datapath
    logic spike;
    logic potential_ovf_inv;
    logic in_ex_no_ovf;
    logic spike_no_ovf;
    logic neuron_addr_max;
    logic axon_addr_max;
    logic leak_no_ovf, leak_no_ovf_inv;

    // 13 inverters -- 26 transistors
    not (rst_inv,               rst                 );
    not (start_inv,             start               );
    not (neuron_addr_max_inv,   neuron_addr_max     );
    not (axon_addr_max_inv,     axon_addr_max       );
    not (spike_inv,             spike               );
    not (in_ex_inv,             in_ex               );
    not (state_START_inv,       state_START         );
    not (state_LOAD_inv,        state_LOAD          );
    not (state_LOOP_inv,        state_LOOP          );
    not (state_THRESH_inv,      state_THRESH        );
    not (state_LEAK_inv,        state_LEAK          );
    not (state_ACC_inv,         state_ACC           );

    // 8 NANDS, 2 ANDS -- 44 transistors
    nand(n0_0,                  state_WAIT,         start_inv           );
    nand(n0_1,                  state_LOOP,         neuron_addr_max     );
    and (n0_2,                  state_WAIT,         start               );
    nand(n0_3,                  state_LOOP,         neuron_addr_max_inv );
    nand(n0_4,                  state_ACC,          axon_addr_max_inv   );
    and (n0_5,                  state_ACC,          axon_addr_max       );
    nand(n0_6,                  state_ACC,          spike_no_ovf        );
    nand(n0_7,                  state_LEAK,         leak_no_ovf         );
    nand(n0_8,                  state_ACC,          in_ex_inv           );
    nand(n0_9,                  state_THRESH,       potential_ovf       );

    // 6 NANDS, 3 ANDS -- 42 transistors
    and (n1_0,                  n0_0,               n0_1                );
    nand(n1_1,                  state_START_inv,    n0_3                );
    nand(n1_2,                  state_LOAD_inv,     n0_4                );
    and (n1_3,                  n0_6,               n0_7                );
    nand(n1_4,                  state_THRESH_inv,   n0_8                );
    nand(n1_5,                  state_LEAK_inv,     state_THRESH_inv    );
    nand(n1_6,                  state_LOAD_inv,     state_ACC_inv       );
    nand(n1_7,                  state_START_inv,    state_LOOP_inv      );
    and (n1_8,                  state_LOAD_inv,     n0_9                );
    
    // 3 NANDS, 6 ANDS -- 48 transistors
    nand(n2_0,                  rst_inv,            n1_0                );
    and (n2_1,                  rst_inv,            n0_2                );
    and (n2_2,                  rst_inv,            n1_1                );
    and (n2_3,                  rst_inv,            n1_2                );
    and (n2_4,                  rst_inv,            n0_5                );
    and (n2_5,                  rst_inv,            state_LEAK          );
    and (n2_6,                  rst_inv,            state_THRESH        );
    nand(n2_7,                  n1_3,               n1_8                );
    nand(n2_8,                  n1_3,               n0_9                );

    assign state_WAIT_next      = n2_0;
    assign state_START_next     = n2_1;
    assign state_LOAD_next      = n2_2;
    assign state_ACC_next       = n2_3;
    assign state_LEAK_next      = n2_4;
    assign state_THRESH_next    = n2_5;
    assign state_LOOP_next      = n2_6;


    assign s_output_potential[0]    = n2_7;
    assign s_output_potential[1]    = n2_8;    
    assign s_adder[0]               = n1_4;
    assign s_adder[1]               = n1_5;
    assign en_axon_addr             = n1_6;
    assign s_axon_addr              = state_ACC;
    assign en_neuron_addr           = n1_7;
    assign s_neuron_addr            = state_LOOP;
    assign spike_buffer_wen         = state_START;
    assign output_spike_buffer_wen  = state_THRESH;
    assign output_spike_buffer_dout = potential_ovf;
    assign potential_memory_wen     = state_LOOP;
    assign ready                    = state_WAIT;

    // store state -- 112 transistors
    ff state0(state_WAIT,      clk, state_WAIT_next    );
    ff state1(state_START,     clk, state_START_next   );
    ff state2(state_LOAD,      clk, state_LOAD_next    );
    ff state3(state_ACC,       clk, state_ACC_next     );
    ff state4(state_LEAK,      clk, state_LEAK_next    );
    ff state5(state_THRESH,    clk, state_THRESH_next  );
    ff state6(state_LOOP,      clk, state_LOOP_next    );

    // counters -- 384 transistors
    counter4 axon_addr_counter (
        .clk    (clk            ),
        .en     (en_axon_addr   ),
        .sel    (s_axon_addr    ),
        .count  (axon_addr      ),
        .max    (axon_addr_max  )
    );
    counter4 neuron_addr_counter (
        .clk    (clk            ),
        .en     (en_neuron_addr ),
        .sel    (s_neuron_addr  ),
        .count  (neuron_addr    ),
        .max    (neuron_addr_max)
    );

    // threshold logic -- 26 transistors
    and(spike, spike_on_axon, crossbar);
    not(potential_ovf_inv, potential_ovf);
    xor(in_ex_no_ovf, potential_ovf, in_ex);
    and(spike_no_ovf, spike, in_ex_no_ovf);
    xor(leak_no_ovf_inv, potential_ovf, leak_sign);
    not(leak_no_ovf, leak_no_ovf_inv);

endmodule

module counter4(
    input clk,
    input en,
    input sel,
    output [3:0] count,
    output max
	);
    // 192 transistors

    logic c0, c1, c2, c3;
    logic carry1, carry2, carry3, carry4;
    logic c0_inc, c1_inc, c2_inc, c3_inc;
    logic c0_sel, c1_sel, c2_sel, c3_sel;
    logic c0_next, c1_next, c2_next, c3_next;
    logic c0_next_inv, c1_next_inv, c2_next_inv, c3_next_inv;

    // carry chain calculation -- 18 transistors
    assign carry1 = c0;
    and(carry2, carry1, c1);
    and(carry3, carry2, c2);
    and(carry4, carry3, c3);

    // incremented value calculation -- 38 transistors
    not(c0_inc, c0);
    xor(c1_inc, c1, carry1);
    xor(c2_inc, c2, carry2);
    xor(c3_inc, c3, carry3);

    // select incremented value or 0 -- 24 transistors
    and(c0_sel, c0_inc, sel);
    and(c1_sel, c1_inc, sel);
    and(c2_sel, c2_inc, sel);
    and(c3_sel, c3_inc, sel);

    // enable to select past value or select value -- 40 transistors
    invmux_2x1 en_mux0(c0_next_inv, c0, c0_sel, en);
    invmux_2x1 en_mux1(c1_next_inv, c1, c1_sel, en);
    invmux_2x1 en_mux2(c2_next_inv, c2, c2_sel, en);
    invmux_2x1 en_mux3(c3_next_inv, c3, c3_sel, en);

    // invert to get next value -- 8 transistors
    not(c0_next, c0_next_inv);
    not(c1_next, c1_next_inv);
    not(c2_next, c2_next_inv);
    not(c3_next, c3_next_inv);

    // store value -- 64 transistors
    ff bit0(c0, clk, c0_next);
    ff bit1(c1, clk, c1_next);
    ff bit2(c2, clk, c2_next);
    ff bit3(c3, clk, c3_next);

    assign count = {c3, c2, c1, c0};
    assign max = carry4;
endmodule

module output_spike_buffer(input clk,
		    input rst,
		    input wen,
		    input din,
		    output [15:0] d);
   // Shift register
   // 16x38 = 608 transistors
   ff_enr ff4_en_ff0(d[15], wen, clk, rst, din);
   ff_enr ff4_en_ff1(d[14], wen, clk, rst, d[15]);
   ff_enr ff4_en_ff2(d[13], wen, clk, rst, d[14]);
   ff_enr ff4_en_ff3(d[12], wen, clk, rst, d[13]);
   ff_enr ff4_en_ff4(d[11], wen, clk, rst, d[12]);
   ff_enr ff4_en_ff5(d[10], wen, clk, rst, d[11]);
   ff_enr ff4_en_ff6(d[9], wen, clk, rst, d[10]);
   ff_enr ff4_en_ff7(d[8], wen, clk, rst, d[9]);
   ff_enr ff4_en_ff8(d[7], wen, clk, rst, d[8]);
   ff_enr ff4_en_ff9(d[6], wen, clk, rst, d[7]);
   ff_enr ff4_en_ff10(d[5], wen, clk, rst, d[6]);
   ff_enr ff4_en_ff11(d[4], wen, clk, rst, d[5]);
   ff_enr ff4_en_ff12(d[3], wen, clk, rst, d[4]);
   ff_enr ff4_en_ff13(d[2], wen, clk, rst, d[3]);
   ff_enr ff4_en_ff14(d[1], wen, clk, rst, d[2]);
   ff_enr ff4_en_ff15(d[0], wen, clk, rst, d[1]);
endmodule

module reg16_enr(input clk,
		 input rst,
		 input wen,
		 input [15:0] d,
		 output [15:0] q);
   // 16x46 = 736 transistors
   ff_enr ff4_enr_ff0(q[0], wen, clk, rst, d[0]);
   ff_enr ff4_enr_ff1(q[1], wen, clk, rst, d[1]);
   ff_enr ff4_enr_ff2(q[2], wen, clk, rst, d[2]);
   ff_enr ff4_enr_ff3(q[3], wen, clk, rst, d[3]);
   ff_enr ff4_enr_ff4(q[4], wen, clk, rst, d[4]);
   ff_enr ff4_enr_ff5(q[5], wen, clk, rst, d[5]);
   ff_enr ff4_enr_ff6(q[6], wen, clk, rst, d[6]);
   ff_enr ff4_enr_ff7(q[7], wen, clk, rst, d[7]);
   ff_enr ff4_enr_ff8(q[8], wen, clk, rst, d[8]);
   ff_enr ff4_enr_ff9(q[9], wen, clk, rst, d[9]);
   ff_enr ff4_enr_ff10(q[10], wen, clk, rst, d[10]);
   ff_enr ff4_enr_ff11(q[11], wen, clk, rst, d[11]);
   ff_enr ff4_enr_ff12(q[12], wen, clk, rst, d[12]);
   ff_enr ff4_enr_ff13(q[13], wen, clk, rst, d[13]);
   ff_enr ff4_enr_ff14(q[14], wen, clk, rst, d[14]);
   ff_enr ff4_enr_ff15(q[15], wen, clk, rst, d[15]);
endmodule

module crossbar_memory(input clk,
		       input wen,
		       input [3:0] waddr,
		       input [21:0] din,
		       input [3:0] neuron_addr,
		       input [3:0] axon_addr,
		       output crossbar,
		       output [3:0] threshold,
		       output [1:0] leak);
   reg [15:0] crossbar_ram [15:0];
   reg [3:0] threshold_ram [15:0];
   reg [1:0] leak_ram [15:0];
   integer i;

   initial begin
      for (i = 0; i < 16; i = i + 1) begin
	 crossbar_ram[i] = 16'b0;
	 threshold_ram[i] = 4'h0;
	 leak_ram[i] = 2'b00;
      end
      // Set initial values here
   end

   always @(posedge clk)
      if (wen) begin
	 crossbar_ram[waddr] <= din[21:6];
	 threshold_ram[waddr] <= din[5:2];
	 leak_ram[waddr] <= din[1:0];
      end

   assign crossbar = crossbar_ram[neuron_addr][axon_addr];
   assign threshold = threshold_ram[neuron_addr];
   assign leak = leak_ram[neuron_addr];
endmodule

module potential_memory(input clk,
			input rst,
			input wen,
			input [3:0] waddr,
			input [3:0] din,
			input [3:0] raddr,
			output [3:0] dout);
   reg [3:0] ram [15:0];
   integer i;

   initial begin
      for (i = 0; i < 16; i = i + 1) ram[i] = 4'h0;
      /// Load initial potentials here
   end

   always @(posedge clk)
      if (wen) ram[waddr] <= din;

   assign dout = ram[raddr];
endmodule

module cr_adder4(output [3:0] s, output cout, input [3:0] a, b);
   // 1x18 + 3x36 = 126 transistors
   wire cout0, cout1, cout2;
   half_adder a4_ha0(s[0], cout0, a[0], b[0]);
   full_adder a4_fa1(s[1], cout1, a[1], b[1], cout0);
   full_adder a4_fa2(s[2], cout2, a[2], b[2], cout1);
   full_adder a4_fa3(s[3], cout, a[3], b[3], cout2);
endmodule

module mux4_4x1(output [3:0] y, input [3:0] d0, d1, d2, d3, input [1:0] s);
   // 4x30 = 120 transistors
   mux_4x1 mux4_4x1_m0(y[0], d0[0], d1[0], d2[0], d3[0], s);
   mux_4x1 mux4_4x1_m1(y[1], d0[1], d1[1], d2[1], d3[1], s);
   mux_4x1 mux4_4x1_m2(y[2], d0[2], d1[2], d2[2], d3[2], s);
   mux_4x1 mux4_4x1_m3(y[3], d0[3], d1[3], d2[3], d3[3], s);
endmodule

module reg4(output [3:0] q, input clk, input [3:0] d);
   // 4x26 = 104 transistors
   ff ff4_ff0(q[0], clk, d[0]);
   ff ff4_ff1(q[1], clk, d[1]);
   ff ff4_ff2(q[2], clk, d[2]);
   ff ff4_ff3(q[3], clk, d[3]);
endmodule

module reg4_en(output [3:0] q, input en, clk, input [3:0] d);
   // 4x38 = 152 transistors
   ff_en ff4_en_ff0(q[0], en, clk, d[0]);
   ff_en ff4_en_ff1(q[1], en, clk, d[1]);
   ff_en ff4_en_ff2(q[2], en, clk, d[2]);
   ff_en ff4_en_ff3(q[3], en, clk, d[3]);
endmodule

module reg4_enr(output [3:0] q, input en, clk, rst, input [3:0] d);
   // 4x46 = 184 transistors
   ff_enr ff4_enr_ff0(q[0], en, clk, rst, d[0]);
   ff_enr ff4_enr_ff1(q[1], en, clk, rst, d[1]);
   ff_enr ff4_enr_ff2(q[2], en, clk, rst, d[2]);
   ff_enr ff4_enr_ff3(q[3], en, clk, rst, d[3]);
endmodule

module half_adder(output s, cout, input a, b);
   // 1x12 + 1x4 + 1x2 = 18 transistors
   wire notcout;
   my_xor ha_xor0(s, a, b);
   nand(notcout, a, b);
   not(cout, notcout);
endmodule

module full_adder(output s, cout, input a, b, cin);
   // 2x12 + 3x4 = 36 transistors
   wire a_xor_b, nand0, nand1;
   my_xor fa_xor0(a_xor_b, a, b);
   my_xor fa_xor1(s, a_xor_b, cin);

   nand(nand0, a, b);
   nand(nand1, cin, a_xor_b);
   nand(cout, nand0, nand1);
endmodule

module my_xor(output y, input a, b);
   // 8 + 2x2 = 12 transistors
   /*supply0 gnd;
   supply1 pwr;
   wire nota, notb, n0, n1, p0, p1;
   not(nota, a);
   not(notb, b);

   nmos(n0, gnd, b);
   nmos(y, n0, a);
   nmos(n1, gnd, notb);
   nmos(y, n1, nota);

   pmos(p0, pwr, nota);
   pmos(y, p0, b);
   pmos(p1, pwr, a);
   pmos(y, p1, notb);*/
	xor(y, a, b);
endmodule

module mux_4x1(output y, input d0, d1, d2, d3, input [1:0] s);
   // 3x10 = 30 transistors
   // Restoring non-inverting pass-transistor-based mux,
   // from the book, Fig 1.30 (a), on page 16
   wire s1d0, s1d1;
   invmux_2x1 mux_4x1_s0m0(s1d0, d0, d1, s[0]);
   invmux_2x1 mux_4x1_s0m1(s1d1, d2, d3, s[0]);
   invmux_2x1 mux_4x1_s1m0(y, s1d0, s1d1, s[1]);
endmodule

module mux_16x1(output y, input [15:0] d, input [3:0] s);
   // 4x30 = 120 transistors
   wire m0, m1, m2, m3;
   mux_4x1 mux_16_m0(m0, d[0], d[1], d[2], d[3], s[1:0]);
   mux_4x1 mux_16_m1(m1, d[4], d[5], d[6], d[7], s[1:0]);
   mux_4x1 mux_16_m2(m2, d[8], d[9], d[10], d[11], s[1:0]);
   mux_4x1 mux_16_m3(m3, d[12], d[13], d[14], d[15], s[1:0]);
   mux_4x1 mux_16_m4(y, m0, m1, m2, m3, s[3:2]);
endmodule

module invmux_2x1(output logic y, input d0, d1, s);
   // 1x2 + 8 = 10 transistors
   // Restoring inverting pass-transistor-based mux,
   // from the book, Fig 1.29 (b), on page 16
   /*supply0 gnd;
   supply1 pwr;

   wire nots, d0npass, d0ppass, d1npass, d1ppass;

   not(nots, s);

   nmos(d0npass, gnd, d0);
   nmos(y, d0npass, nots);
   pmos(d0ppass, pwr, d0);
   pmos(y, d0ppass, s);

   nmos(d1npass, gnd, d1);
   nmos(y, d1npass, s);
   pmos(d1ppass, pwr, d1);
   pmos(y, d1ppass, nots);*/
	assign y = s ? ~d1 : ~d0;
endmodule

module my_dlatch(output q, input clk, d);
   // 1x10 + 2 = 12 transistors
   /* verilator lint_off UNOPTFLAT */
   wire notq;
   invmux_2x1 dlatch_m0(notq, q, d, clk);
   not(q, notq);
   /* verilator lint_on UNOPTFLAT */
endmodule

module ff(output q, input clk, d);
   // 1x2 + 2x12 = 26 transistors
   wire notclk, qm;
   not(notclk, clk);
   my_dlatch ff_master(qm, notclk, d);
   my_dlatch ff_slave(q, clk, qm);
endmodule

module ff_en(output q, input en, clk, d);
   // 1x10 + 1x2 + 1x26 = 38 transistors
   wire ff_d, notff_d;
   invmux_2x1 ff_en_m0(notff_d, q, d, en);
   not(ff_d, notff_d);
   ff ff_en_ff(q, clk, ff_d);
endmodule

module ff_enr(output q, input en, clk, rst, d);
   // 2x10 + 1x26 = 46 transistors
   wire ff_d, notff_d;
   invmux_2x1 ff_enr_m0(notff_d, q, d, en);
   invmux_2x1 ff_enr_m1(ff_d, notff_d, 1'b1, rst);
   ff ff_en_ff(q, clk, ff_d);
endmodule

module or16(output [15:0] y, input [15:0] a, b);
   // What it looks like
   // 16x6 = 96 transistors
   or(y[0], a[0], b[0]);
   or(y[1], a[1], b[1]);
   or(y[2], a[2], b[2]);
   or(y[3], a[3], b[3]);
   or(y[4], a[4], b[4]);
   or(y[5], a[5], b[5]);
   or(y[6], a[6], b[6]);
   or(y[7], a[7], b[7]);
   or(y[8], a[8], b[8]);
   or(y[9], a[9], b[9]);
   or(y[10], a[10], b[10]);
   or(y[11], a[11], b[11]);
   or(y[12], a[12], b[12]);
   or(y[13], a[13], b[13]);
   or(y[14], a[14], b[14]);
   or(y[15], a[15], b[15]);
endmodule