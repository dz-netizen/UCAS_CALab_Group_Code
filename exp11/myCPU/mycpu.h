`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD           33
    `define FETCH_TO_DEC_BUS_WD   64
    `define DEC_TO_EXE_BUS_WD     168
    `define EXE_TO_MEM_BUS_WD     78
    `define MEM_TO_WB_BUS_WD     70
    `define WB_TO_REGFILE_BUS_WD  41

 //   `define ES_FWD_BLK_BUS_WD   42
 //   `define MS_FWD_BLK_BUS_WD   41

//    `define EX_INT              5'h00
//    `define EX_ADEL             5'h04
//    `define EX_ADES             5'h05
//    `define EX_SYS              5'h08
//    `define EX_BP               5'h09
//    `define EX_RI               5'h0a
//    `define EX_OV               5'h0c
//    `define EX_NO               5'h1f

`endif
