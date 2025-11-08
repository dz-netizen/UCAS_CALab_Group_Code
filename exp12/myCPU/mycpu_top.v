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
wire    mem_ld;
wire    gr_we_exe;
wire    gr_we_mem;
wire    gr_we_wb;
wire    [4:0]   dest_exe;
wire    [4:0]   dest_mem;
wire    [4:0]   dest_wb;
wire    [31:0] forward_data_exe;
wire    inst_ld_w_forward_exe;
wire [31:0] forward_data_mem;
wire [31:0] forward_data_wb;

//-------------------- csr ---------------------------
    wire [13:0] csr_num;
    wire [31:0] csr_rvalue;
    wire        csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [31:0] ex_entry;
    wire [31:0] ertn_entry;
    wire        has_int;
    wire        ertn_flush;
    wire [ 5:0] wb_ecode;
    wire [ 8:0] wb_esubcode;
    wire [31:0] wb_pc;
    wire        dec_ex;
    wire        exe_ex;
    wire        mem_ex;
    wire        wb_ex;
    wire        mem_csr_re;
    wire        exe_csr_re;
    
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
	.inst_sram_wdata(inst_sram_wdata),
	
	//exception
	.dec_ex(dec_ex),
	.exe_ex(exe_ex),
	.mem_ex(mem_ex),
    .wb_ex(wb_ex),
    .ertn_flush(ertn_flush),
    .ex_entry(ex_entry),
    .ertn_entry(ertn_entry)

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
	.exe_csr_re (exe_csr_re),
	.exe_allowin	(exe_allowin	),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),
	.inst_ld_w_forward_exe(inst_ld_w_forward_exe),	
	.forward_data_exe(forward_data_exe),
	//to exe
	.dec_to_exe_valid(dec_to_exe_valid),
	.dec_to_exe_bus	(decode_to_exe_bus),
	
    //from mem
    .mem_ld(mem_ld),
    .mem_csr_re(mem_csr_re),
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	.forward_data_mem(forward_data_mem),
    //from write back
    .wb_csr_re(wb_csr_re),
	.gr_we_wb(gr_we_wb),
	.dest_wb(dest_wb),	
	//from write back
	.forward_data_wb(forward_data_wb),
	//to write back
	.wb_to_regfile_bus(wb_to_regfile_bus),
	
	//exception
	.dec_ex(dec_ex),
	.wb_ex(wb_ex|ertn_flush)
);

exe exe(
	.clk (clk),
	.reset(reset),
	
	//from decode
    .exe_csr_re (exe_csr_re),
	.dec_to_exe_valid(dec_to_exe_valid),
	.decode_to_exe_bus(decode_to_exe_bus),
	
	//to decode 
	.exe_allowin(exe_allowin),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),	
	.inst_ld_w_forward_exe(inst_ld_w_forward_exe),	
	.forward_data_exe(forward_data_exe),
	//from mem
	.mem_allowin(mem_allowin),
	
	//to mem
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus),
	
	//data sram interface
	.data_sram_en(data_sram_en),
	.data_sram_we(data_sram_we),
	.data_sram_addr(data_sram_addr),
	.data_sram_wdata(data_sram_wdata),
	
	//exception
	.exe_ex(exe_ex),
    .mem_ex(mem_ex),
    .wb_ex(wb_ex|ertn_flush)
);

mem mem(
	.clk		(clk		),
	.reset		(reset		),

    //to decode
    .mem_ld(mem_ld),
    .mem_csr_re(mem_csr_re),
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	.forward_data_mem(forward_data_mem),	
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
	.data_sram_rdata(data_sram_rdata),
	
	//exception
	.mem_ex(mem_ex),
    .wb_ex(wb_ex|ertn_flush)
);
wb wb(
	.clk		(clk		),
	.reset		(reset		),
	
    //to decode
    .wb_csr_re(wb_csr_re),
	.gr_we_wb(gr_we_wb),
	.dest_wb(dest_wb),	
	.forward_data_wb(forward_data_wb),
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
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    
	//exception
    .csr_num    (csr_num   ),
    .csr_rvalue (csr_rvalue),
    .csr_we     (csr_we    ),
    .csr_wmask  (csr_wmask ),
    .csr_wvalue (csr_wvalue),
    .ertn_flush (ertn_flush),
    .wb_ex      (wb_ex     ),
    .wb_pc      (wb_pc     ),
    .wb_ecode   (wb_ecode  ),
    .wb_esubcode(wb_esubcode)    
    
);

    csr csr(
        .clk        (clk       ),
        .reset      (reset   ),
        .csr_num    (csr_num   ),
        .csr_rvalue (csr_rvalue),
        .csr_we     (csr_we    ),
        .csr_wmask  (csr_wmask ),
        .csr_wvalue (csr_wvalue),

        .has_int    (has_int   ),
        .ex_entry   (ex_entry  ),
        .ertn_entry (ertn_entry),
        .ertn_flush (ertn_flush),
        .wb_ex      (wb_ex     ),
        .wb_pc      (wb_pc     ),
        .wb_ecode   (wb_ecode  ),
        .wb_esubcode(wb_esubcode)
    );
    
endmodule

