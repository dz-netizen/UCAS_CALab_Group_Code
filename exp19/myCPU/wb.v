`include "mycpu.h"
module	wb(
	input wire	clk,
	input wire	reset,
	
	//to decode
	output wire gr_we_wb_final,
	output wire [4:0]  dest_wb_final,
	output wire [31:0] forward_data_wb,	
	//from mem
	input wire	mem_to_wb_valid,
	input wire	[`MEM_TO_WB_BUS_WD-1:0]	mem_to_wb_bus,
	input wire  [13:0] csr_num_to_wb,
	input wire  [4:0] csr_rd_to_wb,
	input wire   csr_rd_we_to_wb,
	input wire  [31:0] csr_rd_value,
	input wire  csr_csr_we_to_wb,
	input wire  [31:0] csr_csr_wvalue_to_wb,
	input wire  [31:0] csr_csr_wmask_to_wb,
	input wire   csr_ertn_flush_to_wb,
	input wire   csr_wb_ex_to_wb,
	input wire   [5:0] csr_wb_ecode_to_wb,
	input wire   [8:0] csr_wb_subecode_to_wb,
	input wire   [31:0] csr_BADV_to_wb,
	input wire   tlb_refecth_to_wb,	
	input wire   tlb_invtlb_to_wb,
	input wire   tlb_tlbwr_to_wb,
	input wire   tlb_tlbrd_to_wb,
	input wire   tlb_tlbsrch_to_wb,
	input wire   tlb_tlbfill_to_wb,
    input wire   EXC_IF_to_wb,
	//to exe
	/*output wire csr_wb_ex_wb_to_exe,
	output wire csr_ertn_flush_wb_to_exe,//block store when reflush*/
	
	//to mem
	output wire	wb_allowin,
	
	//to register file
	output wire	[`WB_TO_REGFILE_BUS_WD-1:0] wb_to_regfile_bus,

    //trace debug interface
    output wire [31:0] debug_wb_pc     ,
    output wire [ 3:0] debug_wb_rf_we ,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
	

	//to csr_control
	output wire [13:0] csr_num_wb,
	output wire  csr_rd_we_wb,
	output wire csr_csr_we_wb,
	output wire [31:0] csr_csr_wvalue_wb,
	output wire [31:0] csr_csr_wmask_wb,
	output wire csr_ertn_flush_wb,
	output wire csr_wb_ex_wb,
	output wire [5:0] csr_wb_ecode_wb,
	output wire [8:0] csr_wb_subecode_wb,
	output wire [31:0] csr_pc_wb,
	output wire [31:0] csr_BADV_wb,
	output wire tlb_refecth_wb,
	output wire tlb_invtlb_wb,
	output wire tlb_tlbwr_wb,
	output wire tlb_tlbrd_wb,
	output wire tlb_tlbsrch_wb,
	output wire tlb_tlbfill_wb,
	output wire [31:0] wb_pc_to_csr,
	output wire   EXC_IF_wb

	
);

wire        gr_we_wb;
wire [4:0]  dest_wb;

reg	wb_valid;
wire	wb_ready_go;

reg [13:0] csr_num_wb_reg;
reg csr_rd_we_wb_reg;
reg [4:0] csr_rd_wb_reg;
reg csr_csr_we_wb_reg;
reg [31:0] csr_csr_wvalue_wb_reg;
reg [31:0] csr_csr_wmask_wb_reg;
reg csr_ertn_flush_wb_reg;
reg csr_wb_ex_wb_reg;
reg [5:0] csr_wb_ecode_wb_reg;
reg [8:0] csr_wb_subecode_wb_reg;
reg [31:0] csr_BADV_wb_reg;
reg tlb_refecth_wb_reg;
reg tlb_invtlb_wb_reg;
reg	tlb_tlbwr_wb_reg;
reg	tlb_tlbrd_wb_reg;
reg	tlb_tlbsrch_wb_reg;
reg	tlb_tlbfill_wb_reg;
reg	EXC_IF_wb_reg;

 

reg	[`MEM_TO_WB_BUS_WD-1:0]	wb_bus_reg;

wire	[4:0]	dest;
wire    [4:0]   dest_final;
wire	[31:0]	final_result;
wire    [31:0]  final_final_result;
wire	[31:0]	wb_pc;
wire    gr_we;

assign	{   gr_we,
            dest,
            final_result,
            wb_pc   }=wb_bus_reg;

wire	[3:0] reg_file_wen;
wire    [3:0] reg_file_wen_final;
assign	reg_file_wen={4{wb_valid&gr_we}};
assign  reg_file_wen_final = (csr_wb_ex_wb) ? 4'b0 :
                            (csr_rd_we_wb_reg) ? {4{wb_valid&csr_rd_we_wb_reg}} :
                             reg_file_wen;
assign dest_final = (csr_rd_we_wb_reg) ? csr_rd_wb_reg :
                     dest;
assign final_final_result = (csr_rd_we_wb_reg) ? csr_rd_value :
                             final_result;


assign	wb_to_regfile_bus={
	reg_file_wen_final,	//40:37
	dest_final,		//36:32
	final_final_result	//31:0
};

assign	wb_ready_go=1'b1;
assign	wb_allowin=!wb_valid|wb_ready_go;
always@(posedge clk)begin
	if(reset)begin
		wb_valid<=1'b0;
	end
	else if(csr_wb_ex_wb | csr_ertn_flush_wb | tlb_refecth_wb)begin
		wb_valid <= 1'b0;
	end
	else if(wb_allowin)begin
		wb_valid<=mem_to_wb_valid;
	end
