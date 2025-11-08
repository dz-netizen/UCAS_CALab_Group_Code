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
	
	//to exe
	output	wire    mem_allowin,
	
	//from write back
	input	wire wb_allowin,
	
	//to write back
	output	wire mem_to_wb_valid,
	output	wire    [`MEM_TO_WB_BUS_WD-1:0]	mem_to_wb_bus,
	
	//data sram interface
	input	wire [31:0]	data_sram_rdata
);

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
wire	[31:0] alu_result;	//63ï¼?32
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

always @(posedge clk) begin
    if (reset) begin
        mem_valid <= 1'b0;
    end
    else if (mem_allowin) begin
        mem_valid <= exe_to_mem_valid;
    end

    if (exe_to_mem_valid && mem_allowin) begin
        mem_bus_reg <= exe_to_mem_bus;
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
assign dest_mem=(mem_valid)? dest:5'b0;
//forward
assign forward_data_mem=(mem_valid)?final_result:32'b0;

endmodule

