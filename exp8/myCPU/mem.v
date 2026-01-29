`include "mycpu.h"

module mem(
	input wire 	clk		,
	input wire 	reset  ,
	
	//to decode
	output wire gr_we_mem,
	output wire [4:0]  dest_mem,
	
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

reg	mem_valid;
wire	mem_ready_go;

reg	[`EXE_TO_MEM_BUS_WD-1:0]	mem_bus_reg;

wire	inst_ld_w;	//72
wire	inst_lu12i_w;	//71
wire	load_op;	//70
wire	gr_we;		//69
wire	[4:0] dest;		//68:64
wire	[31:0] alu_result;	//63ï¼?32
wire	[31:0] mem_pc	;	//31:0

assign	{
	inst_ld_w,
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

assign mem_result   = data_sram_rdata;
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

endmodule

