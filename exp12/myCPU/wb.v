`include "mycpu.h"
module	wb(
	input wire	clk,
	input wire	reset,
	
	//to decode
	output wire wb_csr_re,
	output wire gr_we_wb,
	output wire [4:0]  dest_wb,
	output wire [31:0] forward_data_wb,	
	//from mem
	input wire	mem_to_wb_valid,
	input wire	[`MEM_TO_WB_BUS_WD-1:0]	mem_to_wb_bus,
	
	//to mem
	output wire	wb_allowin,
	
	//to register file
	output wire	[`WB_TO_REGFILE_BUS_WD-1:0] wb_to_regfile_bus,
    //trace debug interface
    output wire [31:0] debug_wb_pc     ,
    output wire [ 3:0] debug_wb_rf_we ,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    
    // wb and csr interface
    output  wire     [13:0] csr_num,
    input   wire     [31:0] csr_rvalue,
    output  wire     csr_we,
    output  wire     [31:0] csr_wmask,
    output  wire     [31:0] csr_wvalue,
    output  wire     ertn_flush,
    output  wire     wb_ex,
    output  wire     [31:0] wb_pc,
    output  wire     [ 5:0] wb_ecode,
    output  wire     [ 8:0] wb_esubcode
);

reg	    wb_valid;
wire	wb_ready_go;

reg	[`MEM_TO_WB_BUS_WD-1:0]	wb_bus_reg;

wire	[4:0]	dest;
wire	[31:0]	mem_final_result;
wire    gr_we;
wire    load_op;

wire [31:0] wb_csr_wvalue;
wire        inst_ertn;
wire        inst_syscall;   
wire        wb_cur_csr_re;
wire [13:0] wb_csr_num;
wire [31:0] wb_csr_wmask;
wire [31:0] final_result;
wire        wb_csr_we;

assign	{   
    wb_cur_csr_re,     //151
    wb_csr_wvalue,  //150:119
    wb_csr_num,    //116:105
    wb_csr_we,     //104
    wb_csr_wmask,  //103:72
    inst_syscall,   //71
    inst_ertn,      //70
    gr_we,
    dest,
    mem_final_result,
    wb_pc   }=wb_bus_reg;

wire	[3:0] reg_file_wen;
assign	reg_file_wen={4{wb_valid&gr_we}};

assign	wb_ready_go=1'b1;
assign	wb_allowin=!wb_valid|wb_ready_go;
always@(posedge clk)begin
	if(reset)begin
		wb_valid<=1'b0;
	end
	else if(wb_ex|ertn_flush)begin
	    wb_valid<=1'b0;
	end
	else if(wb_allowin)begin
		wb_valid<=mem_to_wb_valid;
	end
	if(mem_to_wb_valid&wb_allowin)begin
		wb_bus_reg<=mem_to_wb_bus;
	end
end


// stall(read after write conflict)
assign gr_we_wb=(wb_valid)? gr_we:1'b0;
assign dest_wb=(wb_valid)? dest:5'b0;

assign forward_data_wb=(wb_valid)? final_result:32'b0;

//------------------------ wb and csr interface -----------------------------------
assign csr_num      = wb_csr_num & {14{wb_valid}};
assign csr_wmask    = wb_csr_wmask   & {32{wb_valid}};
assign csr_wvalue   = wb_csr_wvalue & {32{wb_valid}};
assign wb_ex        = inst_syscall & wb_valid;
assign ertn_flush   = inst_ertn & wb_valid;
assign csr_we       = wb_csr_we & wb_valid;
assign wb_ecode = {6{wb_ex}} & 6'hb;
assign wb_esubcode = 9'b0;

assign wb_csr_re=(wb_valid)? wb_cur_csr_re:1'b0;

//----------------------------- wb and register file ---------------------------------------
assign final_result = ( wb_cur_csr_re & wb_valid )? csr_rvalue:mem_final_result;
assign	wb_to_regfile_bus={
	reg_file_wen,	//40:37
	dest,		//36:32
	final_result	//31:0
};

//------------------------------trace debug interface---------------------------------------
assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_we    = reg_file_wen;
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;

endmodule
