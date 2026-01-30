`include "mycpu.h" 
module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
	output wire        inst_sram_wr,
	output wire [1:0]  inst_sram_size,
	output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
	input  wire 	   inst_sram_addr_ok,
	input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    input  wire [ 3:0]  arid,   
    // data sram interface
    output wire        data_sram_req,
	output wire        data_sram_wr,
	output wire [1:0]  data_sram_size,
	output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
	input  wire        data_sram_addr_ok,
	input  wire        data_sram_data_ok,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;
reg      [63:0]   stable_counter;
reg      [3:0]    data_sram_counter;
always@(posedge clk)begin
	if(reset)
	data_sram_counter <= 4'b0;
	else if(data_sram_req &&data_sram_addr_ok&& (~data_sram_data_ok))
	data_sram_counter <= data_sram_counter + 1'b1;
    else if(~data_sram_req & data_sram_addr_ok )
    data_sram_counter <= data_sram_counter + 1'b1;
	else if(data_sram_data_ok&&(~data_sram_req ||  ~data_sram_addr_ok))
	data_sram_counter <= data_sram_counter - 1'b1;
end
always@(posedge clk)begin
	if(reset)
	stable_counter <= 64'b0;
	else if(stable_counter != 64'hffffffffffffffff)
	stable_counter <= stable_counter + 1'b1;
	else if(stable_counter == 64'hffffffffffffffff)
    stable_counter <= 64'b0;
end

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
wire    [31:0] forward_data_exe;
wire    inst_ld_w_forward_exe;
wire [31:0] forward_data_mem;
wire [31:0] forward_data_wb;


//from csr_control to IF
wire csr_is_branch;
wire [31:0] csr_pc_if;

//if
wire ADEF_to_ID;

//decode
wire csr_rd_we_to_exe;
wire [13:0] csr_num_to_exe;
wire [4:0] csr_rd_to_exe;
wire csr_csr_we_to_exe;
wire [31:0] csr_csr_wvalue_to_exe;
wire csr_ertn_flush_to_exe;
wire csr_wb_ex_to_exe;
wire [5:0] csr_wb_ecode_to_exe;
wire [8:0] csr_wb_subecode_to_exe;
wire [31:0] csr_csr_wmask_to_exe;
wire ALE_h_to_exe;
wire ALE_w_to_exe;
wire [1:0] rdcntv_to_exe;
//exe
wire csr_rd_we_to_mem;
wire [13:0] csr_num_to_mem;
wire [4:0]  csr_rd_to_mem;
wire csr_csr_we_to_mem;
wire [31:0] csr_csr_wvalue_to_mem;
wire [31:0] csr_csr_wmask_to_mem;
wire  csr_ertn_flush_to_mem;
wire csr_wb_ex_to_mem;
wire [5:0] csr_wb_ecode_to_mem;
wire [8:0] csr_wb_subecode_to_mem;
wire [31:0] csr_BADV_to_mem;
wire mem_we_to_mem;
//mem
wire csr_rd_we_to_wb;
wire [4:0]  csr_rd_to_wb;
wire [13:0] csr_num_to_wb;
wire  csr_csr_we_to_wb;
wire  [31:0] csr_csr_wvalue_to_wb;
wire  csr_ertn_flush_to_wb;
wire  [31:0] csr_csr_wmask_to_wb;
wire  csr_wb_ex_to_wb;
wire [5:0] csr_wb_ecode_to_wb;
wire [8:0] csr_wb_subecode_to_wb;
wire [31:0] csr_BADV_to_wb;
wire  load_block_mem;


//wb
wire [13:0] csr_num_wb;
wire csr_rd_we_wb;
wire csr_csr_we_wb;
wire [31:0] csr_csr_wvalue_wb;
wire [31:0] csr_csr_wmask_wb;
wire csr_ertn_flush_wb;
wire csr_wb_ex_wb;
wire [5:0] csr_wb_ecode_wb;
wire [8:0] csr_wb_subecode_wb;
wire [31:0] csr_pc_wb;
wire [31:0] csr_BADV_wb;

//csr_control
wire [31:0] csr_rd_value;
wire has_int;


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
	
	//from csr_control
	.csr_is_branch(csr_is_branch),
	.csr_pc_if(csr_pc_if),
	
	//to inst_decode
	.fetch_to_dec_valid(fetch_to_dec_valid),
	.fetch_to_decode_bus(fetch_to_decode_bus),
	.ADEF_to_ID(ADEF_to_ID),
	//from exe
	.csr_wb_ex_to_mem(csr_wb_ex_to_mem),
	// from mem
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	//instruction sram interface
	.inst_sram_req	(inst_sram_req	),
	.inst_sram_wr	(inst_sram_wr	),
	.inst_sram_size(inst_sram_size),
	.inst_sram_wstrb(inst_sram_wstrb),
	.inst_sram_addr	(inst_sram_addr	),
	.inst_sram_rdata(inst_sram_rdata),
	.inst_sram_wdata(inst_sram_wdata),
	.inst_sram_addr_ok(inst_sram_addr_ok),
	.inst_sram_data_ok(inst_sram_data_ok),
    .arid(arid)
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
	.ADEF_to_ID(ADEF_to_ID),
	
	//to fetch 
	.dec_allowin	(dec_allowin	),
	.branch_bus	(branch_bus	),
	
	//from exe
	.exe_allowin	(exe_allowin	),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),
	.inst_ld_w_forward_exe(inst_ld_w_forward_exe),	
	.forward_data_exe(forward_data_exe),
	.csr_rd_we_to_mem(csr_rd_we_to_mem),
	.csr_rd_to_mem(csr_rd_to_mem),
	.csr_num_to_mem(csr_num_to_mem),
	.csr_csr_we_to_mem(csr_csr_we_to_mem),
	.csr_ertn_flush_to_mem(csr_ertn_flush_to_mem),
	//to exe
	.dec_to_exe_valid(dec_to_exe_valid),
	.dec_to_exe_bus	(decode_to_exe_bus),
	.csr_rd_we_to_exe(csr_rd_we_to_exe),
	.csr_num_to_exe(csr_num_to_exe),
	.csr_rd_to_exe(csr_rd_to_exe),
	.csr_csr_we_to_exe(csr_csr_we_to_exe),
	.csr_csr_wvalue_to_exe(csr_csr_wvalue_to_exe),
	.csr_csr_wmask_to_exe(csr_csr_wmask_to_exe),
	.csr_ertn_flush_to_exe(csr_ertn_flush_to_exe),
	.csr_wb_ex_to_exe(csr_wb_ex_to_exe),
	.csr_wb_ecode_to_exe(csr_wb_ecode_to_exe),
	.csr_wb_subecode_to_exe(csr_wb_subecode_to_exe),
	.ALE_h_to_exe(ALE_h_to_exe),
	.ALE_w_to_exe(ALE_w_to_exe),
	.rdcntv_to_exe(rdcntv_to_exe),
	
    //from mem
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	.forward_data_mem(forward_data_mem),
	.csr_rd_we_to_wb(csr_rd_we_to_wb),
	.csr_rd_to_wb(csr_rd_to_wb),
	.csr_num_to_wb(csr_num_to_wb),
	.csr_csr_we_to_wb(csr_csr_we_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.load_block_mem(load_block_mem),
    //from write back
	.gr_we_wb(gr_we_wb),
	.dest_wb(dest_wb),	
	//from write back
	.forward_data_wb(forward_data_wb),
	.wb_to_regfile_bus(wb_to_regfile_bus),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.csr_rd_we_wb(csr_rd_we_wb),
	.csr_num_wb(csr_num_wb),
	.csr_csr_we_wb(csr_csr_we_wb),
	.has_int(has_int)
);

exe exe(
	.clk (clk),
	.reset(reset),
	.stable_counter(stable_counter),
	
	//from decode
	.dec_to_exe_valid(dec_to_exe_valid),
	.decode_to_exe_bus(decode_to_exe_bus),
	.csr_rd_we_to_exe(csr_rd_we_to_exe),
	.csr_num_to_exe(csr_num_to_exe),
	.csr_rd_to_exe(csr_rd_to_exe),
	.csr_csr_we_to_exe(csr_csr_we_to_exe),
	.csr_csr_wvalue_to_exe(csr_csr_wvalue_to_exe),
	.csr_csr_wmask_to_exe(csr_csr_wmask_to_exe),
	.csr_ertn_flush_to_exe(csr_ertn_flush_to_exe),
	.csr_wb_ex_to_exe(csr_wb_ex_to_exe),
	.csr_wb_ecode_to_exe(csr_wb_ecode_to_exe),
	.csr_wb_subecode_to_exe(csr_wb_subecode_to_exe),
	.ALE_h_to_exe(ALE_h_to_exe),
	.ALE_w_to_exe(ALE_w_to_exe),
	.rdcntv_to_exe(rdcntv_to_exe),
	
	//to decode 
	.exe_allowin(exe_allowin),
    .gr_we_exe(gr_we_exe),
	.dest_exe(dest_exe),	
	.inst_ld_w_forward_exe(inst_ld_w_forward_exe),	
	.forward_data_exe(forward_data_exe),
	//from mem
	.mem_allowin(mem_allowin),
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),

	//from wb
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	
	//to mem
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus),
	.csr_rd_we_to_mem(csr_rd_we_to_mem),
	.csr_num_to_mem(csr_num_to_mem),
	.csr_rd_to_mem(csr_rd_to_mem),
	.csr_csr_we_to_mem(csr_csr_we_to_mem),
	.csr_csr_wvalue_to_mem(csr_csr_wvalue_to_mem),
	.csr_csr_wmask_to_mem(csr_csr_wmask_to_mem),
	.csr_ertn_flush_to_mem(csr_ertn_flush_to_mem),
	.csr_wb_ex_to_mem(csr_wb_ex_to_mem),
	.csr_wb_ecode_to_mem(csr_wb_ecode_to_mem),
	.csr_wb_subecode_to_mem(csr_wb_subecode_to_mem),
	.csr_BADV_to_mem(csr_BADV_to_mem),
	.mem_we_to_mem(mem_we_to_mem),
	
	//data sram interface
	.data_sram_req(data_sram_req),
	.data_sram_wr(data_sram_wr),
	.data_sram_size(data_sram_size),
	.data_sram_wstrb(data_sram_wstrb),
	.data_sram_addr(data_sram_addr),
	.data_sram_wdata(data_sram_wdata),
	.data_sram_addr_ok(data_sram_addr_ok)
);

mem mem(
	.clk		(clk		),
	.reset		(reset		),

    //to decode
    .gr_we_mem(gr_we_mem),
	.dest_mem(dest_mem),
	.forward_data_mem(forward_data_mem),
	.load_block_mem(load_block_mem),	
	//from exe
	.exe_to_mem_valid(exe_to_mem_valid),
	.exe_to_mem_bus	(exe_to_mem_bus	),
	.csr_rd_we_to_mem(csr_rd_we_to_mem),
	.csr_rd_to_mem(csr_rd_to_mem),
	.csr_num_to_mem(csr_num_to_mem),
	.csr_csr_we_to_mem(csr_csr_we_to_mem),
	.csr_csr_wvalue_to_mem(csr_csr_wvalue_to_mem),
	.csr_csr_wmask_to_mem(csr_csr_wmask_to_mem),
	.csr_ertn_flush_to_mem(csr_ertn_flush_to_mem),
	.csr_wb_ex_to_mem(csr_wb_ex_to_mem),
	.csr_wb_ecode_to_mem(csr_wb_ecode_to_mem),
	.csr_wb_subecode_to_mem(csr_wb_subecode_to_mem),
	.csr_BADV_to_mem(csr_BADV_to_mem),
	.mem_we_to_mem(mem_we_to_mem),
	
	//to exe
	.mem_allowin	(mem_allowin),
	
	//from write back
	.wb_allowin	(wb_allowin),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	
	//to write back
	.mem_to_wb_valid(mem_to_wb_valid),
	.mem_to_wb_bus	(mem_to_wb_bus),
	.csr_rd_we_to_wb(csr_rd_we_to_wb),
	.csr_rd_to_wb(csr_rd_to_wb),
	.csr_num_to_wb(csr_num_to_wb),
	.csr_csr_we_to_wb(csr_csr_we_to_wb),
	.csr_csr_wvalue_to_wb(csr_csr_wvalue_to_wb),
	.csr_csr_wmask_to_wb(csr_csr_wmask_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	.csr_wb_ecode_to_wb(csr_wb_ecode_to_wb),
	.csr_wb_subecode_to_wb(csr_wb_subecode_to_wb),
	.csr_BADV_to_wb(csr_BADV_to_wb),
	
	//data sram interface
	.data_sram_rdata(data_sram_rdata),
	.data_sram_data_ok(data_sram_data_ok),
	.data_sram_counter(data_sram_counter)
);
wb wb(
	.clk		(clk		),
	.reset		(reset		),
	
    //to decode
	.gr_we_wb_final(gr_we_wb),
	.dest_wb_final(dest_wb),	
	.forward_data_wb(forward_data_wb),
	//from mem
	.mem_to_wb_valid(mem_to_wb_valid),
	.mem_to_wb_bus	(mem_to_wb_bus	),
	.csr_num_to_wb(csr_num_to_wb),
	.csr_rd_to_wb(csr_rd_to_wb),
	.csr_rd_we_to_wb(csr_rd_we_to_wb),
	.csr_csr_we_to_wb(csr_csr_we_to_wb),
	.csr_csr_wvalue_to_wb(csr_csr_wvalue_to_wb),
	.csr_csr_wmask_to_wb(csr_csr_wmask_to_wb),
	.csr_ertn_flush_to_wb(csr_ertn_flush_to_wb),
	.csr_wb_ex_to_wb(csr_wb_ex_to_wb),
	.csr_wb_ecode_to_wb(csr_wb_ecode_to_wb),
	.csr_wb_subecode_to_wb(csr_wb_subecode_to_wb),
	.csr_BADV_to_wb(csr_BADV_to_wb),

	//from csr_control
	.csr_rd_value(csr_rd_value),
	
	//to mem
	.wb_allowin	(wb_allowin	),
	
	//to register file
	.wb_to_regfile_bus(wb_to_regfile_bus),
	
	    //trace debug interface
    .debug_wb_pc (debug_wb_pc)    ,
    .debug_wb_rf_we(debug_wb_rf_we) ,
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

	//to csr_control
	.csr_num_wb(csr_num_wb),
	.csr_rd_we_wb(csr_rd_we_wb),
	.csr_csr_we_wb(csr_csr_we_wb),
	.csr_csr_wvalue_wb(csr_csr_wvalue_wb),
	.csr_csr_wmask_wb(csr_csr_wmask_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_wb_ecode_wb(csr_wb_ecode_wb),
	.csr_wb_subecode_wb(csr_wb_subecode_wb),
	.csr_pc_wb(csr_pc_wb),
	.csr_BADV_wb(csr_BADV_wb)
    
);
csr_control csr_control(
	.clk(clk),
	.reset(reset),
	.csr_num_wb(csr_num_wb),
	.csr_rd_we_wb(csr_rd_we_wb),
	.csr_csr_wvalue_wb(csr_csr_wvalue_wb),
	.csr_csr_we_wb(csr_csr_we_wb),
	.csr_csr_wmask_wb(csr_csr_wmask_wb),
	.csr_wb_ex_wb(csr_wb_ex_wb),
	.csr_ertn_flush_wb(csr_ertn_flush_wb),
	.csr_wb_ecode_wb(csr_wb_ecode_wb),
	.csr_wb_subecode_wb(csr_wb_subecode_wb),
	.csr_pc_wb(csr_pc_wb),
	.csr_BADV_wb(csr_BADV_wb),

	.csr_rd_value(csr_rd_value),
	.csr_is_branch(csr_is_branch),
	.csr_pc_if(csr_pc_if),
	.has_int(has_int)

);

endmodule

