/*`include "mycpu.h"
module csr(
    input  wire          clk       ,
    input  wire          reset     ,
    // csr read interface
    input  wire [13:0]   csr_num   ,
    output wire [31:0]   csr_rvalue,
    // csr write interface
    input  wire          csr_we    ,
    input  wire [31:0]   csr_wmask ,
    input  wire [31:0]   csr_wvalue,
    
    output wire [31:0]   ex_entry  , // the exception entry to pre-IF 
    output wire [31:0]   ertn_entry, // the exception return address to pre-IF 
    output wire          has_int   , // the interrupt valid signal to ID
    input  wire          ertn_flush, // the excption return valid from WB
    input  wire          wb_ex     , // the excption signal from WB
    input  wire [ 5:0]   wb_ecode  , // excption type
    input  wire [ 8:0]   wb_esubcode,
    input  wire [31:0]   wb_pc       
);
// ===================== Current Mode Information (CRMD) =====================
    wire [31: 0] csr_crmd_data;     // data 
    reg  [ 1: 0] csr_crmd_plv;      //Privilege Level
    reg          csr_crmd_ie;       //Interrupt Enable bit
    wire          csr_crmd_da;      //Direct Addressing mode flag
    wire          csr_crmd_pg;      //Paging Enable flag
    wire  [ 1: 0] csr_crmd_datf;    //Data Access Type for Fetch
    wire  [ 1: 0] csr_crmd_datm;    //Data Access Type for Memory


// ===================== Previous Mode Information (PRMD) =====================
    wire [31: 0] csr_prmd_data;         
    reg  [ 1: 0] csr_prmd_pplv;     //Previous Privilege Level
    reg          csr_prmd_pie;      //Previous Interrupt Enable 

// ===================== Exception Configuration (ECFG) =====================
    wire [31: 0] csr_ecfg_data;     
    reg  [12: 0] csr_ecfg_lie;      //Local Interrupt Enable bits 

// ===================== Exception Status (ESTAT) =====================
    wire [31: 0] csr_estat_data;  

    reg  [12: 0] csr_estat_is;      // Interrupt Status bits;8 hardware interrupts + 1 timer interrupt + 1 inter-core interrupt + 2 software interrupts  
    reg  [ 5: 0] csr_estat_ecode;   // Exception Code
    reg  [ 8: 0] csr_estat_esubcode;// Exception Subcode 

// ===================== Exception Return Address (ERA) =====================
    reg  [31: 0] csr_era_data;  // data

// ===================== Exception Entry Address (EENTRY) =====================
    wire [31: 0] csr_eentry_data;   
    reg  [25: 0] csr_eentry_va;     // Virtual Address field (VA field of EENTRY, bits [31:6])

// ===================== Saved Bad Virtual Addresses (SAVE0~3) =====================
    reg  [31: 0] csr_save0_data;
    reg  [31: 0] csr_save1_data;
    reg  [31: 0] csr_save2_data;
    reg  [31: 0] csr_save3_data;



// ===================== Timer Configuration & Interrupt Control =====================
    wire [31: 0] csr_ticlr_data;    // Timer Interrupt Clear Register (TICLR)
    reg         csr_tcfg_en;        // Timer Configuration: Enable bit (TCFG.EN)
    reg         csr_tcfg_periodic; // Timer Configuration: Periodic Mode (TCFG.PERIODIC)
    reg  [29:0] csr_tcfg_initval;  // Timer Configuration: Initial Value (TCFG.INITVAL[29:0])
    wire [31:0] tcfg_next_value;  // Next Timer Value (computed next countdown value)
    wire [31:0] csr_tval;           // Current Timer Value (TVAL)
    reg  [31:0] timer_cnt;          // Internal Timer Counter
 
    assign has_int  = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);
    assign ex_entry = csr_eentry_data;
    assign ertn_entry = csr_era_data;
    
//--------------------------- PLV��IE field of CRMD -------------------------------
    always @(posedge clk) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie  <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                          | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
            csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE ] & csr_wvalue[`CSR_CRMD_IE ]
                          | ~csr_wmask[`CSR_CRMD_IE ] & csr_crmd_ie;
        end
    end

//------------------------------  DA��PG��DATF��DATM filed of CRMD ------------------------------
    assign csr_crmd_da   = 1'b1; 
    assign csr_crmd_pg   = 1'b0; 
    assign csr_crmd_datf = 2'b00; 
    assign csr_crmd_datm = 2'b00;

//------------------------------ the PPLV��PIE fild of PRMD ------------------------------
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <=  csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                           | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <=  csr_wmask[`CSR_PRMD_PIE ] & csr_wvalue[`CSR_PRMD_PIE ]
                           | ~csr_wmask[`CSR_PRMD_PIE ] & csr_prmd_pie;
        end
    end

//------------------------------ the LIE field of ECFG ------------------------------
    always @(posedge clk) begin
        if(reset)
            csr_ecfg_lie <= 13'b0;
        else if(csr_we && csr_num == `CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                        |  ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end
// ----------------- the IS field of ESTAT -----------------------------
always @(posedge clk) begin
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <=  csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                          | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    // csr_estat_is[9:2] <= hw_int_in[7:0]; hardware interrupt
    csr_estat_is[9:2] <= 8'b0;
    csr_estat_is[10] <= 1'b0;
    if (timer_cnt[31:0]==32'b0)begin
        csr_estat_is[11] <= 1'b1;
    end
     //else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]&& csr_wvalue[`CSR_TICLR_CLR])begin
     csr_estat_is[11] <= 1'b0;
    //  csr_estat_is[12] <= ipi_int_in;
    csr_estat_is[ 12] <= 1'b0;
 end

//-------------- the Ecode and EsubCode filed of ESTAT -----------------------------
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
//---------------- PC field of ERA ------------------------------------------------
    always @(posedge clk) begin
        if(wb_ex)
            csr_era_data <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA) 
            csr_era_data <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                        | ~csr_wmask[`CSR_ERA_PC] & csr_era_data;
    end
    
// ---------------------------- the VA field of EENTRY ----------------------------
    always @(posedge clk) begin
        if (csr_we && (csr_num == `CSR_EENTRY))
            csr_eentry_va <=   csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                            | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va ;
    end

// ---------------------------- SAVE0~3 ----------------------------
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0) 
            csr_save0_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && (csr_num == `CSR_SAVE1)) 
            csr_save1_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && (csr_num == `CSR_SAVE2)) 
            csr_save2_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && (csr_num == `CSR_SAVE3)) 
            csr_save3_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end
   
 
 // ---------------------------- the TimeVal field of TVAL ----------------------------
 assign tcfg_next_value =  csr_wmask[31:0]&csr_wvalue[31:0]
                       | ~csr_wmask[31:0]&{csr_tcfg_initval,
                                           csr_tcfg_periodic, csr_tcfg_en};
                                           
//------------------------------- the Vaddr field of BADV -----------------------------
    assign csr_crmd_data  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_data  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_ecfg_data  = {19'b0, csr_ecfg_lie};
    assign csr_estat_data = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_eentry_data= {csr_eentry_va, 6'b0};                                           
    
//---------------------------- the Read Logic of CSR ----------------------------
    assign csr_ticlr_data = 32'b0;
    
    assign csr_rvalue = {32{csr_num == `CSR_CRMD  }} & csr_crmd_data
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_data
                      | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_data
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_data
                      | {32{csr_num == `CSR_ERA   }} & csr_era_data
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_data
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_data
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_data
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_data
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_data
                      | {32{csr_num == `CSR_TICLR }} & csr_ticlr_data;

endmodule*/