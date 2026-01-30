`include "mycpu.h"
module exe (
	input wire	clk,
	input wire	reset,
	input wire  [63:0] stable_counter,
	
	//from decode
	input wire	dec_to_exe_valid,
	input wire	[`DEC_TO_EXE_BUS_WD-1:0]	decode_to_exe_bus,
	input wire  csr_rd_we_to_exe,
	input wire  [13:0] csr_num_to_exe,
	input wire  [4:0]  csr_rd_to_exe,
	input wire  csr_csr_we_to_exe,
	input wire [31:0] csr_csr_wvalue_to_exe,
	input wire [31:0] csr_csr_wmask_to_exe,
	input wire csr_ertn_flush_to_exe,
	input wire csr_wb_ex_to_exe,
	input wire [5:0] csr_wb_ecode_to_exe,
	input wire [8:0] csr_wb_subecode_to_exe,
	input wire ALE_h_to_exe,
	input wire ALE_w_to_exe,
	input wire [1:0] rdcntv_to_exe,//01 l,10 h,
	input wire tlb_refecth_to_exe,
	input wire tlb_invtlb_to_exe,
	input wire tlb_tlbwr_to_exe,
	input wire tlb_tlbrd_to_exe,
	input wire tlb_tlbsrch_to_exe,
	input wire tlb_tlbfill_to_exe,
	input wire [4:0] tlb_invtlb_op_to_exe,
	input wire [31:0] tlb_invtlb_rj_value_to_exe,
	input wire [31:0] tlb_invtlb_rk_value_to_exe,
	// CACOP
	input wire  cacop_to_exe,
	input wire  [4:0] cacop_code_to_exe,
	input wire EXC_IF_to_exe,

	
	//to decode 
	output wire	exe_allowin,
	//forward
	output wire gr_we_exe,
	output wire inst_ld_w_forward_exe,
	output wire [4:0]  dest_exe,	
	output wire [31:0] forward_data_exe,
	
	//from mem
	input wire	mem_allowin,
	input wire  csr_wb_ex_to_wb,
	input wire  csr_ertn_flush_to_wb,
	input wire  tlb_refecth_to_wb,

	//from wb
	input wire csr_wb_ex_wb,
	input wire csr_ertn_flush_wb,
	input wire tlb_refecth_wb,

	//from csr
	input wire [18:0] tlb_vppn_csr_to_exe,
	input wire        tlb_va_bit12_csr_to_exe,
	input wire [9:0]  tlb_asid_csr_to_exe,
	input wire [1:0]   csr_plv_for_mmu,
	input wire [1:0]   csr_crmd_datm_for_mmu,
	input wire [1:0]   csr_dmw0_mat_for_mmu,
	input wire [1:0]   csr_dmw1_mat_for_mmu,
	input wire		csr_direct_addr_for_mmu,
	input wire    [2:0] csr_dmw0_pseg_for_mmu,
	input wire    [2:0] csr_dmw0_vseg_for_mmu,
	input wire    csr_dmw0_plv0_for_mmu,
	input wire    csr_dmw0_plv3_for_mmu,
	input wire    [2:0] csr_dmw1_pseg_for_mmu,
	input wire    [2:0] csr_dmw1_vseg_for_mmu,
	input wire    csr_dmw1_plv0_for_mmu,
	input wire    csr_dmw1_plv3_for_mmu,
	
	//to mem
	output wire	exe_to_mem_valid,
	output wire	[`EXE_TO_MEM_BUS_WD-1:0]exe_to_mem_bus,
	output wire csr_rd_we_to_mem,
	output wire [13:0] csr_num_to_mem,
	output wire [4:0]  csr_rd_to_mem,
	output wire csr_csr_we_to_mem,
	output wire [31:0] csr_csr_wvalue_to_mem,
	output wire [31:0] csr_csr_wmask_to_mem,
	output wire csr_ertn_flush_to_mem,
	output wire csr_wb_ex_to_mem,
	output wire [5:0] csr_wb_ecode_to_mem,
	output wire [8:0] csr_wb_subecode_to_mem,
	output wire [31:0] csr_BADV_to_mem,
	output wire         mem_we_to_mem,
	output wire         tlb_refecth_to_mem,
	//to tlb too
	output wire         tlb_invtlb_to_mem,
	//
	output wire         tlb_tlbwr_to_mem,
	output wire         tlb_tlbrd_to_mem,
	output wire         tlb_tlbsrch_to_mem,
	output wire         tlb_tlbfill_to_mem,
	output wire         EXC_IF_to_mem,
	//to tlb
	output wire   [18:0]    tlb_vppn_exe_to_tlb,
	output wire       		tlb_va_bit12_exe_to_tlb,
	output wire   [9:0]     tlb_asid_exe_to_tlb,
	output wire   [4:0]     tlb_invtlb_op_exe_to_tlb,

	//from tlb
	input wire   s1_found,
	input wire  [19:0]   s1_ppn,
	input wire  [5:0]    s1_ps,
	input wire  [1:0]    s1_plv,
	input wire  [1:0]    s1_mat,
	input wire          s1_d,
	input wire          s1_v,
	input wire [3:0]     s1_index,
	
	//data sram interface
	output wire	data_sram_req,
	output wire data_sram_wr,
	output wire [1:0] data_sram_size,
	output wire [3:0] data_sram_wstrb,
	output wire	[31:0]	data_sram_addr,
	output wire	[31:0]	data_sram_wdata,
	input  wire         data_sram_addr_ok,
	// 1: uncached access
	output wire         data_sram_uncache,

	//virtual address
	output wire	[31:0] data_sram_vaddr
	,
	// ===== CACOP to caches =====
	output wire         icache_cacop_valid,
	output wire [4:0]   icache_cacop_op,
	output wire [7:0]   icache_cacop_index,
	output wire [19:0]  icache_cacop_tag,
	input  wire         icache_cacop_addr_ok,
	input  wire         icache_cacop_data_ok,
	output wire         dcache_cacop_valid,
	output wire [4:0]   dcache_cacop_op,
	output wire [7:0]   dcache_cacop_index,
	output wire [19:0]  dcache_cacop_tag,
	input  wire         dcache_cacop_addr_ok,
	input  wire         dcache_cacop_data_ok
);
wire [4:0]  dest_exe_final;
wire gr_we_exe_final;
reg	    exe_valid;
wire	exe_ready_go;

wire ALE;
reg    ALE_h_to_exe_reg;
reg    ALE_w_to_exe_reg;
reg    csr_rd_we_to_exe_reg;
reg    [13:0] csr_num_to_exe_reg;
reg    [4:0]  csr_rd_to_exe_reg;
reg    csr_csr_we_to_exe_reg;
reg    [31:0] csr_csr_wvalue_to_exe_reg;
reg    [31:0] csr_csr_wmask_to_exe_reg;
reg    csr_ertn_flush_to_exe_reg;
reg    csr_wb_ex_to_exe_reg;
reg    [5:0] csr_wb_ecode_to_exe_reg;
reg    [8:0] csr_wb_subecode_to_exe_reg;
reg    [1:0] rdcntv_to_exe_reg;
reg          mem_we_reg;
reg		  tlb_refecth_to_exe_reg;
reg	   tlb_invtlb_to_exe_reg;
reg	   tlb_tlbwr_to_exe_reg;
reg	   tlb_tlbrd_to_exe_reg;
reg	   tlb_tlbsrch_to_exe_reg;
reg	   tlb_tlbfill_to_exe_reg;
reg   [4:0]    tlb_invtlb_op_to_exe_reg;
reg   [31:0]   tlb_invtlb_rj_value_to_exe_reg;
reg   [31:0]   tlb_invtlb_rk_value_to_exe_reg;
reg     EXC_IF_to_exe_reg;

reg          cacop_to_exe_reg;
reg   [4:0]  cacop_code_to_exe_reg;
reg          cacop_sent;

reg	[`DEC_TO_EXE_BUS_WD-1:0]	exe_bus_reg;
wire	inst_lu12i_w;	
wire	inst_st_w;	
wire	[18:0] alu_op;	
wire	load_op;	
wire	src1_is_pc;
wire	src2_is_imm;	
wire	src2_is_4;	
wire	gr_we;		
wire	mem_we;		
wire	[4:0] dest;		
wire	[31:0] imm;		
wire	[31:0] rj_value;	
wire	[31:0] rkd_value;	
wire	[31:0] exe_pc;	

