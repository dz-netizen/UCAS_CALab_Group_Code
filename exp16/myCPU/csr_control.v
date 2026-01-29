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

    //to WB
    output  wire    [31:0]      csr_rd_value,
    //to IF
    output  wire                csr_is_branch,
    output  wire    [31:0]      csr_pc_if,
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


  wire [31:0] TVAL;//0x42
  wire  TICLR_CLR;//0x44
  wire [31:0] TCFG_NEXT_VALUE;
reg  [31:0] timer_cnt;

  wire wb_ex_addr_err ;
  assign wb_ex_addr_err = (csr_wb_ecode_wb == 6'h8)||(csr_wb_ecode_wb == 6'h9);


assign csr_rd_value = (csr_num_wb == 14'h0) ?  {23'b0,CSR_CRMD_DATM,CSR_CRMD_DATF,CSR_CRMD_PG,CSR_CRMD_DA,CSR_CRMD_IE,CSR_CRMD_PLV} :
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
                       32'b0;
assign csr_pc_if = (csr_wb_ex_wb) ? CSR_EENTRY : CSR_ERA;
assign csr_is_branch = csr_ertn_flush_wb | csr_wb_ex_wb;

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
    /*else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_DA <= csr_csr_wvalue_wb[3];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_PG <= 1'b0;
    /*else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_PG <= csr_csr_wvalue_wb[4];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_DATF <= 2'b0;
    /*else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_DATF <= csr_csr_wvalue_wb[6:5];
    end*/
end
always@(posedge clk)begin
    if(reset)
      CSR_CRMD_DATM <= 2'b0;
    /*else if(csr_num_wb == 14'h0 && csr_csr_we_wb)begin
      CSR_CRMD_DATM <= csr_csr_wvalue_wb[8:7];
    end*/
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
    BADV <= (csr_wb_ecode_wb == 6'h8 && csr_wb_subecode_wb == 9'h0) ? csr_pc_wb : csr_BADV_wb;
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




endmodule
