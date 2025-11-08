`include "mycpu.h"
module exe (
	input wire	clk,
	input wire	reset,
	
	//from decode
	input wire	dec_to_exe_valid,
	input wire	[`DEC_TO_EXE_BUS_WD-1:0]	decode_to_exe_bus,
	
	//to decode 
	output wire	exe_allowin,
    output wire exe_csr_re,
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
	output wire	[31:0]	data_sram_wdata,
	
    // exception 
    input  wire        mem_ex,
    input  wire        wb_ex,
    output wire        exe_ex
);

reg	    exe_valid;
wire	exe_ready_go;

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

wire    inst_st_b;
wire    inst_st_h;
wire    signed_option;
wire    inst_ld_b;
wire    inst_ld_bu;
wire    inst_ld_h;
wire    inst_ld_hu;
wire    inst_ld_w;

wire [31:0] exe_csr_wvalue;
wire        inst_ertn;
wire        inst_syscall;   
wire [13:0] exe_csr_num;
wire [31:0] exe_csr_wmask;
wire        exe_csr_we;
wire        exe_cur_csr_re;

assign {
    exe_cur_csr_re,     //217
    exe_csr_num,     //216:203
    exe_csr_we,     //202
    exe_csr_wmask,  //201:170
    inst_syscall,   //169
    inst_ertn,      //168
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




assign alu_src1 = src1_is_pc  ? exe_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;


wire dout_tvalid;

alu u_alu(
    .clk(clk),
    .reset(reset),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result),
    .dout_tvalid (dout_tvalid)
    );
 
assign data_sram_en	=1'b1;
assign data_sram_we    = {4{mem_we & exe_valid & ~wb_ex & ~mem_ex & ~inst_syscall}}&{
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
assign data_sram_addr  = alu_result;
assign data_sram_wdata = inst_st_b? {4{rkd_value[7:0]}}:
                         inst_st_h? {2{rkd_value[15:0]}}:
                         rkd_value[31:0];

assign	exe_ready_go=1'b1&(dout_tvalid);
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
assign inst_ld_w_forward_exe=(exe_valid)? load_op:1'b0;

assign exe_csr_wvalue=rkd_value;
assign exe_ex = inst_syscall & exe_valid;
assign exe_csr_re = (exe_valid)? exe_cur_csr_re:1'b0;
assign	exe_to_mem_bus={
    exe_cur_csr_re,     //159
    exe_csr_wvalue,  //158:127
    exe_csr_num,    //126:113
    exe_csr_we,     //112
    exe_csr_wmask,  //111:80
    inst_syscall,   //79
    inst_ertn,      //78
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
	alu_result,	//63:32
	exe_pc		//31:0
};

endmodule 