wire    signed_option;
wire    inst_ld_b;
wire    inst_ld_bu;
wire    inst_ld_h;
wire    inst_ld_hu;
wire    inst_ld_w;
wire    inst_st_b;
wire    inst_st_h;
wire  [3:0] data_sram_we_before_csr;
wire   dmw0_hit;
wire   dmw1_hit;
wire   [31:0] dmw0_phy_addr;
wire   [31:0] dmw1_phy_addr;
wire   [31:0] tlb_phy_addr;
wire   [31:0] alu_result_phy;
wire   store_invalid;
wire   load_invalid;
wire   tlbrefill;
wire   tlbpower;
wire   tlbchange;

wire   inst_cacop;
assign inst_cacop = cacop_to_exe_reg;


assign {
    inst_st_b,      //167
    inst_st_h,      //166
    inst_ld_b,      //165
    inst_ld_bu,     //164
    inst_ld_h,      //163
    inst_ld_hu,     //162
    inst_ld_w,      //161
    signed_option,  //160
	inst_lu12i_w,	//159
	inst_st_w,	//158
	alu_op,		//157:139
	load_op,	//138
	src1_is_pc,	//137
	src2_is_imm,	//136
	src2_is_4,	//135
	gr_we,		//134
	mem_we,		//133
	dest,		//132:128
	imm,		//127:96
	rj_value,	//95:64
	rkd_value,	//63:32
	exe_pc	//31:0
	}=exe_bus_reg;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] alu_result_after_rdc;




