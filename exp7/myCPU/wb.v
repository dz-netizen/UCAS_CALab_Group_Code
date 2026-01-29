`include "mycpu.h"
module	wb(
	input wire	clk,
	input wire	reset,
	
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
    output wire [31:0] debug_wb_rf_wdata
);

reg	wb_valid;
wire	wb_ready_go;

reg	[`MEM_TO_WB_BUS_WD-1:0]	wb_bus_reg;

wire	[4:0]	dest;
wire	[31:0]	final_result;
wire	[31:0]	wb_pc;
wire    gr_we;

assign	{   gr_we,
            dest,
            final_result,
            wb_pc   }=wb_bus_reg;

wire	[3:0] reg_file_wen;
assign	reg_file_wen={4{wb_valid&gr_we}};

assign	wb_to_regfile_bus={
	reg_file_wen,	//40:37
	dest,		//36:32
	final_result	//31:0
};

assign	wb_ready_go=1'b1;
assign	wb_allowin=!wb_valid|wb_ready_go;
always@(posedge clk)begin
	if(reset)begin
		wb_valid<=1'b0;
	end
	else if(wb_allowin)begin
		wb_valid<=mem_to_wb_valid;
	end
	if(mem_to_wb_valid&wb_allowin)begin
		wb_bus_reg<=mem_to_wb_bus;
	end

end
// debug info generate
/* answer
 * bug：debug_wb_rf_we拼写错误
 */
 
assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_we    = reg_file_wen;
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;


endmodule
