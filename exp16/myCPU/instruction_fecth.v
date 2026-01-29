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
	output	wire	    inst_sram_req,
	output  wire 		inst_sram_wr,
	output  wire [1:0]  inst_sram_size,
	output	wire [3:0]	inst_sram_wstrb,
	output	wire [31:0]	inst_sram_addr,
	output	wire [31:0]	inst_sram_wdata,
    input   wire        inst_sram_addr_ok,
	input   wire        inst_sram_data_ok,
	input	wire [31:0]	inst_sram_rdata,
    input   wire [ 3:0]  arid
	
);

reg 		fetch_valid	;
wire 		fetch_allowin	;
wire 		fetch_ready_go	;
wire		pre_fetch_valid;
wire		pre_fetch_ready_go;

wire	[31:0]	fetch_inst;
reg	[31:0]	fetch_pc;
reg [31:0]  extra_pc_br;
reg         exrta_br_control; //for branch 
reg         extra_cancel_br;//cancel because it can not be passed by one clock;
reg [31:0]  extra_inst_ID;//for ready_go == 1 but dec_allowin == 0
reg         extra_ID_control;     
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
assign	pre_fetch_ready_go	= inst_sram_req && inst_sram_addr_ok;
assign	pre_fetch_valid	=~reset & pre_fetch_ready_go & ~(csr_is_branch|branch_taken);
assign	seq_pc			= fetch_pc+3'h4;
assign	next_pc			= branch_taken?	branch_target:seq_pc;
assign  next_pc_after_csr = (csr_is_branch) ? csr_pc_if : 
                            (exrta_br_control) ?extra_pc_br :
							 next_pc;
							 						    

//IF stage
assign	fetch_ready_go		= inst_sram_data_ok;
assign	fetch_allowin		=~fetch_valid|((fetch_ready_go|extra_ID_control)&dec_allowin);
assign	fetch_to_dec_valid	= fetch_valid & (fetch_ready_go|extra_ID_control)&&(~extra_cancel_br);

always@(posedge clk)begin
	if(reset)begin
		extra_ID_control <= 1'b0;
		extra_inst_ID <= 32'h00000000;
	end
	else if(fetch_ready_go && ~dec_allowin && fetch_valid)begin
       extra_ID_control <= 1'b1;
	   extra_inst_ID    <= inst_sram_rdata;
	end
	else if(dec_allowin)begin
		extra_ID_control <= 1'b0;
		extra_inst_ID <= 32'h00000000;
	end

end
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
end//valid

always @(posedge clk)begin
	if(reset) begin
		fetch_pc<=32'h1bfffffc;
	end
	else if(pre_fetch_valid&fetch_allowin)begin
		fetch_pc<=next_pc_after_csr;
	end
end

always@(posedge clk)begin
	if(reset) begin
		extra_pc_br <= 32'h00000000;
		exrta_br_control <= 1'b0;    
	end                                 
	else if((~pre_fetch_valid) && (branch_taken || csr_is_branch) )begin
		extra_pc_br <= next_pc_after_csr;
		exrta_br_control <= 1'b1;
	end
	else if((exrta_br_control == 1'b1)&&pre_fetch_valid)begin
		extra_pc_br <= 32'h00000000;
		exrta_br_control <= 1'b0;
	end
end

always@(posedge clk)begin
	if(reset)
	extra_cancel_br <= 1'b0;
	else if((~fetch_allowin)&& (branch_taken || csr_is_branch))begin
	extra_cancel_br <= 1'b1;
	end
	else if(fetch_allowin)begin
	extra_cancel_br <= 1'b0;
	end
end
   
assign inst_sram_req	= fetch_allowin ;
assign inst_sram_wstrb	=4'h0;
assign inst_sram_addr	={next_pc_after_csr[31:2],2'b0};
assign inst_sram_wdata	=32'h0;
assign inst_sram_size   = 2'b10;
assign inst_sram_wr     = 1'b0;
assign fetch_inst	= (extra_ID_control) ? extra_inst_ID:
                        inst_sram_rdata;
assign ADEF_to_ID = !(fetch_pc[1:0] == 2'b00)&& fetch_valid;//not in the pre-if, but in the if

endmodule
