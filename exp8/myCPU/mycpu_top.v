`include "mycpu.h" 

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output wire [3:0]  inst_sram_we,
    // data sram interface
    output wire        data_sram_en,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    output wire [3 :0] data_sram_we,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

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
	
	//to inst_decode
	.fetch_to_dec_valid(fetch_to_dec_valid),
	.fetch_to_decode_bus(fetch_to_decode_bus),
	
	//instruction sram interface
	.inst_sram_en	(inst_sram_en	),
	.inst_sram_we	(inst_sram_we	),
	.inst_sram_addr	(inst_sram_addr	),
	.inst_sram_rdata(inst_sram_rdata),
	.inst_sram_wdata(inst_sram_wdata)

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
	
	//to fetch 
	.dec_allowin	(dec_allowin	),
	.branch_bus	(branch_bus	),
	
	//from exe
	.exe_allowin	(exe_allowin	),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),
		
	//to exe
	.dec_to_exe_valid(dec_to_exe_valid),
	.dec_to_exe_bus	(decode_to_exe_bus),
	
    //from mem
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	
    //from write back
	.gr_we_wb(gr_we_wb),
	.dest_wb(dest_wb),	
		
	//to write back
	.wb_to_regfile_bus(wb_to_regfile_bus)
);

exe exe(
	.clk (clk),
	.reset(reset),
	
	//from decode
	.dec_to_exe_valid(dec_to_exe_valid),
	.decode_to_exe_bus(decode_to_exe_bus),
	
	//to decode 
	.exe_allowin(exe_allowin),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),	
	
	//from mem
	.mem_allowin(mem_allowin),
	
	//to mem
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus),
	
	//data sram interface
	.data_sram_en(data_sram_en),
	.data_sram_we(data_sram_we),
	.data_sram_addr(data_sram_addr),
	.data_sram_wdata(data_sram_wdata)
);

mem mem(
	.clk		(clk		),
	.reset		(reset		),

    //to decode
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
		
	//from exe
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus	),
	
	//to exe
	.mem_allowin	(mem_allowin),
	
	//from write back
	.wb_allowin	(wb_allowin),
	
	//to write back
	.mem_to_wb_valid(mem_to_wb_valid),
	.mem_to_wb_bus	(mem_to_wb_bus),
	
	//data sram interface
	.data_sram_rdata(data_sram_rdata)
);
wb wb(
	.clk		(clk		),
	.reset		(reset		),
	
    //to decode
	.gr_we_wb(gr_we_wb),
	.dest_wb(dest_wb),	
	
	//from mem
	.mem_to_wb_valid(mem_to_wb_valid),
	.mem_to_wb_bus	(mem_to_wb_bus	),
	
	//to mem
	.wb_allowin	(wb_allowin	),
	
	//to register file
	.wb_to_regfile_bus(wb_to_regfile_bus),
	
	    //trace debug interface
    .debug_wb_pc (debug_wb_pc)    ,
    .debug_wb_rf_we(debug_wb_rf_we) ,
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
    
);

endmodule

