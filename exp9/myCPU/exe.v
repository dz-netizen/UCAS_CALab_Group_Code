`include "mycpu.h"
module exe (
	input wire	clk,
	input wire	reset,
	
	//from decode
	input wire	dec_to_exe_valid,
	input wire	[`DEC_TO_EXE_BUS_WD-1:0]	decode_to_exe_bus,
	
	//to decode 
	output wire	exe_allowin,
	//forward
	output wire gr_we_exe,
	output wire inst_ld_w_forward_exe,
	output wire [4:0]  dest_exe,	
	output wire [31:0] forward_data_exe,
	
	//from mem
	input wire	mem_allowin,
	
	//to mem
	output wire	exe_to_mem_valid,
	output wire	[`EXE_TO_MEM_BUS_WD-1:0]exe_to_mem_bus,

	
	//data sram interface
	output wire	data_sram_en,
	output wire	[3:0]	data_sram_we,
	output wire	[31:0]	data_sram_addr,
	output wire	[31:0]	data_sram_wdata
);

reg	    exe_valid;
wire	exe_ready_go;

reg	[`DEC_TO_EXE_BUS_WD-1:0]	exe_bus_reg;
wire	inst_ld_w;	//137
wire	inst_lu12i_w;	//136
wire	inst_st_w;	//135
wire	[11:0] alu_op;	//134:123
wire	load_op;	//122
wire	src1_is_pc;//121
wire	src2_is_imm;	//120
wire	src2_is_4;	//119
wire	gr_we;		//118
wire	mem_we;		//117
wire	[4:0] dest;		//116:112
wire	[31:0] imm;		//111:96
wire	[31:0] rj_value;	//95:64
wire	[31:0] rkd_value;	//63:32
wire	[31:0] exe_pc;	//31:0




assign {
	inst_ld_w,	//137
	inst_lu12i_w,	//136
	inst_st_w,	//135
	alu_op,		//134:123
	load_op,	//122
	src1_is_pc,	//121
	src2_is_imm,	//120
	src2_is_4,	//119
	gr_we,		//118
	mem_we,		//117
	dest,		//116:112
	imm,		//111:96
	rj_value,	//95:64
	rkd_value,	//63:32
	exe_pc	//31:0
	}=exe_bus_reg;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

/* answer
 * bug：final_result未定�?
 */


assign alu_src1 = src1_is_pc  ? exe_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

/* answer
 * bug：alu_src1连接错误
 */

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );


assign	exe_to_mem_bus={
	inst_ld_w,	//72
	inst_lu12i_w,	//71
	load_op,	//70
	gr_we,		//69
	dest,		//68:64
	alu_result,	//63�?32
	exe_pc		//31:0
};

assign data_sram_en	=1'b1;
assign data_sram_we    = {4{mem_we & exe_valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign	exe_ready_go=1'b1;
assign	exe_allowin=!exe_valid|exe_ready_go&mem_allowin;
assign	exe_to_mem_valid=exe_valid&exe_ready_go;

always@(posedge clk)begin
	if(reset)begin
		exe_valid=1'b0;
	end
	else if(exe_allowin)begin
		exe_valid=dec_to_exe_valid;
	end
	if(dec_to_exe_valid&exe_allowin)begin
		exe_bus_reg=decode_to_exe_bus;
	end
end

// hazard(read after write conflict)
assign gr_we_exe=(exe_valid)? gr_we:1'b0;
assign dest_exe=(exe_valid)? dest:5'b0;
//forward
assign forward_data_exe=(exe_valid)?alu_result:32'b0;
assign inst_ld_w_forward_exe=(exe_valid)? inst_ld_w:1'b0;
endmodule 