end
always@(posedge clk)begin
   if(reset)begin
   wb_bus_reg <= 70'b0;
  end
	else if(mem_to_wb_valid&wb_allowin)begin
		wb_bus_reg<=mem_to_wb_bus;
		
	end

end

always@(posedge clk)begin
	if(reset)begin
		csr_num_wb_reg <= 14'b0;
		csr_rd_wb_reg <= 5'b0;
		csr_rd_we_wb_reg <= 1'b0;
		csr_csr_we_wb_reg <= 1'b0;
		csr_csr_wvalue_wb_reg <= 32'b0;
		csr_csr_wmask_wb_reg <= 32'b0;
		csr_ertn_flush_wb_reg <= 1'b0;
		csr_wb_ex_wb_reg <= 1'b0;
		csr_wb_ecode_wb_reg <= 6'b0;
		csr_wb_subecode_wb_reg <= 9'b0;
		csr_BADV_wb_reg <= 32'b0;
		tlb_refecth_wb_reg <= 1'b0;
		tlb_invtlb_wb_reg <= 1'b0;
		tlb_tlbwr_wb_reg <= 1'b0;
		tlb_tlbrd_wb_reg <= 1'b0;
		tlb_tlbsrch_wb_reg <= 1'b0;
		tlb_tlbfill_wb_reg <= 1'b0;
		EXC_IF_wb_reg <= 1'b0;
	end
	else if(mem_to_wb_valid && wb_allowin)begin
		csr_num_wb_reg <= csr_num_to_wb;
		csr_rd_wb_reg <= csr_rd_to_wb;
		csr_rd_we_wb_reg <= csr_rd_we_to_wb;
		csr_csr_we_wb_reg <= csr_csr_we_to_wb;
		csr_csr_wvalue_wb_reg <= csr_csr_wvalue_to_wb;
		csr_csr_wmask_wb_reg <= csr_csr_wmask_to_wb;
		csr_ertn_flush_wb_reg <= csr_ertn_flush_to_wb;
		csr_wb_ex_wb_reg <= csr_wb_ex_to_wb;
		csr_wb_subecode_wb_reg <= csr_wb_subecode_to_wb;
		csr_wb_ecode_wb_reg <= csr_wb_ecode_to_wb;
		csr_BADV_wb_reg <= csr_BADV_to_wb;
		tlb_refecth_wb_reg <= tlb_refecth_to_wb;
		tlb_invtlb_wb_reg <= tlb_invtlb_to_wb;
		tlb_tlbwr_wb_reg <= tlb_tlbwr_to_wb;
		tlb_tlbrd_wb_reg <= tlb_tlbrd_to_wb;
		tlb_tlbsrch_wb_reg <= tlb_tlbsrch_to_wb;
		tlb_tlbfill_wb_reg <= tlb_tlbfill_to_wb;
		EXC_IF_wb_reg <= EXC_IF_to_wb;
	end
end

assign csr_num_wb = csr_num_wb_reg;
assign csr_rd_we_wb = (csr_rd_we_wb_reg) && wb_valid;
assign csr_csr_we_wb = csr_csr_we_wb_reg && wb_valid;
assign csr_csr_wvalue_wb = csr_csr_wvalue_wb_reg;
assign csr_csr_wmask_wb  = csr_csr_wmask_wb_reg;
assign csr_ertn_flush_wb = csr_ertn_flush_wb_reg && wb_valid;
assign csr_wb_ex_wb = csr_wb_ex_wb_reg && wb_valid;
assign csr_wb_ecode_wb = csr_wb_ecode_wb_reg;
assign csr_wb_subecode_wb = csr_wb_subecode_wb_reg;
assign csr_pc_wb  = wb_pc;
assign csr_BADV_wb = csr_BADV_wb_reg;
assign tlb_refecth_wb = tlb_refecth_wb_reg && wb_valid;
assign tlb_invtlb_wb = tlb_invtlb_wb_reg && wb_valid;
assign tlb_tlbwr_wb = tlb_tlbwr_wb_reg && wb_valid;
assign tlb_tlbrd_wb = tlb_tlbrd_wb_reg && wb_valid;
assign tlb_tlbsrch_wb = tlb_tlbsrch_wb_reg && wb_valid;
assign tlb_tlbfill_wb = tlb_tlbfill_wb_reg && wb_valid;
assign wb_pc_to_csr = wb_pc;
assign EXC_IF_wb = EXC_IF_wb_reg;
/*// to exe
assign csr_wb_ex_wb_to_exe = csr_wb_ex_wb_reg;
assign csr_ertn_flush_wb_to_exe = csr_ertn_flush_wb_reg;*/

// debug info generate
/* answer
 * bug：debug_wb_rf_we拼写错误
 */
 
assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_we    = reg_file_wen_final;
assign debug_wb_rf_wnum  = dest_final;
assign debug_wb_rf_wdata = final_final_result;

// stall(read after write conflict)
assign gr_we_wb=(wb_valid)? gr_we:1'b0;
assign gr_we_wb_final = (csr_rd_we_wb_reg) ? (csr_rd_we_wb_reg && wb_valid) : gr_we_wb;
assign dest_wb=(wb_valid)? dest:5'b0;
assign dest_wb_final = (csr_rd_we_wb_reg && wb_valid) ? (csr_rd_wb_reg) : dest_wb;



assign forward_data_wb=(wb_valid)?final_final_result:32'b0;
endmodule
