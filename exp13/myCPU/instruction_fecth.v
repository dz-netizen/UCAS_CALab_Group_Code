`include "mycpu.h"
module instruction_fetch(
	input wire		clk	,
	input wire		reset	,
	
	//from decode
	input wire		dec_allowin,
	
	input wire [`BR_BUS_WD-1:0]	branch_bus,

	//from csr_control
	input wire    csr_is_branch,
	input wire    [31:0] csr_pc_if,
	
	//to decode
	output wire		fetch_to_dec_valid,
	output wire [`FETCH_TO_DEC_BUS_WD-1:0] fetch_to_decode_bus,
	output wire    ADEF_to_ID,
	
	//instruction sram interface
	output	wire	    inst_sram_en	,
	output	wire [3:0]	inst_sram_we,
	output	wire [31:0]	inst_sram_addr,
	output	wire [31:0]	inst_sram_wdata,

	
	input	wire [31:0]	inst_sram_rdata

	
);

reg 		fetch_valid	;
wire 		fetch_allowin	;
wire 		fetch_ready_go	;
wire		pre_fetch_valid;
wire		pre_fetch_ready_go;

wire	[31:0]	fetch_inst;
reg	[31:0]	fetch_pc;
wire	[31:0]	seq_pc;
wire	[31:0]	next_pc;
//final next_pc
wire    [31:0]       next_pc_after_csr;

wire		branch_taken;
wire	[31:0]	branch_target;
assign	{branch_taken,branch_target}=branch_bus;

assign	fetch_to_decode_bus={
				fetch_inst,	//63:32
				fetch_pc	//31:0
			    };

//pre-IF stage
assign	pre_fetch_ready_go	=1'b1;
assign	pre_fetch_valid	=~reset&pre_fetch_ready_go;
assign	seq_pc			=fetch_pc+3'h4;
assign	next_pc			=branch_taken?	branch_target:seq_pc;
assign next_pc_after_csr = (csr_is_branch) ? csr_pc_if : next_pc;

//IF stage
assign	fetch_ready_go		=1'b1;
assign	fetch_allowin		=~fetch_valid|(fetch_ready_go&dec_allowin);
assign	fetch_to_dec_valid	=fetch_valid&fetch_ready_go;

always@(posedge clk)begin
	if(reset)begin
		fetch_valid	=1'b0;
	end
	/*else if(csr_is_branch)begin
		fetch_valid = 1'b0;
	end*/
	else if(fetch_allowin)begin
		fetch_valid	=pre_fetch_valid;
	end
	else if(branch_taken)begin
	   fetch_valid =1'b0;
	end//make block in the ID,so there's no need to block here
end//valid

always @(posedge clk)begin
	if(reset) begin
		fetch_pc<=32'h1bfffffc;
	end
	else if(csr_is_branch)begin
	 fetch_pc <= next_pc_after_csr;
    end
	else if(pre_fetch_valid&fetch_allowin)begin
		fetch_pc<=next_pc_after_csr;
	end
end

assign inst_sram_en	=pre_fetch_valid&(fetch_allowin | csr_is_branch);
assign inst_sram_we	=4'h0;
assign inst_sram_addr	={next_pc_after_csr[31:2],2'h0};
assign inst_sram_wdata	=32'h0;

assign fetch_inst	=inst_sram_rdata;
assign ADEF_to_ID = !(fetch_pc[1:0] == 2'b00)&& fetch_valid;//not in the pre-if, but in the if

endmodule
