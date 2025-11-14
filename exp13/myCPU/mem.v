`include "mycpu.h"

module mem(
	input wire 	clk		,
	input wire 	reset  ,
	
	//to decode
	output wire gr_we_mem,
	output wire [4:0]  dest_mem,
	output wire [31:0] forward_data_mem,
	
	//from exe
	input  wire    	exe_to_mem_valid,
	input	wire [`EXE_TO_MEM_BUS_WD-1:0] exe_to_mem_bus	,
    input wire csr_rd_we_to_mem,
    input wire [4:0]  csr_rd_to_mem,
    input wire [13:0] csr_num_to_mem,
    input wire csr_csr_we_to_mem,
    input wire [31:0] csr_csr_wvalue_to_mem,
    input wire [31:0] csr_csr_wmask_to_mem,
    input wire csr_ertn_flush_to_mem,
    input wire csr_wb_ex_to_mem,
    input wire [5:0] csr_wb_ecode_to_mem,
    input wire [8:0] csr_wb_subecode_to_mem,
    input wire [31:0] csr_BADV_to_mem,
	
	//to exe
	output	wire    mem_allowin,
    /*output  wire    csr_wb_ex_to_wb_to_exe,
    output  wire    csr_ertn_flush_to_wb_to_exe,//block store,when reflush*/
	
	//from write back
	input	wire wb_allowin,
    input  wire csr_wb_ex_wb,
    input  wire csr_ertn_flush_wb,
    
	
	//to write back
	output	wire mem_to_wb_valid,
	output	wire    [`MEM_TO_WB_BUS_WD-1:0]	mem_to_wb_bus,
    output  wire csr_rd_we_to_wb,
    output wire [4:0] csr_rd_to_wb,
    output wire [13:0] csr_num_to_wb,
    output wire csr_csr_we_to_wb,
    output wire [31:0] csr_csr_wvalue_to_wb,
    output wire [31:0] csr_csr_wmask_to_wb,
    output wire  csr_ertn_flush_to_wb,
    output wire  csr_wb_ex_to_wb,
    output wire [5:0] csr_wb_ecode_to_wb,
    output wire [8:0] csr_wb_subecode_to_wb,
    output wire [31:0] csr_BADV_to_wb,
	
	//data sram interface
	input	wire [31:0]	data_sram_rdata
);
wire gr_we_mem_final;
wire [4:0]  dest_mem_final;

reg	    mem_valid;
wire	mem_ready_go;

reg	[`EXE_TO_MEM_BUS_WD-1:0]	mem_bus_reg;
   
wire    inst_ld_b;      
wire    inst_ld_bu;     
wire    inst_ld_h;     
wire    inst_ld_hu;     
wire    inst_ld_w;     
wire    signed_option;
wire	inst_lu12i_w;	//71
wire	load_op;	//70
wire	gr_we;		//69
wire	[4:0] dest;		//68:64
wire	[31:0] alu_result;	//63�?32
wire	[31:0] mem_pc	;	//31:0

assign	{
    inst_ld_b,      //77
    inst_ld_bu,     //76
    inst_ld_h,      //75
    inst_ld_hu,     //74
    inst_ld_w,      //73
    signed_option,
	inst_lu12i_w,
	load_op,
	gr_we,
	dest,
	alu_result,
	mem_pc
	}=mem_bus_reg;

wire [31:0] mem_result;
wire [31:0] final_result;
assign mem_ready_go=1'b1;
reg   [4:0] csr_rd_to_mem_reg;
reg  csr_rd_we_to_mem_reg;
reg   [13:0] csr_num_to_mem_reg;
reg  csr_csr_we_to_mem_reg;
reg  [31:0] csr_csr_wvalue_to_mem_reg;
reg  [31:0] csr_csr_wmask_to_mem_reg;
reg csr_ertn_flush_to_mem_reg;
reg csr_wb_ex_to_mem_reg;
reg [5:0] csr_wb_ecode_to_mem_reg;
reg [8:0] csr_wb_subecode_to_mem_reg;
reg [31:0] csr_BADV_to_mem_reg;


always @(posedge clk) begin
    if (reset) begin
        mem_valid <= 1'b0;
    end
    else if(csr_wb_ex_wb | csr_ertn_flush_wb)begin
        mem_valid <= 1'b0;
    end
    else if (mem_allowin) begin
        mem_valid <= exe_to_mem_valid;
    end
 end
always@(posedge clk)begin
    if(reset)begin
    mem_bus_reg <= 78'b0;
   end  

    else if (exe_to_mem_valid && mem_allowin) begin
        mem_bus_reg <= exe_to_mem_bus;
     
    end
end

