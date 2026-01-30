`include "mycpu.h"
module inst_decode(
	input wire		clk		,
	input wire		reset		,
	
	//from fecth
	input wire	fetch_to_dec_valid,
 	input wire [`FETCH_TO_DEC_BUS_WD-1:0]	fetch_to_decode_bus,
    input wire  ADEF_to_ID,
    input wire  TLBREFILL_to_ID,
    input wire  IFTLBINVALID_to_ID,
    input wire  IFTLBPOWER_to_ID,
    input wire   EXC_IF_to_ID,
	
	//to fetch 
	output wire		dec_allowin	,
	output wire [`BR_BUS_WD-1:0]	branch_bus,
    //from exe
    input wire gr_we_exe,
	input   wire [4:0]  dest_exe,
	input	wire	exe_allowin,
	input wire [31:0] forward_data_exe,
	input wire inst_ld_w_forward_exe,
    input wire csr_rd_we_to_mem,
    input wire [4:0] csr_rd_to_mem,
    input wire [13:0] csr_num_to_mem,
    input wire csr_csr_we_to_mem,
    input wire csr_ertn_flush_to_mem,
    input wire tlb_tlbrd_to_mem,


	//to exe
	output	wire 	dec_to_exe_valid,
	output	wire [`DEC_TO_EXE_BUS_WD-1:0] dec_to_exe_bus	,
    output  wire    csr_rd_we_to_exe,
    output  wire  [13:0]  csr_num_to_exe,
    output  wire  [4:0]   csr_rd_to_exe,
    output  wire    csr_csr_we_to_exe,
    output wire   [31:0] csr_csr_wvalue_to_exe, 
    output wire   [31:0] csr_csr_wmask_to_exe,
    output wire   csr_ertn_flush_to_exe,	
    output wire   csr_wb_ex_to_exe,
    output wire   [5:0] csr_wb_ecode_to_exe,
    output wire   [8:0] csr_wb_subecode_to_exe,	
    output wire   ALE_h_to_exe,
    output wire   ALE_w_to_exe,
    output wire   [1:0] rdcntv_to_exe,//00:nothing,01:l,10:h  
    output wire   tlb_tlbsrch_to_exe,
    output wire   tlb_tlbrd_to_exe,
    output wire   tlb_tlbwr_to_exe,
    output wire   tlb_tlbfill_to_exe,
    output wire   tlb_invtlb_to_exe,
    output wire   tlb_refecth_to_exe,
    output wire   [4:0] tlb_invtlb_op_to_exe,
    output wire   [31:0] tlb_invtlb_rj_value_to_exe,
    output wire   [31:0] tlb_invtlb_rk_value_to_exe,
    // CACOP
    output wire          cacop_to_exe,
    output wire   [4:0]  cacop_code_to_exe,
    output wire   EXC_IF_to_exe,
    //from mem
    input wire gr_we_mem,
	input wire [4:0]  dest_mem,
	input wire [31:0] forward_data_mem,
    input wire csr_rd_we_to_wb,
    input wire [4:0] csr_rd_to_wb,
    input wire [13:0] csr_num_to_wb,
    input wire  csr_csr_we_to_wb,
    input wire  csr_ertn_flush_to_wb,
    input wire load_block_mem,
    input wire tlb_tlbrd_to_wb,

    //from write back
	input wire gr_we_wb,
	input wire [4:0]  dest_wb,		
	input wire [31:0] forward_data_wb,
	input wire [`WB_TO_REGFILE_BUS_WD-1:0] wb_to_regfile_bus,
    input wire csr_wb_ex_wb,
    input wire csr_ertn_flush_wb,
    input wire csr_rd_we_wb,
    input wire [13:0] csr_num_wb,
    input wire csr_csr_we_wb,
    input wire tlb_tlbrd_wb,
    input wire tlb_refecth_wb,

    //from csr
    input wire has_int
);

reg	    decode_valid;
wire	decode_ready_go;
wire    decode_ready_go_before_csr;

wire	[31:0]	dec_pc;
reg	[`FETCH_TO_DEC_BUS_WD-1:0] decode_bus_reg;
reg ADEF_to_ID_reg;
reg TLBREFILL_to_ID_reg;
reg IFTLBINVALID_to_ID_reg;
reg IFTLBPOWER_to_ID_reg;
reg EXC_IF_to_ID_reg;
wire INE;
wire	[31:0]	dec_inst;

