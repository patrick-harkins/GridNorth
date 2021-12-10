// core_tb.sv

 `timescale 1ns/1ns

module core_tb;

	reg clk, rst, start, crossbar_wen, in_ex_wen, spike_in_wen;
	reg [3:0] crossbar_waddr;
	reg [15:0] spike_in_din, in_ex_din;
	reg [21:0] crossbar_din;
	
	wire ready;
	wire [15:0] spike_buffer;
	
	integer fizz = 0;
	integer buzz = 0;
	integer fizzbuzz = 0;
	integer tick = 0;
	
	core DUT(
		.clk(clk),
		.rst(rst),
		.start(start),
		.crossbar_wen(crossbar_wen),
		.crossbar_waddr(crossbar_waddr),
		.in_ex_wen(in_ex_wen),
		.spike_in_wen(spike_in_wen),
		.spike_in_din(spike_in_din),
		.in_ex_din(in_ex_din),
		.crossbar_din(crossbar_din),
		.ready(ready),
		.spike_buffer(spike_buffer)
	);

	initial begin
		clk = 1'b0;
		forever #1 clk = ~clk;
	end

	
	initial begin
		rst = 1'b1;
		spike_in_wen = 1'b0;
		spike_in_din = 16'h0;
		in_ex_din = 16'h0;
		in_ex_wen = 1'b0;
		crossbar_din = 22'h0;
		crossbar_wen = 1'b0;
		crossbar_waddr = 4'b0;
		start = 1'b0;
		#20;
		
		rst = 1'b0;
		crossbar_wen = 1'b1;
		in_ex_wen = 1'b1;
		
		in_ex_din = 16'h0003;
		
		//Neuron 0
		crossbar_waddr = 4'b0000;
		crossbar_din = 22'h35; 
		#20;
		
		in_ex_wen = 1'b0;
		
		//Neuron 1
		crossbar_waddr = 4'b0001;
		crossbar_din = 22'h2d; 
		#20;
		
		//Neuron 2
		crossbar_waddr = 4'b0010;
		crossbar_din = 22'h35; 
		#20;
		
		//Neuron 3
		crossbar_waddr = 4'b0011;
		crossbar_din = 22'h2d; 
		#20;
		
		//Neuron 4
		crossbar_waddr = 4'b0100;
		crossbar_din = 22'h027c;
		#20;
		
		//Neuron 5
		crossbar_waddr = 4'b0101;
		crossbar_din = 22'h0ff;
		#20;
		
		//Neuron 6
		crossbar_waddr = 4'b0110;
		crossbar_din = 22'h01bc;
		#20;
		
		//Neuron 7
		crossbar_waddr = 4'b0111;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 8
		crossbar_waddr = 4'b1000;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 9
		crossbar_waddr = 4'b1001;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 10
		crossbar_waddr = 4'b1010;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 11
		crossbar_waddr = 4'b1011;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 12
		crossbar_waddr = 4'b1100;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 13
		crossbar_waddr = 4'b1101;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 14
		crossbar_waddr = 4'b1110;
		crossbar_din = 22'h04;
		#20;
		
		//Neuron 15
		crossbar_waddr = 4'b1111;
		crossbar_din = 22'h04;
		#20;
		
		crossbar_wen = 1'b0;
		
		forever begin
			start = 1'b1;
			#100;
			start = 1'b0;
		
			wait(ready);
			tick = tick + 1;
			if (tick == 1000) begin
			   $display("fizz: %d, fizzbuzz: %d, buzz: %d", fizz, fizzbuzz, buzz);
			   $stop;
			end
		end
	end
	
	always @(posedge spike_buffer[4]) fizz = fizz + 1;
	always @(posedge spike_buffer[5]) fizzbuzz = fizzbuzz + 1;
	always @(posedge spike_buffer[6]) buzz = buzz + 1;
	
	
endmodule