assign alu_src1 = src1_is_pc  ? exe_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;


wire dout_tvalid;

alu u_alu(
    .clk(clk),
    .reset(reset),
	.exe_valid (exe_valid),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result),
    .dout_tvalid (dout_tvalid)
    );


assign	exe_to_mem_bus={
    inst_ld_b,      //77
    inst_ld_bu,     //76
    inst_ld_h,      //75
    inst_ld_hu,     //74
    inst_ld_w,      //73
    signed_option,  //72
	inst_lu12i_w,	//71
	load_op,	//70
	gr_we,		//69
	dest,		//68:64
	alu_result_after_rdc,	//63:32
	exe_pc		//31:0
};

assign data_sram_size = (inst_ld_w || inst_st_w) ? 2'b10 :
                        (inst_ld_h || inst_ld_hu || inst_st_h) ? 2'b01 :
						(inst_ld_b || inst_ld_bu || inst_st_b) ? 2'b00 :
						2'b00;

wire exe_mem_cancel;
assign exe_mem_cancel = csr_wb_ex_to_mem | csr_ertn_flush_to_mem;

wire        exe_is_cacop;
wire        exe_is_cacop_hit;
wire        exe_is_cacop_wb;
wire        exe_is_cacop_load;
wire        exe_is_cacop_store;
wire        cacop_sel_icache;
wire        cacop_sel_dcache;
wire        cacop_done;
wire        cacop_addr_ok_sel;
wire        cacop_data_ok_sel;