assign	{dec_inst,dec_pc}=decode_bus_reg;

//Register File
wire	[3:0]	rf_we;
wire	[4:0]	rf_waddr;
wire	[31:0]	rf_wdata;

assign	{
	rf_we,	//40:37
	rf_waddr,	//36:32
	rf_wdata	//31:0
	}=wb_to_regfile_bus;

wire	br_taken;

// Branch decision is made in ID, but IF redirect must not happen unless
// the branch/jump instruction can actually transfer to EXE.
wire	br_taken_raw;
wire	[31:0]	br_target;

wire [18:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [ 7:0] op_31_24_d;
wire [ 4:0] op_9_5_d;


wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_pcaddu12i;

wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;

wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;
wire        inst_break;
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_rdcntid_w;

wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;

wire        signed_option;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;

wire        inst_st_b;
wire        inst_st_h; 

wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

wire        inst_cacop;

wire        need_ui5;
wire        need_si12;
wire        need_ui12;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;


wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire	rj_eq_rd;
wire    rj_ge_rd;
wire    rj_geu_rd;


assign	branch_bus={
	br_taken, //32
	br_target //31:0
	};
assign dec_to_exe_bus={
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
	src2_is_imm,//136
	src2_is_4,	//135
	gr_we,		//134
	mem_we,		//133
	dest,		//132:128
	imm,		//127:96
	rj_value,	//95:64
	rkd_value,	//63:32
	dec_pc	//31:0
};

assign  load_op=inst_ld_w|inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu;
assign  signed_option=inst_ld_b|inst_ld_h;

assign  decode_ready_go_before_csr=~(inst_ld_w_forward_exe&
                            (
                                (
                                    (inst_addi_w|inst_pcaddu12i|inst_slti|inst_sltui|load_op|inst_jirl|inst_slli_w|inst_srli_w|inst_srai_w|inst_cacop)&
                                    (rf_raddr1 ==dest_exe)
                                )|
                                (
                                    !(inst_b|inst_bl|inst_lu12i_w)&
                                    (rf_raddr1==dest_exe|rf_raddr2==dest_exe)
                                )
                            )
                        );
assign decode_ready_go = decode_ready_go_before_csr & !(csr_rd_we_to_mem&&rf_raddr1 == csr_rd_to_mem)&!(csr_rd_we_to_mem && rf_raddr2 == csr_rd_to_mem) & !(csr_rd_we_to_wb&& rf_raddr1 == csr_rd_to_wb) & !(csr_rd_we_to_wb && rf_raddr2 == csr_rd_to_wb)&!(csr_csr_we_to_mem && (csr_num_to_mem == 14'h0|| csr_num_to_mem == 14'h4 ||  csr_num_to_mem == 14'h5 || csr_num_to_mem == 14'h41 || csr_num_to_mem == 14'h44)) & !(csr_csr_we_to_wb && (csr_num_to_wb == 14'h0 || csr_num_to_wb == 14'h4 || csr_num_to_wb == 14'h5 || csr_num_to_wb == 14'h41 || csr_num_to_wb == 14'h44))
                                                    &!(csr_csr_we_wb && (csr_num_wb == 14'h0 || csr_num_wb == 14'h4 || csr_num_wb == 14'h5 || csr_num_wb == 14'h41 || csr_num_wb == 14'h44))&!(csr_ertn_flush_wb | csr_ertn_flush_to_mem | csr_ertn_flush_to_wb)&!(csr_rd_we_to_mem || csr_rd_we_to_wb || csr_rd_we_wb)&!(tlb_tlbrd_to_mem || tlb_tlbrd_to_wb || tlb_tlbrd_wb)&(~load_block_mem);//&(~csr_rd_we_wb);
/* assign	decode_ready_go= (inst_b|inst_bl|inst_lu12i_w)|
                        (
                            (inst_addi_w|inst_ld_w|inst_jirl|inst_slli_w|inst_srli_w|inst_srai_w)&
                            (gr_we_exe==1'b0|rf_raddr1 !=dest_exe)&
                            (gr_we_mem==1'b0|rf_raddr1!=dest_mem)&
                            (gr_we_wb==1'b0|rf_raddr1!=dest_wb) 
                         )|
                        (
                            (gr_we_exe==1'b0|(rf_raddr1!=dest_exe&rf_raddr2!=dest_exe))&
                            (gr_we_mem==1'b0|(rf_raddr1!=dest_mem&rf_raddr2!=dest_mem))&
                            (gr_we_wb==1'b0|(rf_raddr1!=dest_wb&rf_raddr2!=dest_wb))   
                        );
*/
assign	dec_allowin	=!decode_valid|decode_ready_go&exe_allowin;
                        
assign	dec_to_exe_valid=decode_valid&decode_ready_go;

always @(posedge clk) begin
    if (reset) begin
        decode_valid <= 1'b0;
    end
    else if(csr_wb_ex_wb | csr_ertn_flush_wb | tlb_refecth_wb)begin
        decode_valid<= 1'b0;
    end 
    else if(br_taken)begin
        decode_valid<=1'b0;
    end   
    else if (dec_allowin) begin
        decode_valid <= fetch_to_dec_valid;
    end
end

always @(posedge clk)begin 
    if(reset)begin
     decode_bus_reg <= 64'b0;
     ADEF_to_ID_reg <= 1'b0;
     TLBREFILL_to_ID_reg <= 1'b0;
     IFTLBINVALID_to_ID_reg <= 1'b0;
     IFTLBPOWER_to_ID_reg <= 1'b0;
     EXC_IF_to_ID_reg <= 1'b0;
    end
    else if (fetch_to_dec_valid & dec_allowin) begin
        decode_bus_reg <= fetch_to_decode_bus;
        ADEF_to_ID_reg <= ADEF_to_ID;
        TLBREFILL_to_ID_reg <= TLBREFILL_to_ID;
        IFTLBINVALID_to_ID_reg <= IFTLBINVALID_to_ID;
        IFTLBPOWER_to_ID_reg <= IFTLBPOWER_to_ID;
        EXC_IF_to_ID_reg <= EXC_IF_to_ID;
    end    
end

assign op_31_26  = dec_inst[31:26];
assign op_25_22  = dec_inst[25:22];
assign op_21_20  = dec_inst[21:20];
assign op_19_15  = dec_inst[19:15];

assign rd   = dec_inst[ 4: 0];
assign rj   = dec_inst[ 9: 5];
assign rk   = dec_inst[14:10];

assign i12  = dec_inst[21:10];
assign i20  = dec_inst[24: 5];
assign i16  = dec_inst[25:10];
assign i26  = {dec_inst[ 9: 0], dec_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];


assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~dec_inst[25];
assign inst_slti   = op_31_26_d[6'h0]& op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h0]& op_25_22_d[4'h9];
assign inst_andi    = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori     = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori    = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_pcaddu12i=op_31_26_d[6'h07] & ~dec_inst[25];
assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_csrrd   = dec_inst[31:24] == 8'b00000100 && dec_inst[9:5] == 5'b00000;
assign inst_csrwr   = dec_inst[31:24] == 8'b00000100 && dec_inst[9:5] == 5'b00001;
assign inst_csrxchg = dec_inst[31:24] == 8'b00000100 && ~inst_csrrd && ~inst_csrwr;
assign inst_ertn    = dec_inst  == 32'b00000110010010000011100000000000;
assign inst_syscall = dec_inst[31:15] == {10'b0,7'b1010110};
assign inst_break   = dec_inst[31:15] == {10'b0,7'b1010100};
assign inst_rdcntid_w = dec_inst[31:10] == {17'b0,5'b11000} && dec_inst[4:0] == 5'b00000;
assign inst_rdcntvl_w = dec_inst[31:10] == {17'b0, 5'b11000} && dec_inst[9:5] == 5'b00000;
assign inst_rdcntvh_w = dec_inst[31:10] == {17'b0,5'b11001} && dec_inst[9:5] == 5'b00000;

assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0a;
assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0b;
assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0c;
assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0d;
assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13] & (rd == 5'h00 || rd == 5'd1 || rd == 5'd2 || rd == 5'd3 || rd == 5'd4 || rd == 5'd5 || rd == 5'd6 );

// CACOP: opcode[31:22] = 000001_1000, format: cacop op, rj, si12
assign inst_cacop   = op_31_26_d[6'h01] & op_25_22_d[4'h8];


assign inst_blt     =op_31_26_d[6'h18];
assign inst_bge     =op_31_26_d[6'h19];
assign inst_bltu    =op_31_26_d[6'h1a];
assign inst_bgeu    =op_31_26_d[6'h1b];

assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_ld_b    =op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h    =op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu   =op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu   =op_31_26_d[6'h0a] & op_25_22_d[4'h9];

assign inst_st_w   =op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_st_b   =op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   =op_31_26_d[6'h0a] & op_25_22_d[4'h5];
///////when you add inst, you should think about our wire and INE wire
assign INE = !(inst_add_w | inst_addi_w | inst_and | inst_andi | inst_b | inst_beq | inst_bge |inst_bgeu | inst_bl |inst_blt | inst_bltu | inst_bne | inst_break | inst_csrrd | inst_csrwr|inst_csrxchg 
            |inst_div_w | inst_div_wu | inst_ertn | inst_jirl |inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_ld_w |inst_lu12i_w| inst_mod_w | inst_mod_wu |
            inst_mul_w  | inst_mulh_w | inst_mulh_wu | inst_nor |inst_or |inst_ori |inst_pcaddu12i|inst_sll_w | inst_slli_w | inst_slt |inst_slti | inst_sltu
            |inst_sltui |inst_sra_w |inst_srai_w | inst_srl_w | inst_srli_w |inst_st_b | inst_st_h| inst_st_w | inst_sub_w |inst_syscall | inst_xor | inst_xori| inst_rdcntid_w|inst_rdcntvh_w|inst_rdcntvl_w | inst_tlbsrch | inst_tlbfill | inst_tlbrd | inst_tlbwr | inst_invtlb | inst_cacop) && decode_valid;


assign alu_op[ 0] = inst_add_w | inst_addi_w|inst_pcaddu12i | load_op | inst_st_w|inst_st_b|inst_st_h | inst_cacop
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt|inst_slti;
assign alu_op[ 3] = inst_sltu|inst_sltui;
assign alu_op[ 4] = inst_and|inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or|inst_ori;
assign alu_op[ 7] = inst_xor|inst_xori;
assign alu_op[ 8] = inst_slli_w|inst_sll_w;
assign alu_op[ 9] = inst_srli_w|inst_srl_w;
assign alu_op[10] = inst_srai_w|inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_div_wu;
assign alu_op[17] = inst_mod_w;
assign alu_op[18] = inst_mod_wu;


assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w|inst_slti |inst_sltui| load_op | inst_st_w|inst_st_b|inst_st_h | inst_cacop;
assign need_ui12  = inst_andi|inst_ori|inst_xori;
assign need_si20  =  inst_lu12i_w|inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;


assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12? {20'b0,i12[11:0]}           :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w|inst_st_b|inst_st_h|inst_blt|inst_bge|inst_bltu|inst_bgeu | inst_csrwr| inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl|inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_pcaddu12i|
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_cacop  |
                       load_op     |
                       inst_st_w   |
                       inst_st_h   |
                       inst_st_b   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = load_op;
assign dst_is_r1     = inst_bl;
/* answer
 * bug：inst_bl�??要写回�?�用寄存器堆
 */
assign gr_we         = ~inst_st_w&~inst_st_b&~inst_st_h & ~inst_beq & ~inst_bne & ~inst_b&~inst_blt&~inst_bge&~inst_bltu&~inst_bgeu & ~inst_ertn &  ~inst_syscall&~inst_break & ~INE & ~inst_tlbsrch & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_invtlb & ~inst_cacop;//other csr inst will be blocked
assign mem_we        = inst_st_w|inst_st_b|inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 :  rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = (gr_we_exe==1'b1&&rf_raddr1==dest_exe)? forward_data_exe:
                   (gr_we_mem==1'b1&&rf_raddr1==dest_mem)? forward_data_mem:
                   (gr_we_wb==1'b1&&rf_raddr1==dest_wb)? forward_data_wb:
                   rf_rdata1;
assign rkd_value = (gr_we_exe==1'b1&&rf_raddr2==dest_exe)? forward_data_exe:
                   (gr_we_mem==1'b1&&rf_raddr2==dest_mem)? forward_data_mem:
                   (gr_we_wb==1'b1&&rf_raddr2==dest_wb)? forward_data_wb:
                   rf_rdata2;
/*
assign  decode_ready_go=~(inst_ld_w_forward_exe&
                            (
                                (
                                    (inst_addi_w|inst_ld_w|inst_jirl|inst_slli_w|inst_srli_w|inst_srai_w)&
                                    (rf_raddr1 ==dest_exe)
                                )|
                                (
                                    !(inst_b|inst_bl|inst_lu12i_w)&
                                    (rf_raddr1==dest_exe|rf_raddr2==dest_exe)
                                )
                            )
                        );
*/
assign rj_eq_rd = (rj_value == rkd_value); 
assign rj_ge_rd = ($signed(rj_value)>=$signed(rkd_value));
assign rj_geu_rd= ($unsigned(rj_value)>=$unsigned(rkd_value));

assign br_taken_raw = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  && !rj_ge_rd
                   || inst_bge  &&  rj_ge_rd
                   || inst_bltu && !rj_geu_rd
                   || inst_bgeu &&  rj_geu_rd
                   || inst_jirl 
                   || inst_bl
                   || inst_b
                  ) && decode_valid;

assign br_taken = br_taken_raw && decode_ready_go && exe_allowin;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b||inst_blt||inst_bltu||inst_bge||inst_bgeu) ? (dec_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
assign csr_rd_we_to_exe = (inst_csrrd || inst_csrwr || inst_csrxchg || inst_rdcntid_w)&&decode_valid;
assign csr_num_to_exe  = (inst_rdcntid_w) ? 14'h40 :dec_inst[23:10];
assign csr_rd_to_exe   = (inst_rdcntid_w) ? rj : rd;
assign csr_csr_we_to_exe = (inst_csrwr || inst_csrxchg)&&decode_valid;
assign csr_csr_wvalue_to_exe = rkd_value;
assign csr_csr_wmask_to_exe = (inst_csrxchg) ? rj_value : 32'hffffffff;
assign csr_ertn_flush_to_exe = (inst_ertn)&&decode_valid;
assign csr_wb_ex_to_exe = (inst_syscall | inst_break | ADEF_to_ID_reg | INE | has_int | TLBREFILL_to_ID_reg  |IFTLBINVALID_to_ID_reg | IFTLBPOWER_to_ID_reg  ) && decode_valid;
assign csr_wb_subecode_to_exe =  (has_int) ? 9'b0:
                                 (ADEF_to_ID_reg) ? 9'b0:
                                  (TLBREFILL_to_ID_reg) ? 9'b0 :
                                  (IFTLBINVALID_to_ID_reg) ? 9'b0 :
                                  (IFTLBPOWER_to_ID_reg) ? 9'b0 :
                                 (INE) ?   9'b0 :
                                 (inst_syscall) ? 9'b0 : 
                                 (inst_break) ? 9'b0 :
                                  9'b0;
assign csr_wb_ecode_to_exe =  (has_int) ? 6'h0 :
                              (ADEF_to_ID_reg) ? 6'h8 : 
                                (TLBREFILL_to_ID_reg) ? 6'h3f :
                                (IFTLBINVALID_to_ID_reg) ? 6'h3 :
                                (IFTLBPOWER_to_ID_reg) ? 6'h7 :
                               (INE) ?    6'hD:                         
                              (inst_syscall) ? 6'hB :
                              (inst_break) ? 6'hC:
                              6'h0;

assign ALE_h_to_exe = (inst_ld_h | inst_ld_hu | inst_st_h) && decode_valid;
assign ALE_w_to_exe = (inst_ld_w | inst_st_w ) && decode_valid;
assign rdcntv_to_exe = (inst_rdcntvl_w && decode_valid) ? 2'b01 :
                       (inst_rdcntvh_w && decode_valid) ? 2'b10 :
                       2'b00;
assign tlb_tlbsrch_to_exe = inst_tlbsrch && decode_valid;
assign tlb_tlbrd_to_exe   = inst_tlbrd && decode_valid;
assign tlb_tlbwr_to_exe   = inst_tlbwr && decode_valid;
assign tlb_tlbfill_to_exe = inst_tlbfill && decode_valid;
assign tlb_invtlb_to_exe  = inst_invtlb && decode_valid;
assign tlb_refecth_to_exe = (inst_tlbrd || inst_tlbfill || inst_invtlb|| inst_tlbwr || (csr_csr_we_to_exe && (csr_num_to_exe == 14'h180 || csr_num_to_exe == 14'h181 || csr_num_to_exe == 14'h18 || csr_num_to_exe == 14'h0 )))&&decode_valid;
assign tlb_invtlb_op_to_exe = rd[4:0];
assign tlb_invtlb_rj_value_to_exe = rj_value;
assign tlb_invtlb_rk_value_to_exe = rkd_value;

assign cacop_to_exe      = inst_cacop && decode_valid;
assign cacop_code_to_exe = rd[4:0];
assign EXC_IF_to_exe = EXC_IF_to_ID_reg;
endmodule 
