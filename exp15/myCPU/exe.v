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

	//from wb
	input wire csr_wb_ex_wb,
	input wire csr_ertn_flush_wb,
	
	
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


	
	//data sram interface
	output wire	data_sram_req,
	output wire data_sram_wr,
	output wire [1:0] data_sram_size,
	output wire [3:0] data_sram_wstrb,
	output wire	[31:0]	data_sram_addr,
	output wire	[31:0]	data_sram_wdata,
	input  wire         data_sram_addr_ok
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

assign data_sram_req = ((mem_we || load_op) && exe_valid)&&mem_allowin;


assign data_sram_wr	= (mem_we & exe_valid) ? 1'b1 : 1'b0;
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
assign data_sram_wstrb = (csr_wb_ex_to_wb | csr_wb_ex_wb | csr_ertn_flush_to_wb | csr_ertn_flush_wb |csr_wb_ex_to_mem) ? 4'b0 : data_sram_we_before_csr;//find ex,stop store
assign data_sram_addr  = alu_result;
assign data_sram_wdata = inst_st_b? {4{rkd_value[7:0]}}:
                         inst_st_h? {2{rkd_value[15:0]}}:
                         rkd_value[31:0];

assign	exe_ready_go= (mem_we || load_op)&& exe_valid ? (data_sram_req && data_sram_addr_ok)&(dout_tvalid) : 1'b1&(dout_tvalid);
assign	exe_allowin=!exe_valid|(exe_ready_go&mem_allowin);
assign	exe_to_mem_valid=exe_valid&exe_ready_go;

always@(posedge clk)begin
	if(reset)begin
		exe_valid <=1'b0;
	end
	else if(csr_wb_ex_wb | csr_ertn_flush_wb)begin
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
assign csr_wb_ex_to_mem = (csr_wb_ex_to_exe_reg | ALE) && exe_valid;
assign csr_wb_ecode_to_mem = (csr_wb_ex_to_exe_reg) ? csr_wb_ecode_to_exe_reg : 
                              (ALE) ? 6'h9 :
							6'h0;
assign csr_wb_subecode_to_mem = (csr_wb_ex_to_exe_reg) ? csr_wb_subecode_to_exe_reg :
                                (ALE) ? 9'h0:
								9'h0;


assign ALE = ((ALE_h_to_exe_reg &&alu_result[0] != 1'b0) || (ALE_w_to_exe_reg && alu_result[1:0] != 2'b00)) && exe_valid;
assign csr_BADV_to_mem = alu_result;
assign alu_result_after_rdc = (rdcntv_to_exe_reg == 2'b01) ? stable_counter[31:0] :
                              (rdcntv_to_exe_reg == 2'b10) ? stable_counter[63:32] :
							  alu_result;
assign mem_we_to_mem = mem_we && exe_valid;
endmodule
