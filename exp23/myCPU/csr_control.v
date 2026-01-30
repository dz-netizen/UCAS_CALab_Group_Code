`include "mycpu.h"

module csr_control (
    input   wire                clk,
    input   wire                reset,

    //from wb
    input   wire    [13:0]      csr_num_wb,                         
    input   wire                csr_rd_we_wb,
    input   wire    [31:0]      csr_csr_wvalue_wb,
    input   wire                csr_csr_we_wb,
    input   wire    [31:0]      csr_csr_wmask_wb,
    input   wire                csr_wb_ex_wb,
    input   wire                csr_ertn_flush_wb,
    input   wire    [5:0]       csr_wb_ecode_wb,
    input   wire    [8:0]       csr_wb_subecode_wb,
    input   wire    [31:0]      csr_pc_wb,
    input   wire    [31:0]      csr_BADV_wb,
    input   wire                tlb_refecth_wb,
    input   wire                tlb_invtlb_wb,
    input   wire                tlb_tlbwr_wb,
    input   wire                tlb_tlbrd_wb,
    input   wire                tlb_tlbsrch_to_mem,
    input   wire                tlb_tlbfill_wb,
    input   wire   [31:0]       wb_pc_to_csr,
    input   wire                EXC_IF_wb,

    //from tlb
    input   wire    [3:0]       tlb_index_tlb_to_csr,
    input   wire    tlb_found_tlb_to_csr,
    
    input   wire                 tlb_r_e_tlb_to_csr,
    input   wire [18:0]          tlb_r_vppn_tlb_to_csr,
    input  wire [5:0]           tlb_r_ps_tlb_to_csr,
    input  wire [9:0]           tlb_r_asid_tlb_to_csr,
    input  wire                 tlb_r_g_tlb_to_csr,

    input  wire [19:0]          tlb_r_ppn0_tlb_to_csr,
    input  wire [1:0]           tlb_r_plv0_tlb_to_csr,
    input  wire [1:0]           tlb_r_mat0_tlb_to_csr,
    input  wire                 tlb_r_d0_tlb_to_csr,
    input  wire                 tlb_r_v0_tlb_to_csr,

    input  wire [19:0]          tlb_r_ppn1_tlb_to_csr,
    input  wire [1:0]           tlb_r_plv1_tlb_to_csr,
    input  wire [1:0]           tlb_r_mat1_tlb_to_csr,
    input  wire                 tlb_r_d1_tlb_to_csr,
    input  wire                 tlb_r_v1_tlb_to_csr,


    //to exe
    output  wire    [18:0]      tlb_vpnn_csr_to_exe,//for TLBSRCH
    output  wire                tlb_va_bit12_csr_to_exe,//for TLBSRCH
    output  wire    [9:0]       tlb_asid_csr_to_exe,//for TLBSRCH
    //to tlb
    output  wire    [3:0]       tlb_r_index_csr_to_tlb,//for TLBRD
    
    output  wire                tlb_we_csr_to_tlb,
    output  wire    [3:0]       tlb_w_index_csr_to_tlb,
    output  wire                tlb_w_e_csr_to_tlb,
    output  wire    [18:0]      tlb_w_vppn_csr_to_tlb,
    output  wire    [5:0]       tlb_w_ps_csr_to_tlb,
    output  wire    [9:0]       tlb_w_asid_csr_to_tlb,
    output  wire                tlb_w_g_csr_to_tlb,

    output  wire    [19:0]      tlb_w_ppn0_csr_to_tlb,
    output  wire    [1:0]       tlb_w_plv0_csr_to_tlb,
    output  wire    [1:0]       tlb_w_mat0_csr_to_tlb,
    output  wire                tlb_w_d0_csr_to_tlb,
    output  wire                tlb_w_v0_csr_to_tlb,

    output  wire    [19:0]      tlb_w_ppn1_csr_to_tlb,
    output  wire    [1:0]       tlb_w_plv1_csr_to_tlb,
    output  wire    [1:0]       tlb_w_mat1_csr_to_tlb,
    output  wire                tlb_w_d1_csr_to_tlb,
    output  wire                tlb_w_v1_csr_to_tlb,

    //to WB
    output  wire    [31:0]      csr_rd_value,
    //to IF
    output  wire                csr_is_branch,
    output  wire    [31:0]      csr_pc_if,
    //to IF & EXE for MMU
    output wire     [1:0]       csr_plv_for_mmu,

    output wire                 csr_dmw0_plv0_for_mmu,
    output wire                 csr_dmw0_plv3_for_mmu,
    output wire     [2:0]       csr_dmw0_pseg_for_mmu,
    output wire     [2:0]       csr_dmw0_vseg_for_mmu,
    output wire                 csr_dmw1_plv0_for_mmu,
    output wire                 csr_dmw1_plv3_for_mmu,
    output wire     [2:0]       csr_dmw1_pseg_for_mmu,
    output wire     [2:0]       csr_dmw1_vseg_for_mmu,

    // memory access type (MAT) for load/store cacheability decision
    output wire     [1:0]       csr_crmd_datm_for_mmu,
    output wire     [1:0]       csr_dmw0_mat_for_mmu,
    output wire     [1:0]       csr_dmw1_mat_for_mmu,

    output wire                 csr_direct_addr_for_mmu,
 
    //to ID
    output wire                 has_int

);
  reg [1:0] CSR_CRMD_PLV;//0
  reg  CSR_CRMD_IE;//0
  reg  CSR_CRMD_DA;//0
  reg  CSR_CRMD_PG;//0
  reg  [1:0] CSR_CRMD_DATF;//0
  reg [1:0] CSR_CRMD_DATM;//0
  reg [1:0] CSR_PRMD_PPLV;//1
  reg  CSR_PRMD_PIE;//1
  

  reg [1:0] CSR_ESTAT_IS1_0;//5
  reg [7:0] CSR_ESTAT_IS9_2;//5
  reg  CSR_ESTAT_IS11;//5
  reg  CSR_ESTAT_IS12;//5
  reg  [5:0] CSR_ESTAT_ECODE;//5
  reg [8:0] CSR_ESTAT_ESUBCODE;//5
  reg [31:0] CSR_ERA;//6
  reg [31:0] CSR_EENTRY;//c
  reg [31:0] SAVE0;//0x30
  reg [31:0] SAVE1;//0x31
  reg [31:0] SAVE2;//0x32
  reg [31:0] SAVE3;//0x33
  reg [9:0] ECFG_LIE9_0;//0x4
  reg [1:0] ECFG_LIE12_11;//0x4
  reg [31:0] BADV;//0x7
  reg [31:0] TID;//0x40
  reg  TCFG_EN;//0x41
  reg  TCFG_PERIODIC;//0X41
  reg  [29:0] TCFG_INITVAL;//0X41
  reg  [3:0] TLBIDX_INDEX;//0X10
  reg  [5:0] TLBIDX_PS;//0X10
  reg  TLBIDX_NE;//0X10
  reg  [18:0] TLBEHI_VPNN;//0X11
  reg  TLBELO0_V;//0X12
  reg  TLBELO0_D;//0X12
  reg  [1:0] TLBELO0_PLV;//0X12
  reg  [1:0] TLBELO0_MAT;//0X12
  reg  TLBELO0_G;//0X12
  reg  [19:0] TLBELO0_PPN;//0X12
  reg  TLBELO1_V;//0X13
  reg  TLBELO1_D;//0X13
  reg  [1:0] TLBELO1_PLV;//0X13
  reg  [1:0] TLBELO1_MAT;//0X13
  reg  TLBELO1_G;//0X13
  reg  [19:0] TLBELO1_PPN;//0X13
  reg  [9:0]  ASID_ASID;//0X18
  wire  [7:0]  ASID_ASIDBITS;//0X18
  reg  [25:0] TLBRENTRY_PA;//0x88
  reg  DMW0_PLV0;
  reg  DMW0_PLV3;
  reg  [1:0] DMW0_MAT;//0x180
  reg  [2:0] DMW0_PSEG;
  reg  [2:0] DMW0_VSEG;
  reg  DMW1_PLV0;//0x181
  reg  DMW1_PLV3;
  reg  [1:0] DMW1_MAT;
  reg  [2:0] DMW1_PSEG;
  reg  [2:0] DMW1_VSEG;


  wire [31:0] TVAL;//0x42
  wire  TICLR_CLR;//0x44
  wire [31:0] TCFG_NEXT_VALUE;
  reg  [31:0] timer_cnt;
  wire wb_ex_tlbhi;

  wire wb_ex_addr_err ;
  assign wb_ex_addr_err = (csr_wb_ecode_wb == 6'h8)||(csr_wb_ecode_wb == 6'h9)||  
                          (csr_wb_ecode_wb == 6'h1)||(csr_wb_ecode_wb == 6'h2) ||
                          (csr_wb_ecode_wb == 6'h3)||(csr_wb_ecode_wb == 6'h4) ||
                          (csr_wb_ecode_wb == 6'h7)||(csr_wb_ecode_wb == 6'h3f) ;
                          
  assign wb_ex_tlbhi  =  
                          (csr_wb_ecode_wb == 6'h1)||(csr_wb_ecode_wb == 6'h2) ||
                          (csr_wb_ecode_wb == 6'h3)||(csr_wb_ecode_wb == 6'h4) ||
                          (csr_wb_ecode_wb == 6'h7)||(csr_wb_ecode_wb == 6'h3f) ;


wire [31:0] csr_rd_value_comb;

assign csr_rd_value_comb = (csr_num_wb == 14'h0) ?  {23'b0,CSR_CRMD_DATM,CSR_CRMD_DATF,CSR_CRMD_PG,CSR_CRMD_DA,CSR_CRMD_IE,CSR_CRMD_PLV} :
                           (csr_num_wb == 14'h1) ?  {29'b0, CSR_PRMD_PIE,CSR_PRMD_PPLV} :
                           (csr_num_wb == 14'h5) ? {1'b0,CSR_ESTAT_ESUBCODE,CSR_ESTAT_ECODE,3'b0,CSR_ESTAT_IS12,CSR_ESTAT_IS11,1'b0,CSR_ESTAT_IS9_2,CSR_ESTAT_IS1_0} :
                           (csr_num_wb == 14'h6) ? CSR_ERA :
                           (csr_num_wb == 14'hc) ? CSR_EENTRY :
                           (csr_num_wb == 14'h30) ? SAVE0 :
                           (csr_num_wb == 14'h31) ? SAVE1 :
                           (csr_num_wb == 14'h32) ? SAVE2 :
                           (csr_num_wb == 14'h33) ? SAVE3 :
                           (csr_num_wb == 14'h4) ? {19'b0,ECFG_LIE12_11,1'b0,ECFG_LIE9_0} : 
                           (csr_num_wb == 14'h7) ? BADV:
                           (csr_num_wb == 14'h40) ? TID :
                           (csr_num_wb == 14'h41) ? {TCFG_INITVAL,TCFG_PERIODIC, TCFG_EN} :
                           (csr_num_wb == 14'h42) ? TVAL:
                           (csr_num_wb == 14'h44) ? {31'b0,TICLR_CLR} :
                           (csr_num_wb == 14'h10) ? {TLBIDX_NE,1'b0,TLBIDX_PS,8'h0,12'h0,TLBIDX_INDEX} :
                           (csr_num_wb == 14'h11) ? {TLBEHI_VPNN,13'h0} :
                           (csr_num_wb == 14'h12) ? {4'h0,TLBELO0_PPN,1'b0,TLBELO0_G,TLBELO0_MAT,TLBELO0_PLV,TLBELO0_D,TLBELO0_V} :
                           (csr_num_wb == 14'h13) ? {4'h0,TLBELO1_PPN,1'b0,TLBELO1_G,TLBELO1_MAT,TLBELO1_PLV,TLBELO1_D,TLBELO1_V} :
                           (csr_num_wb == 14'h18) ? {8'h0,ASID_ASIDBITS,6'h0,ASID_ASID} :
                           (csr_num_wb == 14'h88) ? {TLBRENTRY_PA,6'h0} :
                           (csr_num_wb == 14'h180) ? {DMW0_VSEG,1'b0,DMW0_PSEG,19'b0,DMW0_MAT,DMW0_PLV3,2'b0,DMW0_PLV0} :
                           (csr_num_wb == 14'h181) ? {DMW1_VSEG,1'b0,DMW1_PSEG,19'b0,DMW1_MAT,DMW1_PLV3,2'b0,DMW1_PLV0} :
                           32'b0;

assign csr_rd_value = csr_rd_value_comb;
assign csr_pc_if = (csr_wb_ex_wb  && (csr_wb_ecode_wb == 6'h3f)) ? {TLBRENTRY_PA,6'h0} :
                    (csr_wb_ex_wb && !(csr_wb_ecode_wb == 6'h3f)) ? CSR_EENTRY : 
                    (csr_ertn_flush_wb) ? CSR_ERA :
                    wb_pc_to_csr+32'h4 ;

assign csr_is_branch = csr_ertn_flush_wb | csr_wb_ex_wb | tlb_refecth_wb ;

always@(posedge clk)begin
    if(reset)
      CSR_CRMD_PLV <= 2'b0;
    else if(csr_wb_ex_wb)begin
      CSR_CRMD_PLV <= 2'b0;
    end
    else if(csr_ertn_flush_wb)begin
      CSR_CRMD_PLV <= CSR_PRMD_PPLV;
    end
    else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_PLV <= csr_csr_wvalue_wb[1:0] &csr_csr_wmask_wb[1:0] | ~csr_csr_wmask_wb[1:0] & CSR_CRMD_PLV;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_IE <= 1'b0;
    else if(csr_wb_ex_wb)begin
      CSR_CRMD_IE <= 1'b0;
    end
    else if(csr_ertn_flush_wb)begin
      CSR_CRMD_IE <= CSR_PRMD_PIE;
    end
    else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_IE <= csr_csr_wvalue_wb[2] & csr_csr_wmask_wb[2] | ~csr_csr_wmask_wb[2] & CSR_CRMD_IE;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_DA <= 1'b1;
    else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_DA <= csr_csr_wvalue_wb[3] & csr_csr_wmask_wb[3] | ~csr_csr_wmask_wb[3] & CSR_CRMD_DA;
    end
    else if(csr_ertn_flush_wb && CSR_ESTAT_ECODE ==6'h3f )begin
      CSR_CRMD_DA <= 1'b0;
    end
    else if(csr_wb_ex_wb && csr_wb_ecode_wb == 6'h3f)begin
      CSR_CRMD_DA <= 1'b1;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_PG <= 1'b0;
    else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_PG <= csr_csr_wvalue_wb[4] & csr_csr_wmask_wb[4] | ~csr_csr_wmask_wb[4] & CSR_CRMD_PG;
    end
    else if(csr_ertn_flush_wb && CSR_ESTAT_ECODE ==6'h3f )begin
      CSR_CRMD_PG <= 1'b1;
    end
    else if(csr_wb_ex_wb && csr_wb_ecode_wb == 6'h3f)begin
      CSR_CRMD_PG <= 1'b0;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_DATF <= 2'b0;
    else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_DATF <= csr_csr_wvalue_wb[6:5] & csr_csr_wmask_wb[6:5] | ~csr_csr_wmask_wb[6:5] & CSR_CRMD_DATF;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_DATM <= 2'b0;
    else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_DATM <= csr_csr_wvalue_wb[8:7] & csr_csr_wmask_wb[8:7] | ~csr_csr_wmask_wb[8:7] & CSR_CRMD_DATM;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_PRMD_PPLV <= 2'b0;
    else if(csr_wb_ex_wb)begin
      CSR_PRMD_PPLV <= CSR_CRMD_PLV;
    end
    else if(csr_num_wb == 14'h1 && csr_csr_we_wb)begin
      CSR_PRMD_PPLV <= csr_csr_wvalue_wb[1:0] & csr_csr_wmask_wb[1:0] | ~csr_csr_wmask_wb[1:0] & CSR_PRMD_PPLV;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_PRMD_PIE <= 1'b0;
    else if(csr_wb_ex_wb)begin
      CSR_PRMD_PIE <= CSR_CRMD_IE;
    end
    else if(csr_num_wb == 14'h1 && csr_csr_we_wb)begin
      CSR_PRMD_PIE <= csr_csr_wvalue_wb[2] & csr_csr_wmask_wb[2] | ~csr_csr_wmask_wb[2] & CSR_PRMD_PIE;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_ESTAT_IS1_0 <= 2'b0;
    else if(csr_num_wb == 14'h5 && csr_csr_we_wb)begin
      CSR_ESTAT_IS1_0 <= csr_csr_wvalue_wb[1:0] & csr_csr_wmask_wb[1:0] | ~csr_csr_wmask_wb[1:0] & CSR_ESTAT_IS1_0;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_ESTAT_IS9_2 <= 8'b0;
    /*else if(csr_num_wb == 14'h5 && csr_csr_we_wb)begin
      CSR_ESTAT_IS9_2 <= csr_csr_wvalue_wb[9:2];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_ESTAT_IS11 <= 1'b0;
    else if(timer_cnt[31:0] == 32'b0)begin
      CSR_ESTAT_IS11 <= 1'b1;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h44&&csr_csr_wmask_wb[0] &&csr_csr_wvalue_wb[0])
      CSR_ESTAT_IS11 <= 1'b0;
    /*else if(csr_num_wb == 14'h5 && csr_csr_we_wb)begin
      CSR_ESTAT_IS11 <= csr_csr_wvalue_wb[11];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_ESTAT_IS12 <= 1'b0;
end
always@(posedge clk)begin
    if(reset)
      CSR_ESTAT_ECODE <= 6'b0;
    else if(csr_wb_ex_wb)begin
      CSR_ESTAT_ECODE <= csr_wb_ecode_wb;
    end
    /*else if(csr_num_wb == 14'h5 && csr_csr_we_wb)begin
      CSR_ESTAT_ECODE <= csr_csr_wvalue_wb[21:16];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_ESTAT_ESUBCODE <= 9'b0;
    else if(csr_wb_ex_wb)begin
      CSR_ESTAT_ESUBCODE <= csr_wb_subecode_wb;
    end
    /*else if(csr_num_wb == 14'h5 && csr_csr_we_wb)begin
      CSR_ESTAT_ESUBCODE <= csr_csr_wvalue_wb[30:22];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_ERA <= 32'b0;
    else if(csr_wb_ex_wb)begin
      CSR_ERA <= csr_pc_wb;
    end
    else if(csr_num_wb == 14'h6 && csr_csr_we_wb)begin
      CSR_ERA <= csr_csr_wvalue_wb & csr_csr_wmask_wb | ~csr_csr_wmask_wb & CSR_ERA;
    end
end
always@(posedge clk)begin
    if(reset)
      CSR_EENTRY <= 32'b0;
    else if(csr_num_wb == 14'hc && csr_csr_we_wb)begin
      CSR_EENTRY <= {csr_csr_wvalue_wb[31:6] & csr_csr_wmask_wb[31:6] | ~csr_csr_wmask_wb[31:6] & CSR_EENTRY[31:6] , CSR_EENTRY[5:0]};
    end
end
always@(posedge clk)begin
    if(reset)
      SAVE0 <= 32'b0;
    else if(csr_num_wb == 14'h30 && csr_csr_we_wb)begin
      SAVE0 <= csr_csr_wvalue_wb & csr_csr_wmask_wb | ~csr_csr_wmask_wb & SAVE0;
    end
end
always@(posedge clk)begin
    if(reset)
      SAVE1 <= 32'b0;
    else if(csr_num_wb == 14'h31 && csr_csr_we_wb)begin
      SAVE1 <= csr_csr_wvalue_wb & csr_csr_wmask_wb | ~csr_csr_wmask_wb & SAVE1;
    end
end
always@(posedge clk)begin
    if(reset)
      SAVE2 <= 32'b0;
    else if(csr_num_wb == 14'h32 && csr_csr_we_wb)begin
      SAVE2 <= csr_csr_wvalue_wb & csr_csr_wmask_wb | ~csr_csr_wmask_wb & SAVE2;
    end
end
always@(posedge clk)begin
    if(reset)
      SAVE3 <= 32'b0;
    else if(csr_num_wb == 14'h33 && csr_csr_we_wb)begin
      SAVE3 <= csr_csr_wvalue_wb & csr_csr_wmask_wb | ~csr_csr_wmask_wb & SAVE3;
    end
end
always@(posedge clk)begin
  if(reset)
    BADV <= 32'b0;
  else if(wb_ex_addr_err && csr_wb_ex_wb)begin
    BADV <= (EXC_IF_wb) ? csr_pc_wb : csr_BADV_wb;
  end
end
always@(posedge clk)begin
  if(reset)begin
   ECFG_LIE12_11 <= 2'b0;
   ECFG_LIE9_0   <= 10'b0;
  end
  else if(csr_csr_we_wb && csr_num_wb == 14'h4)begin
    ECFG_LIE12_11 <= csr_csr_wmask_wb[12:11] & csr_csr_wvalue_wb[12:11] | ~csr_csr_wmask_wb[12:11] & ECFG_LIE12_11;
    ECFG_LIE9_0 <= csr_csr_wmask_wb[9:0] & csr_csr_wvalue_wb[9:0] | ~csr_csr_wmask_wb[9:0] & ECFG_LIE9_0;
  end
end

always@(posedge clk)begin
  if(reset)
    TID <= 32'b0;
  else if(csr_csr_we_wb && csr_num_wb == 14'h40)begin
    TID <= csr_csr_wmask_wb & csr_csr_wvalue_wb | ~csr_csr_wmask_wb & TID;
  end
end

always@(posedge clk)begin
  if(reset)begin
     TCFG_EN <= 1'b0;
     TCFG_PERIODIC <= 1'b0;
     TCFG_INITVAL <= 30'b0;
  end
  else if(csr_csr_we_wb && csr_num_wb == 14'h41)begin
     TCFG_EN <= csr_csr_wmask_wb[0] & csr_csr_wvalue_wb[0] | ~csr_csr_wmask_wb[0] & TCFG_EN;
     TCFG_PERIODIC <= csr_csr_wmask_wb[1] & csr_csr_wvalue_wb[1] | ~csr_csr_wmask_wb[1] & TCFG_PERIODIC;
     TCFG_INITVAL <= csr_csr_wmask_wb[31:2] & csr_csr_wvalue_wb[31:2] | ~csr_csr_wmask_wb[31:2] & TCFG_INITVAL;
  end
end

assign TCFG_NEXT_VALUE =  csr_csr_wmask_wb[31:0] & csr_csr_wvalue_wb[31:0] | ~csr_csr_wmask_wb[31:0] &{TCFG_INITVAL,TCFG_PERIODIC,TCFG_EN};

always@(posedge clk)begin
  if(reset)
   timer_cnt <= 32'hffffffff;
  else if(csr_csr_we_wb && csr_num_wb == 14'h41 && TCFG_NEXT_VALUE[0])begin
    timer_cnt <= {TCFG_NEXT_VALUE[31:2],2'b0};
  end
  else if(TCFG_EN && timer_cnt != 32'hffffffff) begin
    if(timer_cnt[31:0] == 32'b0 && TCFG_PERIODIC)
      timer_cnt <= {TCFG_INITVAL,2'b0};
    else
      timer_cnt <= timer_cnt - 1'b1;
  end
end


assign TVAL = timer_cnt[31:0];
assign TICLR_CLR = 1'b0;
assign has_int = (({CSR_ESTAT_IS12,CSR_ESTAT_IS11,1'b0,CSR_ESTAT_IS9_2,CSR_ESTAT_IS1_0}& {ECFG_LIE12_11,1'b0,ECFG_LIE9_0}) != 13'b0) && (CSR_CRMD_IE == 1'b1);


always@(posedge clk)begin
    if(reset)begin
      TLBIDX_INDEX <= 4'b0;
      TLBIDX_PS <= 6'b0;
      TLBIDX_NE <= 1'b0;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h10)begin
      TLBIDX_INDEX <= csr_csr_wvalue_wb[3:0] & csr_csr_wmask_wb[3:0] | ~csr_csr_wmask_wb[3:0] & TLBIDX_INDEX;
      TLBIDX_PS <= csr_csr_wvalue_wb[29:24] & csr_csr_wmask_wb[29:24] | ~csr_csr_wmask_wb[29:24] & TLBIDX_PS;
      TLBIDX_NE <= csr_csr_wvalue_wb[31] & csr_csr_wmask_wb[31] | ~csr_csr_wmask_wb[31] & TLBIDX_NE;
    end
    else if(tlb_tlbsrch_to_mem)begin
      TLBIDX_INDEX <= tlb_found_tlb_to_csr ? tlb_index_tlb_to_csr : TLBIDX_INDEX;
      TLBIDX_NE <= ~tlb_found_tlb_to_csr;
    end
    else if(tlb_tlbrd_wb)begin
      TLBIDX_PS <= {6{tlb_r_e_tlb_to_csr}}& tlb_r_ps_tlb_to_csr ;
      TLBIDX_NE <= ~tlb_r_e_tlb_to_csr;
    end
end
always@(posedge clk)begin
    if(reset)
      TLBEHI_VPNN <= 19'b0;
    else if(csr_wb_ex_wb && wb_ex_tlbhi)begin
      TLBEHI_VPNN <= (EXC_IF_wb) ?  csr_pc_wb[31:13] : csr_BADV_wb[31:13];
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h11)begin
      TLBEHI_VPNN <= csr_csr_wvalue_wb[31:13] & csr_csr_wmask_wb[31:13] | ~csr_csr_wmask_wb[31:13] & TLBEHI_VPNN;
    end
    else if(tlb_tlbrd_wb)begin
      TLBEHI_VPNN <= tlb_r_e_tlb_to_csr ? tlb_r_vppn_tlb_to_csr : 19'b0;
    end
    
end

always@(posedge clk)begin
    if(reset)begin
      TLBELO0_V <= 1'b0;
      TLBELO0_D <= 1'b0;
      TLBELO0_PLV <= 2'b0;
      TLBELO0_MAT <= 2'b0;
      TLBELO0_G <= 1'b0;
      TLBELO0_PPN <= 20'b0;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h12)begin
      TLBELO0_V <= csr_csr_wvalue_wb[0] & csr_csr_wmask_wb[0] | ~csr_csr_wmask_wb[0] & TLBELO0_V;
      TLBELO0_D <= csr_csr_wvalue_wb[1] & csr_csr_wmask_wb[1] | ~csr_csr_wmask_wb[1] & TLBELO0_D;
      TLBELO0_PLV <= csr_csr_wvalue_wb[3:2] & csr_csr_wmask_wb[3:2] | ~csr_csr_wmask_wb[3:2] & TLBELO0_PLV;
      TLBELO0_MAT <= csr_csr_wvalue_wb[5:4] & csr_csr_wmask_wb[5:4] | ~csr_csr_wmask_wb[5:4] & TLBELO0_MAT;
      TLBELO0_G <= csr_csr_wvalue_wb[6] & csr_csr_wmask_wb[6] | ~csr_csr_wmask_wb[6] & TLBELO0_G;
      TLBELO0_PPN <= csr_csr_wvalue_wb[27:8] & csr_csr_wmask_wb[27:8] | ~csr_csr_wmask_wb[27:8] & TLBELO0_PPN;
    end
    else if(tlb_tlbrd_wb)begin
      TLBELO0_V <= tlb_r_e_tlb_to_csr ? tlb_r_v0_tlb_to_csr : 1'b0;
      TLBELO0_D <= tlb_r_e_tlb_to_csr ? tlb_r_d0_tlb_to_csr : 1'b0;
      TLBELO0_PLV <= tlb_r_e_tlb_to_csr ? tlb_r_plv0_tlb_to_csr : 2'b0;
      TLBELO0_MAT <= tlb_r_e_tlb_to_csr ? tlb_r_mat0_tlb_to_csr : 2'b0;
      TLBELO0_G <= tlb_r_e_tlb_to_csr ? tlb_r_g_tlb_to_csr : 1'b0;
      TLBELO0_PPN <= tlb_r_e_tlb_to_csr ? tlb_r_ppn0_tlb_to_csr : 20'b0;
    end
end

always@(posedge clk)begin
    if(reset)begin
      TLBELO1_V <= 1'b0;
      TLBELO1_D <= 1'b0;
      TLBELO1_PLV <= 2'b0;
      TLBELO1_MAT <= 2'b0;
      TLBELO1_G <= 1'b0;
      TLBELO1_PPN <= 20'b0;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h13)begin
      TLBELO1_V <= csr_csr_wvalue_wb[0] & csr_csr_wmask_wb[0] | ~csr_csr_wmask_wb[0] & TLBELO1_V;
      TLBELO1_D <= csr_csr_wvalue_wb[1] & csr_csr_wmask_wb[1] | ~csr_csr_wmask_wb[1] & TLBELO1_D;
      TLBELO1_PLV <= csr_csr_wvalue_wb[3:2] & csr_csr_wmask_wb[3:2] | ~csr_csr_wmask_wb[3:2] & TLBELO1_PLV;
      TLBELO1_MAT <= csr_csr_wvalue_wb[5:4] & csr_csr_wmask_wb[5:4] | ~csr_csr_wmask_wb[5:4] & TLBELO1_MAT;
      TLBELO1_G <= csr_csr_wvalue_wb[6] & csr_csr_wmask_wb[6] | ~csr_csr_wmask_wb[6] & TLBELO1_G;
      TLBELO1_PPN <= csr_csr_wvalue_wb[27:8] & csr_csr_wmask_wb[27:8] | ~csr_csr_wmask_wb[27:8] & TLBELO1_PPN;
    end
    else if(tlb_tlbrd_wb)begin
      TLBELO1_V <= tlb_r_e_tlb_to_csr ? tlb_r_v1_tlb_to_csr : 1'b0;
      TLBELO1_D <= tlb_r_e_tlb_to_csr ? tlb_r_d1_tlb_to_csr : 1'b0;
      TLBELO1_PLV <= tlb_r_e_tlb_to_csr ? tlb_r_plv1_tlb_to_csr : 2'b0;
      TLBELO1_MAT <= tlb_r_e_tlb_to_csr ? tlb_r_mat1_tlb_to_csr : 2'b0;
      TLBELO1_G <= tlb_r_e_tlb_to_csr ? tlb_r_g_tlb_to_csr : 1'b0;
      TLBELO1_PPN <= tlb_r_e_tlb_to_csr ? tlb_r_ppn1_tlb_to_csr : 20'b0;
    end
end

assign ASID_ASIDBITS = 8'd10;
always@(posedge clk)begin
    if(reset)begin
      ASID_ASID <= 10'b0;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h18)begin
      ASID_ASID <= csr_csr_wvalue_wb[9:0] & csr_csr_wmask_wb[9:0] | ~csr_csr_wmask_wb[9:0] & ASID_ASID;
    end
    else if(tlb_tlbrd_wb)begin
      ASID_ASID <= tlb_r_e_tlb_to_csr ? tlb_r_asid_tlb_to_csr : 10'b0;   
    end
end

always@(posedge clk)begin
    if(reset)
      TLBRENTRY_PA <= 26'b0;
    else if(csr_csr_we_wb && csr_num_wb == 14'h88)begin
      TLBRENTRY_PA <= csr_csr_wvalue_wb[31:6] & csr_csr_wmask_wb[31:6] | ~csr_csr_wmask_wb[31:6] & TLBRENTRY_PA;
    end
end

always@(posedge clk)begin
    if(reset)begin
      DMW0_PLV0 <= 1'b0;
      DMW0_PLV3 <= 1'b0;
      DMW0_MAT <= 2'b0;
      DMW0_PSEG <= 3'b0;
      DMW0_VSEG <= 3'b0;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h180)begin
      DMW0_PLV0 <= csr_csr_wvalue_wb[0] & csr_csr_wmask_wb[0] | ~csr_csr_wmask_wb[0] & DMW0_PLV0;
      DMW0_PLV3 <= csr_csr_wvalue_wb[3] & csr_csr_wmask_wb[3] | ~csr_csr_wmask_wb[3] & DMW0_PLV3;
      DMW0_MAT <= csr_csr_wvalue_wb[5:4] & csr_csr_wmask_wb[5:4] | ~csr_csr_wmask_wb[5:4] & DMW0_MAT;
      DMW0_PSEG <= csr_csr_wvalue_wb[27:25] & csr_csr_wmask_wb[27:25] | ~csr_csr_wmask_wb[27:25] & DMW0_PSEG;
      DMW0_VSEG <= csr_csr_wvalue_wb[31:29] & csr_csr_wmask_wb[31:29] | ~csr_csr_wmask_wb[31:29] & DMW0_VSEG;
    end
end

always@(posedge clk)begin
    if(reset)begin
      DMW1_PLV0 <= 1'b0;
      DMW1_PLV3 <= 1'b0;
      DMW1_MAT <= 2'b0;
      DMW1_PSEG <= 3'b0;
      DMW1_VSEG <= 3'b0;
    end
    else if(csr_csr_we_wb && csr_num_wb == 14'h181)begin
      DMW1_PLV0 <= csr_csr_wvalue_wb[0] & csr_csr_wmask_wb[0] | ~csr_csr_wmask_wb[0] & DMW1_PLV0;
      DMW1_PLV3 <= csr_csr_wvalue_wb[3] & csr_csr_wmask_wb[3] | ~csr_csr_wmask_wb[3] & DMW1_PLV3;
      DMW1_MAT <= csr_csr_wvalue_wb[5:4] & csr_csr_wmask_wb[5:4] | ~csr_csr_wmask_wb[5:4] & DMW1_MAT;
      DMW1_PSEG <= csr_csr_wvalue_wb[27:25] & csr_csr_wmask_wb[27:25] | ~csr_csr_wmask_wb[27:25] & DMW1_PSEG;
      DMW1_VSEG <= csr_csr_wvalue_wb[31:29] & csr_csr_wmask_wb[31:29] | ~csr_csr_wmask_wb[31:29] & DMW1_VSEG;
    end
end


assign tlb_vpnn_csr_to_exe = TLBEHI_VPNN[18:0];
assign tlb_va_bit12_csr_to_exe = 1'b0;
assign tlb_asid_csr_to_exe = ASID_ASID[9:0];
assign tlb_r_index_csr_to_tlb = TLBIDX_INDEX[3:0];

assign tlb_we_csr_to_tlb = tlb_tlbwr_wb | tlb_tlbfill_wb;
assign tlb_w_index_csr_to_tlb = TLBIDX_INDEX[3:0];  
assign tlb_w_e_csr_to_tlb = ~TLBIDX_NE;
assign tlb_w_ps_csr_to_tlb = TLBIDX_PS[5:0];
assign tlb_w_asid_csr_to_tlb = ASID_ASID[9:0];
assign tlb_w_g_csr_to_tlb = TLBELO0_G && TLBELO1_G;
assign tlb_w_vppn_csr_to_tlb = TLBEHI_VPNN;
assign tlb_w_ppn0_csr_to_tlb = TLBELO0_PPN;
assign tlb_w_plv0_csr_to_tlb = TLBELO0_PLV;
assign tlb_w_mat0_csr_to_tlb = TLBELO0_MAT; 
assign tlb_w_d0_csr_to_tlb = TLBELO0_D;
assign tlb_w_v0_csr_to_tlb = TLBELO0_V;
assign tlb_w_ppn1_csr_to_tlb = TLBELO1_PPN;
assign tlb_w_plv1_csr_to_tlb = TLBELO1_PLV;
assign tlb_w_mat1_csr_to_tlb = TLBELO1_MAT; 
assign tlb_w_d1_csr_to_tlb = TLBELO1_D;
assign tlb_w_v1_csr_to_tlb = TLBELO1_V;
assign csr_plv_for_mmu = CSR_CRMD_PLV;
assign csr_dmw0_plv0_for_mmu = DMW0_PLV0;
assign csr_dmw0_plv3_for_mmu = DMW0_PLV3;
assign csr_dmw0_pseg_for_mmu = DMW0_PSEG;
assign csr_dmw0_vseg_for_mmu = DMW0_VSEG;
assign csr_dmw1_plv0_for_mmu = DMW1_PLV0;

assign csr_dmw1_plv3_for_mmu = DMW1_PLV3;
assign csr_dmw1_pseg_for_mmu = DMW1_PSEG;
assign csr_dmw1_vseg_for_mmu = DMW1_VSEG;
assign csr_crmd_datm_for_mmu = CSR_CRMD_DATM;
assign csr_dmw0_mat_for_mmu  = DMW0_MAT;
assign csr_dmw1_mat_for_mmu  = DMW1_MAT;
assign csr_direct_addr_for_mmu = CSR_CRMD_DA && !CSR_CRMD_PG;



endmodule
