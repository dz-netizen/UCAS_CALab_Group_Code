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
	output	wire	    inst_sram_req	,
	output  wire        inst_sram_wr   ,
	output	wire [3:0]	inst_sram_wstrb,
	output	wire [31:0]	inst_sram_addr,
	output	wire [31:0]	inst_sram_wdata,
	output  wire [1:0]  inst_sram_size,
    input   wire        inst_sram_addr_ok,
    input   wire        inst_sram_data_ok,	
	input	wire [31:0]	inst_sram_rdata


	
);

// pre IF
wire		pre_fetch_valid;
wire		pre_fetch_ready_go;
reg         pre_fetch_wait;
reg  [31:0] pre_fetch_inst_reg;
// IF
reg 		     fetch_valid	;
wire 		     fetch_allowin	;
wire 		     fetch_ready_go	;
reg     [31:0]   fetch_inst_buf;
reg              inst_buf_valid;
wire	[31:0]	 fetch_inst;
reg	    [31:0]	 fetch_pc;
wire	[31:0]	 seq_pc;
wire	[31:0]	 next_pc;

//final next_pc
wire    [31:0]       next_pc_after_csr;
// branch
wire		branch_taken;
wire	[31:0]	branch_target;
wire        br_stall;

assign	{   br_stall,
            branch_taken,
            branch_target}=branch_bus;

assign	fetch_to_decode_bus={
				fetch_inst,	//63:32
				fetch_pc	//31:0
			    };
// -------------------------exception cansel --------------------------------------
wire    IF_ex_cancel;
reg     inst_discard;
assign IF_ex_cancel = csr_is_branch|branch_taken;
    
always @(posedge clk) begin
     if(reset)
         inst_discard <= 1'b0;
     else if(IF_ex_cancel & ~ fetch_allowin & ~fetch_ready_go )
         inst_discard <= 1'b1;
     else if(inst_discard & inst_sram_data_ok)
        inst_discard <= 1'b0;
end

// ------------------------- pre-IF stage --------------------------------
assign	pre_fetch_ready_go	= inst_sram_req & inst_sram_addr_ok;
assign	pre_fetch_valid	=~reset & pre_fetch_ready_go;
assign	seq_pc			=fetch_pc+3'h4;
assign	next_pc			=branch_taken?	branch_target:seq_pc;
assign  next_pc_after_csr =(pre_fetch_wait)?    pre_fetch_inst_reg:
                           (csr_is_branch) ? csr_pc_if : next_pc;
always @(posedge clk)begin
    if(reset)begin
        pre_fetch_wait<=1'b0;
        pre_fetch_inst_reg<=32'h1bfffffc;
    end
    else if(~pre_fetch_ready_go & branch_taken)begin
        pre_fetch_wait<=1'b1;
        pre_fetch_inst_reg<=next_pc_after_csr;
    end
    else if(pre_fetch_ready_go)begin
        pre_fetch_wait<=1'b0;
    end
end
//---------------------------- IF stage -----------------------------------

assign	fetch_ready_go		=(inst_sram_data_ok | inst_buf_valid )& ~inst_discard;
assign	fetch_allowin		= ~fetch_valid | fetch_ready_go & dec_allowin;
assign	fetch_to_dec_valid	= fetch_valid & fetch_ready_go;

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
	else if (fetch_ready_go & dec_allowin)begin
	    fetch_valid = 1'b0;
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

//  buffer
    always @(posedge clk) begin
        if(reset) begin
            fetch_inst_buf <= 32'b0;
            inst_buf_valid <= 1'b0;
        end
        else if(fetch_to_dec_valid & dec_allowin)   
            inst_buf_valid <= 1'b0;
        else if(IF_ex_cancel & fetch_ready_go)                  
            inst_buf_valid <= 1'b0;
        else if(fetch_ready_go & ~dec_allowin & ~inst_discard) begin
            fetch_inst_buf <= fetch_inst;
            inst_buf_valid <= 1'b1;
        end
    end 
    
//  ---------------------------- inst sram ----------------------------------
assign inst_sram_req	=fetch_allowin & ~csr_is_branch & ~br_stall;
assign inst_sram_wstrb	=4'h0;
assign inst_sram_addr	={next_pc_after_csr[31:2],2'h0};
assign inst_sram_wdata	=32'h0;
assign inst_sram_wr = | inst_sram_wstrb;
assign inst_sram_size = 2'b10;
assign fetch_inst	=inst_sram_rdata;
assign ADEF_to_ID = !(fetch_pc[1:0] == 2'b00)&& fetch_valid;//not in the pre-if, but in the if

endmodule