assign exe_is_cacop     = inst_cacop && exe_valid;
// LoongArch CACOP: hit ops (op[4:3]=2'b10/2'b11) require address translation and may raise TLB exceptions.
// For hit wb+inv (op[4:3]=2'b11) treat as store-like; otherwise treat as load-like.
assign exe_is_cacop_hit   = exe_is_cacop && (cacop_code_to_exe_reg[4:3] == 2'b10 || cacop_code_to_exe_reg[4:3] == 2'b11);
assign exe_is_cacop_wb    = exe_is_cacop && (cacop_code_to_exe_reg[4:3] == 2'b01 || cacop_code_to_exe_reg[4:3] == 2'b10);
// For address translation exceptions, CACOP hit ops are treated as load-like (PIL/PIF),
// even if the operation may trigger internal writeback.
assign exe_is_cacop_load  = exe_is_cacop_hit;
assign exe_is_cacop_store = exe_is_cacop_hit && exe_is_cacop_wb;
assign cacop_sel_icache = (cacop_code_to_exe_reg[2:0] == 3'b000);
assign cacop_sel_dcache = (cacop_code_to_exe_reg[2:0] == 3'b001);

assign cacop_addr_ok_sel = cacop_sel_icache ? icache_cacop_addr_ok :
						   cacop_sel_dcache ? dcache_cacop_addr_ok :
						   1'b1;
assign cacop_data_ok_sel = cacop_sel_icache ? icache_cacop_data_ok :
						   cacop_sel_dcache ? dcache_cacop_data_ok :
						   1'b1;

assign cacop_done = (cacop_sel_icache || cacop_sel_dcache) ? (cacop_sent && cacop_data_ok_sel) : 1'b1;

assign data_sram_req = ((mem_we || load_op) && exe_valid) && mem_allowin && !exe_mem_cancel;


assign data_sram_wr	= (mem_we & exe_valid) ? (!exe_mem_cancel) : 1'b0;
assign data_sram_we_before_csr    = {4{mem_we & exe_valid}}&{
                            (
                            {4{inst_st_b}}&{
                            alu_result[1]&alu_result[0],
                            alu_result[1]&!alu_result[0],
                            !alu_result[1]&alu_result[0],
                            !alu_result[1]&!alu_result[0]}
                            )|
                            (
                            {4{inst_st_h}}&{{2{alu_result[1]}},{2{!alu_result[1]}}}
                            )|
                            {4{inst_st_w}}
                        };
assign data_sram_wstrb = (csr_wb_ex_to_wb | csr_wb_ex_wb | csr_ertn_flush_to_wb | csr_ertn_flush_wb |csr_wb_ex_to_mem |tlb_refecth_to_mem | tlb_refecth_to_wb | tlb_refecth_wb ) ? 4'b0 : data_sram_we_before_csr;//find ex,stop store
assign data_sram_addr  = alu_result_phy;
assign data_sram_wdata = inst_st_b? {4{rkd_value[7:0]}}:
                         inst_st_h? {2{rkd_value[15:0]}}:
                         rkd_value[31:0];

assign	exe_ready_go= ((mem_we || load_op) && exe_valid) ? ((exe_mem_cancel ? 1'b1 : (data_sram_req && data_sram_addr_ok)) & (dout_tvalid)) :
								 (exe_is_cacop)                    ? (((exe_mem_cancel ? 1'b1 : cacop_done)) & (dout_tvalid)) :
								                                   (1'b1 & (dout_tvalid));
assign	exe_allowin=!exe_valid|(exe_ready_go&mem_allowin);
assign	exe_to_mem_valid=exe_valid&exe_ready_go;

always@(posedge clk)begin
	if(reset)begin
		exe_valid <=1'b0;
	end
	else if(csr_wb_ex_wb | csr_ertn_flush_wb | tlb_refecth_wb)begin
		exe_valid <= 1'b0;
	end
	else if(exe_allowin)begin
		exe_valid <=dec_to_exe_valid;
	end
end
always@(posedge clk)begin
    if(reset)begin
       exe_bus_reg <= 168'b0;
    end
	else if(dec_to_exe_valid&exe_allowin)begin
		exe_bus_reg <= decode_to_exe_bus;

	end
end
always @(posedge clk) begin
	if(reset)begin
		csr_rd_to_exe_reg <= 5'b0;
		csr_num_to_exe_reg <= 14'b0;
		csr_rd_we_to_exe_reg <= 1'b0;
		csr_csr_we_to_exe_reg <= 1'b0;
		csr_csr_wvalue_to_exe_reg <= 32'b0;
		csr_csr_wmask_to_exe_reg <= 32'b0;
		csr_ertn_flush_to_exe_reg <= 1'b0;
		csr_wb_ex_to_exe_reg <= 1'b0;
		csr_wb_ecode_to_exe_reg  <= 6'b0;
		mem_we_reg <= 1'b0;
		csr_wb_subecode_to_exe_reg <= 9'b0;
		ALE_h_to_exe_reg <= 1'b0;
		ALE_w_to_exe_reg <= 1'b0;
		rdcntv_to_exe_reg <= 2'b0;
		tlb_refecth_to_exe_reg <= 1'b0;
		tlb_invtlb_to_exe_reg <= 1'b0;
		tlb_tlbwr_to_exe_reg <= 1'b0;
		tlb_tlbrd_to_exe_reg <= 1'b0;
		tlb_tlbsrch_to_exe_reg <= 1'b0;
		tlb_tlbfill_to_exe_reg <= 1'b0;
		tlb_invtlb_op_to_exe_reg <= 5'b0;
		tlb_invtlb_rj_value_to_exe_reg <= 32'b0;
		tlb_invtlb_rk_value_to_exe_reg <= 32'b0;
		EXC_IF_to_exe_reg <= 1'b0;
		cacop_to_exe_reg <= 1'b0;
		cacop_code_to_exe_reg <= 5'b0;
	end
	else if(dec_to_exe_valid && exe_allowin)begin
		csr_rd_to_exe_reg <= csr_rd_to_exe;
		csr_num_to_exe_reg <= csr_num_to_exe;
		csr_rd_we_to_exe_reg <= csr_rd_we_to_exe;
		csr_csr_we_to_exe_reg <= csr_csr_we_to_exe;
		csr_csr_wvalue_to_exe_reg <= csr_csr_wvalue_to_exe;
		csr_csr_wmask_to_exe_reg <= csr_csr_wmask_to_exe;
		csr_ertn_flush_to_exe_reg <= csr_ertn_flush_to_exe;
		csr_wb_ex_to_exe_reg <= csr_wb_ex_to_exe;
		csr_wb_ecode_to_exe_reg <= csr_wb_ecode_to_exe;
		csr_wb_subecode_to_exe_reg <= csr_wb_subecode_to_exe;
		ALE_h_to_exe_reg <= ALE_h_to_exe;
		ALE_w_to_exe_reg <= ALE_w_to_exe;
		rdcntv_to_exe_reg <= rdcntv_to_exe;
		mem_we_reg <= mem_we;
		tlb_refecth_to_exe_reg <= tlb_refecth_to_exe;
		tlb_invtlb_to_exe_reg <= tlb_invtlb_to_exe;
		tlb_tlbwr_to_exe_reg <= tlb_tlbwr_to_exe;
		tlb_tlbrd_to_exe_reg <= tlb_tlbrd_to_exe;
		tlb_tlbsrch_to_exe_reg <= tlb_tlbsrch_to_exe;
		tlb_tlbfill_to_exe_reg <= tlb_tlbfill_to_exe;
		tlb_invtlb_op_to_exe_reg <= tlb_invtlb_op_to_exe;
		tlb_invtlb_rj_value_to_exe_reg <= tlb_invtlb_rj_value_to_exe;
		tlb_invtlb_rk_value_to_exe_reg <= tlb_invtlb_rk_value_to_exe;
		EXC_IF_to_exe_reg <= EXC_IF_to_exe;
		cacop_to_exe_reg <= cacop_to_exe;
		cacop_code_to_exe_reg <= cacop_code_to_exe;
		
	end
	
end

// Track CACOP request acceptance so the request is issued exactly once.
always @(posedge clk) begin
	if (reset) begin
		cacop_sent <= 1'b0;
	end
	else if (csr_wb_ex_wb | csr_ertn_flush_wb | tlb_refecth_wb) begin
		cacop_sent <= 1'b0;
	end
	else if (dec_to_exe_valid && exe_allowin) begin
		// new instruction entering EXE
		cacop_sent <= 1'b0;
	end
	else if (exe_is_cacop && !exe_mem_cancel && !cacop_sent) begin
		// For unsupported cache objects, complete immediately.
		if (!(cacop_sel_icache || cacop_sel_dcache)) begin
			cacop_sent <= 1'b1;
		end
		else if (cacop_addr_ok_sel) begin
			cacop_sent <= 1'b1;
		end
	end
end

// hazard(read after write conflict)
assign gr_we_exe=(exe_valid)? gr_we:1'b0;
assign gr_we_exe_final = (csr_rd_we_to_exe_reg) ? (csr_rd_we_to_exe_reg && exe_valid) : gr_we_exe;//nothing
assign dest_exe=(exe_valid)? dest:5'b0;
assign dest_exe_final = (csr_rd_we_to_exe_reg && exe_valid) ? (csr_rd_to_exe_reg) : dest_exe;//nothing
//forward
assign forward_data_exe=(exe_valid)?alu_result_after_rdc:32'b0;
assign inst_ld_w_forward_exe=(exe_valid)? load_op:1'b0;

assign csr_rd_to_mem = csr_rd_to_exe_reg;
assign csr_rd_we_to_mem = (csr_rd_we_to_exe_reg) && exe_valid;
assign csr_num_to_mem = csr_num_to_exe_reg;
assign csr_csr_we_to_mem = (csr_csr_we_to_exe_reg) && exe_valid;
assign csr_csr_wvalue_to_mem = csr_csr_wvalue_to_exe_reg;
assign csr_csr_wmask_to_mem = csr_csr_wmask_to_exe_reg;
assign csr_ertn_flush_to_mem = (csr_ertn_flush_to_exe_reg) && exe_valid;
assign csr_wb_ex_to_mem = (csr_wb_ex_to_exe_reg | ALE | tlbrefill | store_invalid | load_invalid | tlbpower | tlbchange) && exe_valid;
assign csr_wb_ecode_to_mem = (csr_wb_ex_to_exe_reg) ? csr_wb_ecode_to_exe_reg : 
                              (ALE) ? 6'h9 :
							  (tlbrefill) ? 6'h3f:
							  (store_invalid) ? 6'h2:
							  (load_invalid) ? 6'h1:
							  (tlbpower) ? 6'h7:
							  (tlbchange) ? 6'h4 :
							6'h0;
assign csr_wb_subecode_to_mem = (csr_wb_ex_to_exe_reg) ? csr_wb_subecode_to_exe_reg :
                                (ALE) ? 9'h0:
								(tlbrefill) ? 9'h0:
								(store_invalid) ? 9'h0:
								(load_invalid) ? 9'h0:
								(tlbpower) ? 9'h0:
								(tlbchange) ? 9'h0 :
								9'h0;


assign ALE = ((ALE_h_to_exe_reg &&alu_result[0] != 1'b0) || (ALE_w_to_exe_reg && alu_result[1:0] != 2'b00)) && exe_valid;
assign csr_BADV_to_mem = alu_result;
assign alu_result_after_rdc = (rdcntv_to_exe_reg == 2'b01) ? stable_counter[31:0] :
                              (rdcntv_to_exe_reg == 2'b10) ? stable_counter[63:32] :
							  alu_result;
assign mem_we_to_mem = mem_we && exe_valid;
assign tlb_refecth_to_mem = tlb_refecth_to_exe_reg && exe_valid ;
assign tlb_invtlb_to_mem = tlb_invtlb_to_exe_reg && exe_valid&& !(csr_wb_ex_to_wb | csr_wb_ex_wb | csr_ertn_flush_to_wb | csr_ertn_flush_wb  | tlb_refecth_to_wb | tlb_refecth_wb | csr_wb_ex_to_mem);
assign tlb_tlbwr_to_mem = tlb_tlbwr_to_exe_reg && exe_valid;
assign tlb_tlbrd_to_mem = tlb_tlbrd_to_exe_reg && exe_valid;
assign tlb_tlbsrch_to_mem = tlb_tlbsrch_to_exe_reg && exe_valid && !(csr_wb_ex_to_wb | csr_wb_ex_wb | csr_ertn_flush_to_wb | csr_ertn_flush_wb  | tlb_refecth_to_wb | tlb_refecth_wb | csr_wb_ex_to_mem);
assign tlb_tlbfill_to_mem = tlb_tlbfill_to_exe_reg && exe_valid;
assign tlb_vppn_exe_to_tlb = (tlb_invtlb_to_exe_reg && exe_valid) ? tlb_invtlb_rk_value_to_exe_reg[31:13] :
							  (tlb_tlbsrch_to_exe_reg && exe_valid) ? tlb_vppn_csr_to_exe :
							  alu_result[31:13];
assign tlb_va_bit12_exe_to_tlb = (tlb_invtlb_to_exe_reg && exe_valid)? tlb_invtlb_rk_value_to_exe_reg[12] :
								(tlb_tlbsrch_to_exe_reg && exe_valid) ? tlb_va_bit12_csr_to_exe:
								alu_result[12];
assign tlb_asid_exe_to_tlb = (tlb_invtlb_to_exe_reg && exe_valid) ? tlb_invtlb_rj_value_to_exe_reg[9:0] :
							tlb_asid_csr_to_exe;
assign tlb_invtlb_op_exe_to_tlb = tlb_invtlb_op_to_exe_reg;
assign dmw0_hit = (alu_result[31:29] == csr_dmw0_vseg_for_mmu) &&
				   ( (csr_plv_for_mmu == 2'b00 && csr_dmw0_plv0_for_mmu) ||
					 (csr_plv_for_mmu == 2'b11 && csr_dmw0_plv3_for_mmu)) ;
assign	dmw0_phy_addr = {csr_dmw0_pseg_for_mmu, alu_result[28:0]};
assign dmw1_hit = (alu_result[31:29] == csr_dmw1_vseg_for_mmu) &&
				   ( (csr_plv_for_mmu == 2'b00 && csr_dmw1_plv0_for_mmu) ||
					 (csr_plv_for_mmu == 2'b11 && csr_dmw1_plv3_for_mmu)) ;
assign	dmw1_phy_addr = {csr_dmw1_pseg_for_mmu, alu_result[28:0]};
assign	tlb_phy_addr = (s1_ps == 6'd22) ? {s1_ppn[19:10], alu_result[21:0]} :
						{ s1_ppn, alu_result[11:0]};
assign	alu_result_phy = csr_direct_addr_for_mmu ? alu_result :
					 dmw0_hit ? dmw0_phy_addr :
					 dmw1_hit ? dmw1_phy_addr :
					 s1_found ?
					  tlb_phy_addr :
					  alu_result;

// DATM select for load/store (LoongArch): DA uses CRMD.DATM; DMW uses DMWx.MAT; PG uses TLB MAT.
wire [1:0] datm;
assign datm = csr_direct_addr_for_mmu ? csr_crmd_datm_for_mmu :
              dmw0_hit               ? csr_dmw0_mat_for_mmu  :
              dmw1_hit               ? csr_dmw1_mat_for_mmu  :
                                      s1_mat;
// Treat MAT==2'b01 as cacheable, otherwise uncached.
assign data_sram_uncache = (datm != 2'b01);
assign EXC_IF_to_mem = EXC_IF_to_exe_reg && exe_valid;
assign tlbrefill = (!s1_found) && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu && (load_op || mem_we || exe_is_cacop_hit) && exe_valid;
assign store_invalid = (s1_found)&&(s1_v == 1'b0) && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu && (mem_we) && exe_valid;
assign tlbpower = (s1_plv < csr_plv_for_mmu)&&(s1_v == 1'b1) && (s1_found == 1'b1) && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu && (load_op || mem_we || exe_is_cacop_hit) && exe_valid;
assign load_invalid = (s1_found)&&(s1_v == 1'b0) && !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu && (load_op || exe_is_cacop_load) && exe_valid;
assign tlbchange = (s1_found)&&(s1_d == 1'b0) &&(s1_v == 1'b1)&& !dmw0_hit && !dmw1_hit && !csr_direct_addr_for_mmu && (mem_we || exe_is_cacop_store) && exe_valid && !(s1_plv < csr_plv_for_mmu);

//-------------- virtual address ---------------------
assign data_sram_vaddr = alu_result;

//-------------- CACOP to caches ----------------------
assign icache_cacop_valid = exe_is_cacop && !exe_mem_cancel && !cacop_sent && cacop_sel_icache;
assign dcache_cacop_valid = exe_is_cacop && !exe_mem_cancel && !cacop_sent && cacop_sel_dcache;

assign icache_cacop_op    = cacop_code_to_exe_reg;
assign dcache_cacop_op    = cacop_code_to_exe_reg;

assign icache_cacop_index = alu_result[11:4];
assign dcache_cacop_index = alu_result[11:4];

assign icache_cacop_tag   = alu_result_phy[31:12];
assign dcache_cacop_tag   = alu_result_phy[31:12];


endmodule
