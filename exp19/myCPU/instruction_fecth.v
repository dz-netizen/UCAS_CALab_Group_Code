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

	input wire    [1:0] csr_plv_for_mmu,
	input wire    csr_dmw0_plv0_for_mmu,
	input wire    csr_dmw0_plv3_for_mmu,
	input wire    [2:0] csr_dmw0_pseg_for_mmu,
	input wire    [2:0] csr_dmw0_vseg_for_mmu,
	input wire    csr_dmw1_plv0_for_mmu,
	input wire    csr_dmw1_plv3_for_mmu,
	input wire    [2:0] csr_dmw1_pseg_for_mmu,
	input wire    [2:0] csr_dmw1_vseg_for_mmu,
	input wire    csr_direct_addr_for_mmu,

	
	//to decode
	output wire		fetch_to_dec_valid,
	output wire [`FETCH_TO_DEC_BUS_WD-1:0] fetch_to_decode_bus,
	output wire    ADEF_to_ID,
	output wire    TLBREFILL_to_ID,
	output wire    IFTLBINVALID_to_ID,
	output wire    IFTLBPOWER_to_ID,
	output wire     EXC_IF_to_ID,

   //to tlb
    output wire  [18:0]  s0_vppn_to_tlb,
	output wire          s0_va_bit12_to_tlb,

   //from tlb
	input wire           s0_found,
	input wire  [19:0]   s0_ppn,
	input wire  [5:0]    s0_ps,
	input wire  [1:0]    s0_plv,
	input wire  [1:0]    s0_mat,
	input wire          s0_d,
	input wire          s0_v,
	input wire [3:0]     s0_index,

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
wire        [31:0]  next_pc_phy;
wire        dmw0_hit;
wire        dmw1_hit;
wire    [31:0]	dmw0_phy_addr;
wire    [31:0]	dmw1_phy_addr;
wire    [31:0]  tlb_phy_addr;
wire       tlbrefill;
reg        tlbrefill_reg;
wire       tlbinvalid;
reg        tlbinvalid_reg;
wire       tlbpower;
reg        tlbpower_reg;

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
		tlbrefill_reg <= 1'b0;
		tlbinvalid_reg <= 1'b0;
		tlbpower_reg <= 1'b0;
	end
	else if(pre_fetch_valid&fetch_allowin)begin
		fetch_pc<=next_pc_after_csr;
		tlbrefill_reg <= tlbrefill;
		tlbinvalid_reg <= tlbinvalid;
		tlbpower_reg <= tlbpower;
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
assign inst_sram_addr	={next_pc_phy[31:2],2'b0};
assign inst_sram_wdata	=32'h0;
assign inst_sram_size   = 2'b10;
assign inst_sram_wr     = 1'b0;
assign fetch_inst	= (extra_ID_control) ? extra_inst_ID:
                        inst_sram_rdata;
assign ADEF_to_ID = !(fetch_pc[1:0] == 2'b00)&& fetch_valid;//not in the pre-if, but in the if
assign TLBREFILL_to_ID = tlbrefill_reg && fetch_valid;
assign IFTLBINVALID_to_ID = tlbinvalid_reg && fetch_valid;
assign IFTLBPOWER_to_ID = tlbpower_reg && fetch_valid;
assign EXC_IF_to_ID = ADEF_to_ID | TLBREFILL_to_ID | IFTLBINVALID_to_ID | IFTLBPOWER_to_ID;
assign s0_vppn_to_tlb = next_pc_after_csr[31:13];
assign s0_va_bit12_to_tlb = next_pc_after_csr[12];
assign dmw0_hit = ((next_pc_after_csr[31:29] == csr_dmw0_vseg_for_mmu) &&
				   ((csr_plv_for_mmu == 2'b00 && csr_dmw0_plv0_for_mmu) ||
					(csr_plv_for_mmu == 2'b11 && csr_dmw0_plv3_for_mmu)) );
assign dmw1_hit = ((next_pc_after_csr[31:29] == csr_dmw1_vseg_for_mmu) &&
				   ((csr_plv_for_mmu == 2'b00 && csr_dmw1_plv0_for_mmu) ||
					(csr_plv_for_mmu == 2'b11 && csr_dmw1_plv3_for_mmu)) );
assign	dmw0_phy_addr = {csr_dmw0_pseg_for_mmu, next_pc_after_csr[28:0]};
assign	dmw1_phy_addr = {csr_dmw1_pseg_for_mmu, next_pc_after_csr[28:0]};
assign	tlb_phy_addr = (s0_ps == 6'd22) ? {s0_ppn[19:10], next_pc_after_csr[21:0]} :
						{ s0_ppn, next_pc_after_csr[11:0]};
assign next_pc_phy = csr_direct_addr_for_mmu ? next_pc_after_csr :
					 dmw0_hit ? dmw0_phy_addr :
					 dmw1_hit ? dmw1_phy_addr :
					  s0_found ? tlb_phy_addr  :
					   next_pc_after_csr;

assign	tlbrefill = !s0_found && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu;
assign  tlbinvalid = (s0_found && !s0_v) && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu;
assign  tlbpower = (s0_found &&s0_v && (csr_plv_for_mmu > s0_plv)) && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu;





endmodule