always@(posedge clk)begin
    if(reset) begin
        csr_rd_to_mem_reg <= 5'b00000;
        csr_rd_we_to_mem_reg <= 1'b0;
        csr_num_to_mem_reg <= 14'b0;
        csr_csr_we_to_mem_reg <= 1'b0;
        csr_csr_wvalue_to_mem_reg <= 32'b0;
        csr_csr_wmask_to_mem_reg <= 32'b0;
        csr_ertn_flush_to_mem_reg <= 1'b0;
        csr_wb_ex_to_mem_reg <= 1'b0;
        csr_wb_ecode_to_mem_reg <= 6'b0;
        csr_wb_subecode_to_mem_reg <= 9'b0;
        csr_BADV_to_mem_reg <= 32'b0;
    end

    else if(exe_to_mem_valid && mem_allowin)begin
        csr_rd_to_mem_reg <= csr_rd_to_mem;
        csr_rd_we_to_mem_reg <= csr_rd_we_to_mem;
        csr_num_to_mem_reg <= csr_num_to_mem;
        csr_csr_we_to_mem_reg <= csr_csr_we_to_mem;
        csr_csr_wvalue_to_mem_reg <= csr_csr_wvalue_to_mem;
        csr_csr_wmask_to_mem_reg <= csr_csr_wmask_to_mem;
        csr_ertn_flush_to_mem_reg <= csr_ertn_flush_to_mem;
        csr_wb_ex_to_mem_reg <= csr_wb_ex_to_mem;
        csr_wb_ecode_to_mem_reg <= csr_wb_ecode_to_mem;
        csr_wb_subecode_to_mem_reg <= csr_wb_subecode_to_mem;
        csr_BADV_to_mem_reg <= csr_BADV_to_mem;
    end
end   

wire    [31:0] ld_b_result;
wire    [31:0] ld_bu_result;
wire    [31:0] ld_h_result;
wire    [31:0] ld_hu_result;

assign ld_b_result=(alu_result[1:0] ==2'b11)? {{24{data_sram_rdata[31]}},data_sram_rdata[31:24] }:
                   (alu_result[1:0] ==2'b10)? {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:
                   (alu_result[1:0] ==2'b01)? {{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:
                   {{24{data_sram_rdata[7]}},data_sram_rdata[7:0]};
assign ld_bu_result=(alu_result[1:0] ==2'b11)? {24'b0,data_sram_rdata[31:24] }:
                   (alu_result[1:0]==2'b10)? {24'b0,data_sram_rdata[23:16]}:
                   (alu_result[1:0] ==2'b01)? {24'b0,data_sram_rdata[15:8]}:
                   {24'b0,data_sram_rdata[7:0]};
assign ld_h_result=(alu_result[1] ==1'b1)? {{16{data_sram_rdata[31]}},data_sram_rdata[31:16] }:
                   {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]};
assign ld_hu_result=(alu_result[1] ==1'b1)? {16'b0,data_sram_rdata[31:16] }:
                   {16'b0,data_sram_rdata[15:0]};  
                                                      
assign mem_result   = ({32{inst_ld_b}}&ld_b_result)|
                      ({32{inst_ld_bu}}&ld_bu_result)|
                      ({32{inst_ld_h}}&ld_h_result)|
                      ({32{inst_ld_hu}}&ld_hu_result)|
                      ({32{inst_ld_w}}&data_sram_rdata);
                      
assign final_result = load_op ? mem_result : alu_result;
assign mem_allowin=!mem_valid|mem_ready_go & wb_allowin;

assign	mem_to_wb_bus={
    gr_we,      //69
	dest,		//68:64
	final_result,	//63:32
	mem_pc		//31:0
};
assign mem_to_wb_valid=mem_valid&mem_ready_go;

// hazard(read after write conflict)
assign gr_we_mem=(mem_valid)? gr_we:1'b0;
assign gr_we_mem_final = (csr_rd_we_to_mem_reg) ? (csr_rd_we_to_mem_reg && mem_valid) : gr_we_mem;
assign dest_mem=(mem_valid)? dest:5'b0;
assign dest_mem_final = (csr_rd_we_to_mem_reg && mem_valid) ? (csr_rd_to_mem_reg) : dest_mem;
//forward
assign forward_data_mem=(mem_valid)?final_result:32'b0;
//csr 
assign csr_rd_to_wb = csr_rd_to_mem_reg;
assign csr_rd_we_to_wb = (csr_rd_we_to_mem_reg) && mem_valid;
assign csr_num_to_wb  = csr_num_to_mem_reg;
assign csr_csr_we_to_wb = (csr_csr_we_to_mem_reg) && mem_valid;
assign csr_csr_wvalue_to_wb = csr_csr_wvalue_to_mem_reg;
assign csr_csr_wmask_to_wb = csr_csr_wmask_to_mem_reg;
assign csr_ertn_flush_to_wb = (csr_ertn_flush_to_mem_reg) && mem_valid;
assign csr_wb_ex_to_wb = (csr_wb_ex_to_mem_reg) && mem_valid;
assign csr_wb_ecode_to_wb = csr_wb_ecode_to_mem_reg;
assign csr_wb_subecode_to_wb = csr_wb_subecode_to_mem_reg;
assign csr_BADV_to_wb = csr_BADV_to_mem_reg;
/*
//to exe
assign csr_wb_ex_to_wb_to_exe = csr_wb_ex_to_mem_reg;
assign csr_ertn_flush_to_wb_to_exe = csr_ertn_flush_to_mem_reg;*/

endmodule

