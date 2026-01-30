`include "mycpu.h" 
module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
	output wire        inst_sram_wr,
	output wire [1:0]  inst_sram_size,
	output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
	input  wire 	   inst_sram_addr_ok,
	input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_req,
	output wire        data_sram_wr,
	output wire [1:0]  data_sram_size,
	output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
	input  wire        data_sram_addr_ok,
	input  wire        data_sram_data_ok,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

	//virtual address
	output  wire [31:0] inst_sram_vaddr,
	output  wire [31:0] data_sram_vaddr,
	// 1: uncached access for data load/store
	output  wire        data_sram_uncache,

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

reg         reset;
always @(posedge clk) reset <= ~resetn;
reg      [63:0]   stable_counter;
reg      [3:0]    data_sram_counter;
always@(posedge clk)begin
	if(reset)
	data_sram_counter <= 4'b0;
	else if(data_sram_req &&data_sram_addr_ok&& (~data_sram_data_ok))
	data_sram_counter <= data_sram_counter + 1'b1;
    else if(~data_sram_req & data_sram_addr_ok )
    data_sram_counter <= data_sram_counter + 1'b1;
	else if(data_sram_data_ok&&(~data_sram_req ||  ~data_sram_addr_ok))
	data_sram_counter <= data_sram_counter - 1'b1;
end
always@(posedge clk)begin
	if(reset)
	stable_counter <= 64'b0;
	else if(stable_counter != 64'hffffffffffffffff)
	stable_counter <= stable_counter + 1'b1;
	else if(stable_counter == 64'hffffffffffffffff)
    stable_counter <= 64'b0;
end

wire	dec_allowin;
wire	exe_allowin;
wire	mem_allowin;
wire	wb_allowin;

wire	fetch_to_dec_valid;
wire	dec_to_exe_valid;
wire	exe_to_mem_valid;
wire	mem_to_wb_valid;

wire	[`FETCH_TO_DEC_BUS_WD-1:0] fetch_to_decode_bus;
wire	[`DEC_TO_EXE_BUS_WD-1  :0] decode_to_exe_bus;
wire	[`EXE_TO_MEM_BUS_WD-1  :0] exe_to_mem_bus;
wire	[`MEM_TO_WB_BUS_WD-1   :0] mem_to_wb_bus;
wire	[`WB_TO_REGFILE_BUS_WD-1:0] wb_to_regfile_bus;
wire	[`BR_BUS_WD-1		:0] branch_bus;

//hazard (read after write)
wire    gr_we_exe;
wire    gr_we_mem;
wire    gr_we_wb;
wire    [4:0]   dest_exe;
wire    [4:0]   dest_mem;
wire    [4:0]   dest_wb;
wire    [31:0] forward_data_exe;
wire    inst_ld_w_forward_exe;
wire [31:0] forward_data_mem;
wire [31:0] forward_data_wb;


//from csr_control to IF
wire csr_is_branch;
wire [31:0] csr_pc_if;

//if
wire ADEF_to_ID;
wire [18:0] s0_vppn_to_tlb;
wire  s0_va_bit12_to_tlb;
wire TLBREFILL_to_ID;
wire IFTLBINVALID_to_ID;
wire IFTLBPOWER_to_ID;
wire EXC_IF_to_ID;


//decode
wire csr_rd_we_to_exe;
wire [13:0] csr_num_to_exe;
wire [4:0] csr_rd_to_exe;
wire csr_csr_we_to_exe;
wire [31:0] csr_csr_wvalue_to_exe;
wire csr_ertn_flush_to_exe;
wire csr_wb_ex_to_exe;
wire [5:0] csr_wb_ecode_to_exe;
wire [8:0] csr_wb_subecode_to_exe;
wire [31:0] csr_csr_wmask_to_exe;
wire ALE_h_to_exe;
wire ALE_w_to_exe;
wire [1:0] rdcntv_to_exe;
wire tlb_refecth_to_exe;
wire tlb_tlbwr_to_exe;
wire tlb_tlbrd_to_exe;
wire tlb_tlbsrch_to_exe;
wire tlb_tlbfill_to_exe;
wire tlb_invtlb_to_exe;
wire [4:0] tlb_invtlb_op_to_exe;
wire [31:0] tlb_invtlb_rj_value_to_exe;
wire [31:0] tlb_invtlb_rk_value_to_exe;
wire        cacop_to_exe;
wire [4:0]  cacop_code_to_exe;
wire EXC_IF_to_exe;
//exe
wire csr_rd_we_to_mem;
wire [13:0] csr_num_to_mem;
wire [4:0]  csr_rd_to_mem;
wire csr_csr_we_to_mem;
wire [31:0] csr_csr_wvalue_to_mem;
wire [31:0] csr_csr_wmask_to_mem;
wire  csr_ertn_flush_to_mem;
wire csr_wb_ex_to_mem;
wire [5:0] csr_wb_ecode_to_mem;
wire [8:0] csr_wb_subecode_to_mem;
wire [31:0] csr_BADV_to_mem;
wire mem_we_to_mem;
wire tlb_refecth_to_mem;
wire tlb_invtlb_to_mem;
wire tlb_tlbwr_to_mem;
wire tlb_tlbrd_to_mem;
wire tlb_tlbsrch_to_mem;
wire tlb_tlbfill_to_mem;
wire [18:0] tlb_vppn_exe_to_tlb;
wire [9:0] tlb_asid_exe_to_tlb;
wire [4:0] tlb_invtlb_op_exe_to_tlb;
wire tlb_va_bit12_exe_to_tlb;
wire EXC_IF_to_mem;


//mem
wire csr_rd_we_to_wb;
wire [4:0]  csr_rd_to_wb;
wire [13:0] csr_num_to_wb;
wire  csr_csr_we_to_wb;
wire  [31:0] csr_csr_wvalue_to_wb;
wire  csr_ertn_flush_to_wb;
wire  [31:0] csr_csr_wmask_to_wb;
wire  csr_wb_ex_to_wb;
wire [5:0] csr_wb_ecode_to_wb;
wire [8:0] csr_wb_subecode_to_wb;
wire [31:0] csr_BADV_to_wb;
wire  load_block_mem;
wire tlb_refecth_to_wb;
wire tlb_invtlb_to_wb;
wire tlb_tlbwr_to_wb;
wire tlb_tlbrd_to_wb;
wire tlb_tlbsrch_to_wb;
wire tlb_tlbfill_to_wb;
wire EXC_IF_to_wb;






//wb
wire [13:0] csr_num_wb;
wire csr_rd_we_wb;
wire csr_csr_we_wb;
wire [31:0] csr_csr_wvalue_wb;
wire [31:0] csr_csr_wmask_wb;
wire csr_ertn_flush_wb;
wire csr_wb_ex_wb;
wire [5:0] csr_wb_ecode_wb;
wire [8:0] csr_wb_subecode_wb;
wire [31:0] csr_pc_wb;
wire [31:0] csr_BADV_wb;
wire tlb_refecth_wb;
wire tlb_invtlb_wb;
wire tlb_tlbwr_wb;
wire tlb_tlbrd_wb;
wire tlb_tlbsrch_wb;
wire tlb_tlbfill_wb;
wire [31:0] wb_pc_to_csr;
wire EXC_IF_wb;


//csr_control
wire [31:0] csr_rd_value;
wire has_int;
wire [18:0] tlb_vpnn_csr_to_exe;
wire [9:0] tlb_asid_csr_to_exe;
wire tlb_va_bit12_csr_to_exe;
wire [3:0] tlb_r_index_csr_to_tlb;
wire tlb_we_csr_to_tlb;
wire [3:0] tlb_w_index_csr_to_tlb;
wire tlb_w_e_csr_to_tlb;
wire [18:0] tlb_w_vppn_csr_to_tlb;
wire [5:0] tlb_w_ps_csr_to_tlb;
wire [9:0] tlb_w_asid_csr_to_tlb;
wire tlb_w_g_csr_to_tlb;
wire [19:0] tlb_w_ppn0_csr_to_tlb;
wire [1:0] tlb_w_plv0_csr_to_tlb;
wire [1:0] tlb_w_mat0_csr_to_tlb;
wire tlb_w_d0_csr_to_tlb;
wire tlb_w_v0_csr_to_tlb;
wire [19:0] tlb_w_ppn1_csr_to_tlb;
wire [1:0] tlb_w_plv1_csr_to_tlb;
wire [1:0] tlb_w_mat1_csr_to_tlb;
wire tlb_w_d1_csr_to_tlb;
wire tlb_w_v1_csr_to_tlb;
wire [1:0] csr_plv_for_mmu;
wire csr_dmw0_plv0_for_mmu;
wire csr_dmw0_plv3_for_mmu;
wire [2:0] csr_dmw0_pseg_for_mmu;
wire [2:0] csr_dmw0_vseg_for_mmu;
wire csr_dmw1_plv0_for_mmu;
wire csr_dmw1_plv3_for_mmu;
wire [2:0] csr_dmw1_pseg_for_mmu;
wire [2:0] csr_dmw1_vseg_for_mmu;
wire csr_direct_addr_for_mmu;
wire [1:0] csr_crmd_datm_for_mmu;
wire [1:0] csr_dmw0_mat_for_mmu;
wire [1:0] csr_dmw1_mat_for_mmu;

//tlb
wire tlb_s0_found;
wire [3:0] tlb_s0_index;
wire [19:0] tlb_s0_ppn;
wire [5:0] tlb_s0_ps;
wire [1:0] tlb_s0_plv;
wire [1:0] tlb_s0_mat;
wire tlb_s0_d;
wire tlb_s0_v;
wire tlb_s1_found;
wire [3:0] tlb_s1_index;
wire [19:0] tlb_s1_ppn;
wire [5:0] tlb_s1_ps;
wire [1:0] tlb_s1_plv;
wire [1:0] tlb_s1_mat;
wire tlb_s1_d;
wire tlb_s1_v;
wire tlb_r_e;
wire [18:0] tlb_r_vppn;
wire [5:0] tlb_r_ps;
wire [9:0] tlb_r_asid;
wire tlb_r_g;
wire [19:0] tlb_r_ppn0;
wire [1:0] tlb_r_plv0;
wire [1:0] tlb_r_mat0;
wire tlb_r_d0;
wire tlb_r_v0;
wire [19:0] tlb_r_ppn1;
wire [1:0] tlb_r_plv1;
wire [1:0] tlb_r_mat1;
wire tlb_r_d1;
wire tlb_r_v1;


/*
=============================================================
instrucion fetch
=============================================================
*/

instruction_fetch instruction_fetch(
	.clk		(clk		),
	.reset		(reset		),
	
	//from decode
	.dec_allowin 	(dec_allowin	),
	
	.branch_bus	(branch_bus	),
	
	//from csr_control
	.csr_is_branch(csr_is_branch),
	.csr_pc_if(csr_pc_if),

	.csr_plv_for_mmu(csr_plv_for_mmu),
	.csr_dmw0_plv0_for_mmu(csr_dmw0_plv0_for_mmu),
	.csr_dmw0_plv3_for_mmu(csr_dmw0_plv3_for_mmu),
	.csr_dmw0_pseg_for_mmu(csr_dmw0_pseg_for_mmu),
	.csr_dmw0_vseg_for_mmu(csr_dmw0_vseg_for_mmu),
	.csr_dmw1_plv0_for_mmu(csr_dmw1_plv0_for_mmu),
	.csr_dmw1_plv3_for_mmu(csr_dmw1_plv3_for_mmu),
	.csr_dmw1_pseg_for_mmu(csr_dmw1_pseg_for_mmu),
	.csr_dmw1_vseg_for_mmu(csr_dmw1_vseg_for_mmu),
	.csr_direct_addr_for_mmu(csr_direct_addr_for_mmu),
	
	//to inst_decode
	.fetch_to_dec_valid(fetch_to_dec_valid),
	.fetch_to_decode_bus(fetch_to_decode_bus),
	.ADEF_to_ID(ADEF_to_ID),
	.TLBREFILL_to_ID(TLBREFILL_to_ID),
	.IFTLBINVALID_to_ID(IFTLBINVALID_to_ID),
	.IFTLBPOWER_to_ID(IFTLBPOWER_to_ID),
	.EXC_IF_to_ID(EXC_IF_to_ID),

	//to tlb
	.s0_vppn_to_tlb(s0_vppn_to_tlb),
	.s0_va_bit12_to_tlb(s0_va_bit12_to_tlb),

	//from 	tlb
	.s0_found		(tlb_s0_found		),
	.s0_ppn			(tlb_s0_ppn			),
	.s0_ps			(tlb_s0_ps			),
	.s0_plv			(tlb_s0_plv			),
	.s0_mat			(tlb_s0_mat			),
	.s0_d			(tlb_s0_d			),
	.s0_v			(tlb_s0_v			),
	.s0_index		(tlb_s0_index		),
	//instruction sram interface
	.inst_sram_req	(inst_sram_req	),
	.inst_sram_wr	(inst_sram_wr	),
	.inst_sram_size(inst_sram_size),
	.inst_sram_wstrb(inst_sram_wstrb),
	.inst_sram_addr	(inst_sram_addr	),
	.inst_sram_rdata(inst_sram_rdata),
	.inst_sram_wdata(inst_sram_wdata),
	.inst_sram_addr_ok(inst_sram_addr_ok),
	.inst_sram_data_ok(inst_sram_data_ok),

	//virtual	address
	.inst_sram_vaddr(inst_sram_vaddr)
);

/*
==============================================================
instruction decode
==============================================================
*/
inst_decode inst_decode(
	.clk		(clk		),
	.reset		(reset		),
	
	//from fecth
	.fetch_to_dec_valid	(fetch_to_dec_valid),
 	.fetch_to_decode_bus	(fetch_to_decode_bus),
	.ADEF_to_ID(ADEF_to_ID),
	.TLBREFILL_to_ID(TLBREFILL_to_ID),
	.IFTLBINVALID_to_ID(IFTLBINVALID_to_ID),
	.IFTLBPOWER_to_ID(IFTLBPOWER_to_ID),
	.EXC_IF_to_ID(EXC_IF_to_ID),
	
	//to fetch 
	.dec_allowin	(dec_allowin	),
	.branch_bus	(branch_bus	),
	
	//from exe
	.exe_allowin	(exe_allowin	),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),
	.inst_ld_w_forward_exe(inst_ld_w_forward_exe),	
	.forward_data_exe(forward_data_exe),
	.csr_rd_we_to_mem(csr_rd_we_to_mem),
	.csr_rd_to_mem(csr_rd_to_mem),
	.csr_num_to_mem(csr_num_to_mem),
	.csr_csr_we_to_mem(csr_csr_we_to_mem),
	.csr_ertn_flush_to_mem(csr_ertn_flush_to_mem),
	.tlb_tlbrd_to_mem(tlb_tlbrd_to_mem),
	//to exe
	.dec_to_exe_valid(dec_to_exe_valid),
	.dec_to_exe_bus	(decode_to_exe_bus),
	.csr_rd_we_to_exe(csr_rd_we_to_exe),
	.csr_num_to_exe(csr_num_to_exe),
	.csr_rd_to_exe(csr_rd_to_exe),
	.csr_csr_we_to_exe(csr_csr_we_to_exe),
	.csr_csr_wvalue_to_exe(csr_csr_wvalue_to_exe),
	.csr_csr_wmask_to_exe(csr_csr_wmask_to_exe),
	.csr_ertn_flush_to_exe(csr_ertn_flush_to_exe),
	.csr_wb_ex_to_exe(csr_wb_ex_to_exe),
	.csr_wb_ecode_to_exe(csr_wb_ecode_to_exe),
	.csr_wb_subecode_to_exe(csr_wb_subecode_to_exe),
	.ALE_h_to_exe(ALE_h_to_exe),
	.ALE_w_to_exe(ALE_w_to_exe),
	.rdcntv_to_exe(rdcntv_to_exe),
	.tlb_refecth_to_exe(tlb_refecth_to_exe),
	.tlb_tlbwr_to_exe(tlb_tlbwr_to_exe),
	.tlb_tlbrd_to_exe(tlb_tlbrd_to_exe),
	.tlb_tlbsrch_to_exe(tlb_tlbsrch_to_exe),
	.tlb_tlbfill_to_exe(tlb_tlbfill_to_exe),
	.tlb_invtlb_to_exe(tlb_invtlb_to_exe),
	.tlb_invtlb_op_to_exe(tlb_invtlb_op_to_exe),
	.tlb_invtlb_rj_value_to_exe(tlb_invtlb_rj_value_to_exe),
	.tlb_invtlb_rk_value_to_exe(tlb_invtlb_rk_value_to_exe),
	.cacop_to_exe(cacop_to_exe),
	.cacop_code_to_exe(cacop_code_to_exe),
	.EXC_IF_to_exe(EXC_IF_to_exe),
  
	
    //from mem
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	.forward_data_mem(forward_data_mem),
	.csr_rd_we_to_wb(csr_rd_we_to_wb),
	.csr_rd_to_wb(csr_rd_to_wb),
	.csr_num_to_wb(csr_num_to_wb),
	.csr_csr_we_to_wb(csr_csr_we_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.load_block_mem(load_block_mem),
	.tlb_tlbrd_to_wb(tlb_tlbrd_to_wb),
    //from write back
	.gr_we_wb(gr_we_wb),
	.dest_wb(dest_wb),	
	//from write back
	.forward_data_wb(forward_data_wb),
	.wb_to_regfile_bus(wb_to_regfile_bus),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.csr_rd_we_wb(csr_rd_we_wb),
	.csr_num_wb(csr_num_wb),
	.csr_csr_we_wb(csr_csr_we_wb),
	.tlb_tlbrd_wb(tlb_tlbrd_wb),
	.tlb_refecth_wb(tlb_refecth_wb),
	.has_int(has_int)
);

exe  exe(
	.clk (clk),
	.reset(reset),
	.stable_counter(stable_counter),
	
	//from decode
	.dec_to_exe_valid(dec_to_exe_valid),
	.decode_to_exe_bus(decode_to_exe_bus),
	.csr_rd_we_to_exe(csr_rd_we_to_exe),
	.csr_num_to_exe(csr_num_to_exe),
	.csr_rd_to_exe(csr_rd_to_exe),
	.csr_csr_we_to_exe(csr_csr_we_to_exe),
	.csr_csr_wvalue_to_exe(csr_csr_wvalue_to_exe),
	.csr_csr_wmask_to_exe(csr_csr_wmask_to_exe),
	.csr_ertn_flush_to_exe(csr_ertn_flush_to_exe),
	.csr_wb_ex_to_exe(csr_wb_ex_to_exe),
	.csr_wb_ecode_to_exe(csr_wb_ecode_to_exe),
	.csr_wb_subecode_to_exe(csr_wb_subecode_to_exe),
	.ALE_h_to_exe(ALE_h_to_exe),
	.ALE_w_to_exe(ALE_w_to_exe),
	.rdcntv_to_exe(rdcntv_to_exe),
	.tlb_refecth_to_exe(tlb_refecth_to_exe),
	.tlb_tlbwr_to_exe(tlb_tlbwr_to_exe),
	.tlb_tlbrd_to_exe(tlb_tlbrd_to_exe),
	.tlb_tlbsrch_to_exe(tlb_tlbsrch_to_exe),
	.tlb_tlbfill_to_exe(tlb_tlbfill_to_exe),
	.tlb_invtlb_to_exe(tlb_invtlb_to_exe),
	.tlb_invtlb_op_to_exe(tlb_invtlb_op_to_exe),
	.tlb_invtlb_rj_value_to_exe(tlb_invtlb_rj_value_to_exe),
	.tlb_invtlb_rk_value_to_exe(tlb_invtlb_rk_value_to_exe),
	.cacop_to_exe(cacop_to_exe),
	.cacop_code_to_exe(cacop_code_to_exe),
	.EXC_IF_to_exe(EXC_IF_to_exe),
	
	//to decode 
	.exe_allowin(exe_allowin),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),	
	.inst_ld_w_forward_exe(inst_ld_w_forward_exe),	
	.forward_data_exe(forward_data_exe),
	//from mem
	.mem_allowin(mem_allowin),
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.tlb_refecth_to_wb(tlb_refecth_to_wb),

	//from wb
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.tlb_refecth_wb(tlb_refecth_wb),
	

	//from csr
	.tlb_vppn_csr_to_exe(tlb_vpnn_csr_to_exe),
	.tlb_va_bit12_csr_to_exe(tlb_va_bit12_csr_to_exe),
	.tlb_asid_csr_to_exe(tlb_asid_csr_to_exe),
	.csr_plv_for_mmu(csr_plv_for_mmu),
	.csr_crmd_datm_for_mmu(csr_crmd_datm_for_mmu),
	.csr_dmw0_mat_for_mmu(csr_dmw0_mat_for_mmu),
	.csr_dmw1_mat_for_mmu(csr_dmw1_mat_for_mmu),
	.csr_dmw0_plv0_for_mmu(csr_dmw0_plv0_for_mmu),
	.csr_dmw0_plv3_for_mmu(csr_dmw0_plv3_for_mmu),
	.csr_dmw0_pseg_for_mmu(csr_dmw0_pseg_for_mmu),
	.csr_dmw0_vseg_for_mmu(csr_dmw0_vseg_for_mmu),
	.csr_dmw1_plv0_for_mmu(csr_dmw1_plv0_for_mmu),
	.csr_dmw1_plv3_for_mmu(csr_dmw1_plv3_for_mmu),
	.csr_dmw1_pseg_for_mmu(csr_dmw1_pseg_for_mmu),
	.csr_dmw1_vseg_for_mmu(csr_dmw1_vseg_for_mmu),
	.csr_direct_addr_for_mmu(csr_direct_addr_for_mmu),
	
	


	
	//to mem
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus),
	.csr_rd_we_to_mem(csr_rd_we_to_mem),
	.csr_num_to_mem(csr_num_to_mem),
	.csr_rd_to_mem(csr_rd_to_mem),
	.csr_csr_we_to_mem(csr_csr_we_to_mem),
	.csr_csr_wvalue_to_mem(csr_csr_wvalue_to_mem),
	.csr_csr_wmask_to_mem(csr_csr_wmask_to_mem),
	.csr_ertn_flush_to_mem(csr_ertn_flush_to_mem),
	.csr_wb_ex_to_mem(csr_wb_ex_to_mem),
	.csr_wb_ecode_to_mem(csr_wb_ecode_to_mem),
	.csr_wb_subecode_to_mem(csr_wb_subecode_to_mem),
	.csr_BADV_to_mem(csr_BADV_to_mem),
	.mem_we_to_mem(mem_we_to_mem),
	.tlb_refecth_to_mem(tlb_refecth_to_mem),
	.tlb_invtlb_to_mem(tlb_invtlb_to_mem),
	.tlb_tlbwr_to_mem(tlb_tlbwr_to_mem),
	.tlb_tlbrd_to_mem(tlb_tlbrd_to_mem),
	.tlb_tlbsrch_to_mem(tlb_tlbsrch_to_mem),
	.tlb_tlbfill_to_mem(tlb_tlbfill_to_mem),
	//to tlb
	.tlb_vppn_exe_to_tlb(tlb_vppn_exe_to_tlb),
	.tlb_asid_exe_to_tlb(tlb_asid_exe_to_tlb),
	.tlb_invtlb_op_exe_to_tlb(tlb_invtlb_op_exe_to_tlb),
	.tlb_va_bit12_exe_to_tlb(tlb_va_bit12_exe_to_tlb),
	.EXC_IF_to_mem(EXC_IF_to_mem),
	
	.s1_found(tlb_s1_found),
	.s1_ppn(tlb_s1_ppn),
	.s1_ps(tlb_s1_ps),
	.s1_plv(tlb_s1_plv),
	.s1_mat(tlb_s1_mat),
	.s1_d(tlb_s1_d),
	.s1_v(tlb_s1_v),
	.s1_index(tlb_s1_index),
	
	//data sram interface
	.data_sram_req(data_sram_req),
	.data_sram_wr(data_sram_wr),
	.data_sram_size(data_sram_size),
	.data_sram_wstrb(data_sram_wstrb),
	.data_sram_addr(data_sram_addr),
	.data_sram_wdata(data_sram_wdata),
	.data_sram_addr_ok(data_sram_addr_ok),
	.data_sram_uncache(data_sram_uncache),

	//virtual	address
	.data_sram_vaddr(data_sram_vaddr),

	// CACOP to caches
	.icache_cacop_valid(icache_cacop_valid),
	.icache_cacop_op(icache_cacop_op),
	.icache_cacop_index(icache_cacop_index),
	.icache_cacop_tag(icache_cacop_tag),
	.icache_cacop_addr_ok(icache_cacop_addr_ok),
	.icache_cacop_data_ok(icache_cacop_data_ok),
	.dcache_cacop_valid(dcache_cacop_valid),
	.dcache_cacop_op(dcache_cacop_op),
	.dcache_cacop_index(dcache_cacop_index),
	.dcache_cacop_tag(dcache_cacop_tag),
	.dcache_cacop_addr_ok(dcache_cacop_addr_ok),
	.dcache_cacop_data_ok(dcache_cacop_data_ok)
);

mem mem(
	.clk		(clk		),
	.reset		(reset		),

    //to decode
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	.forward_data_mem(forward_data_mem),
	.load_block_mem(load_block_mem),	
	//from exe
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus	),
	.csr_rd_we_to_mem(csr_rd_we_to_mem),
	.csr_rd_to_mem(csr_rd_to_mem),
	.csr_num_to_mem(csr_num_to_mem),
	.csr_csr_we_to_mem(csr_csr_we_to_mem),
	.csr_csr_wvalue_to_mem(csr_csr_wvalue_to_mem),
	.csr_csr_wmask_to_mem(csr_csr_wmask_to_mem),
	.csr_ertn_flush_to_mem(csr_ertn_flush_to_mem),
	.csr_wb_ex_to_mem(csr_wb_ex_to_mem),
	.csr_wb_ecode_to_mem(csr_wb_ecode_to_mem),
	.csr_wb_subecode_to_mem(csr_wb_subecode_to_mem),
	.csr_BADV_to_mem(csr_BADV_to_mem),
	.mem_we_to_mem(mem_we_to_mem),
	.tlb_refecth_to_mem(tlb_refecth_to_mem),
	.tlb_invtlb_to_mem(tlb_invtlb_to_mem),
	.tlb_tlbwr_to_mem(tlb_tlbwr_to_mem),
	.tlb_tlbrd_to_mem(tlb_tlbrd_to_mem),
	.tlb_tlbsrch_to_mem(tlb_tlbsrch_to_mem),
	.tlb_tlbfill_to_mem(tlb_tlbfill_to_mem),
	.EXC_IF_to_mem(EXC_IF_to_mem),

	
	//to exe
	.mem_allowin	(mem_allowin),
	
	//from write back
	.wb_allowin	(wb_allowin),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.tlb_refecth_wb(tlb_refecth_wb),
	
	//to write back
	.mem_to_wb_valid(mem_to_wb_valid),
	.mem_to_wb_bus	(mem_to_wb_bus),
	.csr_rd_we_to_wb(csr_rd_we_to_wb),
	.csr_rd_to_wb(csr_rd_to_wb),
	.csr_num_to_wb(csr_num_to_wb),
	.csr_csr_we_to_wb(csr_csr_we_to_wb),
	.csr_csr_wvalue_to_wb(csr_csr_wvalue_to_wb),
	.csr_csr_wmask_to_wb(csr_csr_wmask_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	.csr_wb_ecode_to_wb(csr_wb_ecode_to_wb),
	.csr_wb_subecode_to_wb(csr_wb_subecode_to_wb),
	.csr_BADV_to_wb(csr_BADV_to_wb),
	.tlb_refecth_to_wb(tlb_refecth_to_wb),
	.tlb_invtlb_to_wb(tlb_invtlb_to_wb),
	.tlb_tlbwr_to_wb(tlb_tlbwr_to_wb),
	.tlb_tlbrd_to_wb(tlb_tlbrd_to_wb),
	.tlb_tlbsrch_to_wb(tlb_tlbsrch_to_wb),
	.tlb_tlbfill_to_wb(tlb_tlbfill_to_wb),	
	.EXC_IF_to_wb(EXC_IF_to_wb),
	
	//data sram interface
	.data_sram_rdata(data_sram_rdata),
	.data_sram_data_ok(data_sram_data_ok),
	.data_sram_counter(data_sram_counter)
);
wb wb(
	.clk		(clk		),
	.reset		(reset		),
	
    //to decode
	.gr_we_wb_final(gr_we_wb),
	.dest_wb_final(dest_wb),	
	.forward_data_wb(forward_data_wb),
	//from mem
	.mem_to_wb_valid(mem_to_wb_valid),
	.mem_to_wb_bus	(mem_to_wb_bus	),
	.csr_num_to_wb(csr_num_to_wb),
	.csr_rd_to_wb(csr_rd_to_wb),
	.csr_rd_we_to_wb(csr_rd_we_to_wb),
	.csr_csr_we_to_wb(csr_csr_we_to_wb),
	.csr_csr_wvalue_to_wb(csr_csr_wvalue_to_wb),
	.csr_csr_wmask_to_wb(csr_csr_wmask_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	.csr_wb_ecode_to_wb(csr_wb_ecode_to_wb),
	.csr_wb_subecode_to_wb(csr_wb_subecode_to_wb),
	.csr_BADV_to_wb(csr_BADV_to_wb),
	.tlb_refecth_to_wb(tlb_refecth_to_wb),
	.tlb_invtlb_to_wb(tlb_invtlb_to_wb),
	.tlb_tlbwr_to_wb(tlb_tlbwr_to_wb),
	.tlb_tlbrd_to_wb(tlb_tlbrd_to_wb),
	.tlb_tlbsrch_to_wb(tlb_tlbsrch_to_wb),
	.tlb_tlbfill_to_wb(tlb_tlbfill_to_wb),
    .EXC_IF_to_wb(EXC_IF_to_wb),
	//from csr_control
	.csr_rd_value(csr_rd_value),
	
	//to mem
	.wb_allowin	(wb_allowin	),
	
	//to register file
	.wb_to_regfile_bus(wb_to_regfile_bus),
	
	    //trace debug interface
    .debug_wb_pc (debug_wb_pc)    ,
    .debug_wb_rf_we(debug_wb_rf_we) ,
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

	//to csr_control
	.csr_num_wb(csr_num_wb),
	.csr_rd_we_wb(csr_rd_we_wb),
	.csr_csr_we_wb(csr_csr_we_wb),
	.csr_csr_wvalue_wb(csr_csr_wvalue_wb),
	.csr_csr_wmask_wb(csr_csr_wmask_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_wb_ecode_wb(csr_wb_ecode_wb),
	.csr_wb_subecode_wb(csr_wb_subecode_wb),
	.csr_pc_wb(csr_pc_wb),
	.csr_BADV_wb(csr_BADV_wb),
	.tlb_refecth_wb(tlb_refecth_wb),
	.tlb_invtlb_wb(tlb_invtlb_wb),
	.tlb_tlbwr_wb(tlb_tlbwr_wb),
	.tlb_tlbrd_wb(tlb_tlbrd_wb),
	.tlb_tlbsrch_wb(tlb_tlbsrch_wb),
	.tlb_tlbfill_wb(tlb_tlbfill_wb),
	.wb_pc_to_csr(wb_pc_to_csr),
	.EXC_IF_wb(EXC_IF_wb)
    
);
csr_control csr_control(
	.clk(clk),
	.reset(reset),
	.csr_num_wb(csr_num_wb),
	.csr_rd_we_wb(csr_rd_we_wb),
	.csr_csr_wvalue_wb(csr_csr_wvalue_wb),
	.csr_csr_we_wb(csr_csr_we_wb),
	.csr_csr_wmask_wb(csr_csr_wmask_wb),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.csr_wb_ecode_wb(csr_wb_ecode_wb),
	.csr_wb_subecode_wb(csr_wb_subecode_wb),
	.csr_pc_wb(csr_pc_wb),
	.csr_BADV_wb(csr_BADV_wb),

	.tlb_refecth_wb(tlb_refecth_wb),
	.tlb_invtlb_wb(tlb_invtlb_wb),
	.tlb_tlbwr_wb(tlb_tlbwr_wb),
	.tlb_tlbrd_wb(tlb_tlbrd_wb),
	.tlb_tlbsrch_to_mem(tlb_tlbsrch_to_mem),
	.tlb_tlbfill_wb(tlb_tlbfill_wb),

	.wb_pc_to_csr(wb_pc_to_csr),
	.EXC_IF_wb(EXC_IF_wb),

    .tlb_index_tlb_to_csr(tlb_s1_index),
	.tlb_found_tlb_to_csr(tlb_s1_found),
	.tlb_r_e_tlb_to_csr(tlb_r_e),
	.tlb_r_vppn_tlb_to_csr(tlb_r_vppn),
	.tlb_r_ps_tlb_to_csr(tlb_r_ps),
	.tlb_r_asid_tlb_to_csr(tlb_r_asid),
	.tlb_r_g_tlb_to_csr(tlb_r_g),
	.tlb_r_ppn0_tlb_to_csr(tlb_r_ppn0),
	.tlb_r_plv0_tlb_to_csr(tlb_r_plv0),
	.tlb_r_mat0_tlb_to_csr(tlb_r_mat0),
	.tlb_r_d0_tlb_to_csr(tlb_r_d0),
	.tlb_r_v0_tlb_to_csr(tlb_r_v0),
	.tlb_r_ppn1_tlb_to_csr(tlb_r_ppn1),
	.tlb_r_plv1_tlb_to_csr(tlb_r_plv1),
	.tlb_r_mat1_tlb_to_csr(tlb_r_mat1),	
	.tlb_r_d1_tlb_to_csr(tlb_r_d1),
	.tlb_r_v1_tlb_to_csr(tlb_r_v1),
	.tlb_vpnn_csr_to_exe(tlb_vpnn_csr_to_exe),
	.tlb_asid_csr_to_exe(tlb_asid_csr_to_exe),
	.tlb_va_bit12_csr_to_exe(tlb_va_bit12_csr_to_exe),
	.tlb_r_index_csr_to_tlb(tlb_r_index_csr_to_tlb),
	.tlb_we_csr_to_tlb(tlb_we_csr_to_tlb),
	.tlb_w_index_csr_to_tlb(tlb_w_index_csr_to_tlb),
	.tlb_w_e_csr_to_tlb(tlb_w_e_csr_to_tlb),
	.tlb_w_vppn_csr_to_tlb(tlb_w_vppn_csr_to_tlb),
	.tlb_w_ps_csr_to_tlb(tlb_w_ps_csr_to_tlb),
	.tlb_w_asid_csr_to_tlb(tlb_w_asid_csr_to_tlb),
	.tlb_w_g_csr_to_tlb(tlb_w_g_csr_to_tlb),
	.tlb_w_ppn0_csr_to_tlb(tlb_w_ppn0_csr_to_tlb),
	.tlb_w_plv0_csr_to_tlb(tlb_w_plv0_csr_to_tlb),
	.tlb_w_mat0_csr_to_tlb(tlb_w_mat0_csr_to_tlb),
	.tlb_w_d0_csr_to_tlb(tlb_w_d0_csr_to_tlb),
	.tlb_w_v0_csr_to_tlb(tlb_w_v0_csr_to_tlb),
	.tlb_w_ppn1_csr_to_tlb(tlb_w_ppn1_csr_to_tlb),
	.tlb_w_plv1_csr_to_tlb(tlb_w_plv1_csr_to_tlb),
	.tlb_w_mat1_csr_to_tlb(tlb_w_mat1_csr_to_tlb),
	.tlb_w_d1_csr_to_tlb(tlb_w_d1_csr_to_tlb),
	.tlb_w_v1_csr_to_tlb(tlb_w_v1_csr_to_tlb),	

	.csr_rd_value(csr_rd_value),
	.csr_is_branch(csr_is_branch),
	.csr_pc_if(csr_pc_if),
	.csr_plv_for_mmu(csr_plv_for_mmu),
	.csr_dmw0_plv0_for_mmu(csr_dmw0_plv0_for_mmu),
	.csr_dmw0_plv3_for_mmu(csr_dmw0_plv3_for_mmu),
	.csr_dmw0_pseg_for_mmu(csr_dmw0_pseg_for_mmu),
	.csr_dmw0_vseg_for_mmu(csr_dmw0_vseg_for_mmu),
	.csr_dmw1_plv0_for_mmu(csr_dmw1_plv0_for_mmu),
	.csr_dmw1_plv3_for_mmu(csr_dmw1_plv3_for_mmu),
	.csr_dmw1_pseg_for_mmu(csr_dmw1_pseg_for_mmu),
	.csr_dmw1_vseg_for_mmu(csr_dmw1_vseg_for_mmu),
	.csr_crmd_datm_for_mmu(csr_crmd_datm_for_mmu),
	.csr_dmw0_mat_for_mmu(csr_dmw0_mat_for_mmu),
	.csr_dmw1_mat_for_mmu(csr_dmw1_mat_for_mmu),
	.csr_direct_addr_for_mmu(csr_direct_addr_for_mmu),
	.has_int(has_int)

);

tlb tlb(
	.clk(clk),
	.reset(reset),
	.inst_wb_tlbfill(tlb_tlbfill_wb),
	.s0_vppn(s0_vppn_to_tlb),
	.s0_asid(tlb_asid_csr_to_exe),
	.s0_va_bit12(s0_va_bit12_to_tlb),
	.s0_found(tlb_s0_found),
	.s0_index(tlb_s0_index),
	.s0_ppn(tlb_s0_ppn),
	.s0_ps(tlb_s0_ps),
	.s0_plv(tlb_s0_plv),
	.s0_mat(tlb_s0_mat),
	.s0_d(tlb_s0_d),
	.s0_v(tlb_s0_v),
	.s1_vppn(tlb_vppn_exe_to_tlb),
	.s1_asid(tlb_asid_exe_to_tlb),
	.s1_va_bit12(tlb_va_bit12_exe_to_tlb),
	.s1_found(tlb_s1_found),
	.s1_index(tlb_s1_index),
	.s1_ppn(tlb_s1_ppn),
	.s1_ps(tlb_s1_ps),
	.s1_plv(tlb_s1_plv),
	.s1_mat(tlb_s1_mat),
	.s1_d(tlb_s1_d),
	.s1_v(tlb_s1_v),
	.invtlb_valid(tlb_invtlb_to_mem),
	.invtlb_op(tlb_invtlb_op_exe_to_tlb),
    .we(tlb_we_csr_to_tlb),
	.w_index(tlb_w_index_csr_to_tlb),
	.w_e(tlb_w_e_csr_to_tlb),
	.w_vppn(tlb_w_vppn_csr_to_tlb),
	.w_ps(tlb_w_ps_csr_to_tlb),
	.w_asid(tlb_w_asid_csr_to_tlb),
	.w_g(tlb_w_g_csr_to_tlb),
	.w_ppn0(tlb_w_ppn0_csr_to_tlb),
	.w_plv0(tlb_w_plv0_csr_to_tlb),
	.w_mat0(tlb_w_mat0_csr_to_tlb),
	.w_d0(tlb_w_d0_csr_to_tlb),
	.w_v0(tlb_w_v0_csr_to_tlb),
	.w_ppn1(tlb_w_ppn1_csr_to_tlb),
	.w_plv1(tlb_w_plv1_csr_to_tlb),		
	.w_mat1(tlb_w_mat1_csr_to_tlb),
	.w_d1(tlb_w_d1_csr_to_tlb),
	.w_v1(tlb_w_v1_csr_to_tlb),
	.r_index(tlb_r_index_csr_to_tlb),
	.r_e(tlb_r_e),
	.r_vppn(tlb_r_vppn),
	.r_ps(tlb_r_ps),
	.r_asid(tlb_r_asid),
	.r_g(tlb_r_g),
	.r_ppn0(tlb_r_ppn0),
	.r_plv0(tlb_r_plv0),
	.r_mat0(tlb_r_mat0),
	.r_d0(tlb_r_d0),
	.r_v0(tlb_r_v0),
	.r_ppn1(tlb_r_ppn1),
	.r_plv1(tlb_r_plv1),
	.r_mat1(tlb_r_mat1),
	.r_d1(tlb_r_d1),
	.r_v1(tlb_r_v1)
);




endmodule

