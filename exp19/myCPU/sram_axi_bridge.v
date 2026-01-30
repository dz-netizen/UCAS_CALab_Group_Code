`include "mycpu.h"

//=====================================================================
//  bridge_sram_axi
//  将 CPU 的 inst_sram / data_sram 请求 转换成 AXI 协议
//  - inst_sram：仅支持读
//  - data_sram：支持读/写
//=====================================================================

module bridge_sram_axi(
    input  wire          aclk,
    input  wire          aresetn,

    //=================================================================
    // AXI Read Address Channel
    //=================================================================
    output wire  [ 3:0]  arid,
    output wire  [31:0]  araddr,
    output wire  [ 7:0]  arlen,
    output wire  [ 2:0]  arsize,
    output wire  [ 1:0]  arburst,
    output wire  [ 1:0]  arlock,
    output wire  [ 3:0]  arcache,
    output wire  [ 2:0]  arprot,
    output wire          arvalid,
    input  wire          arready,

    //=================================================================
    // AXI Read Data Channel
    //=================================================================
    input  wire [ 3:0]   rid,
    input  wire [31:0]   rdata,
    input  wire          rlast,
    input  wire          rvalid,
    output wire          rready,

    //=================================================================
    // AXI Write Address Channel
    //=================================================================
    output wire  [ 3:0]  awid,
    output wire  [31:0]  awaddr,
    output wire  [ 7:0]  awlen,
    output wire  [ 2:0]  awsize,
    output wire  [ 1:0]  awburst,
    output wire  [ 1:0]  awlock,
    output wire  [ 3:0]  awcache,
    output wire  [ 2:0]  awprot,
    output wire          awvalid,
    input  wire          awready,

    //=================================================================
    // AXI Write Data Channel
    //=================================================================
    output wire  [ 3:0]  wid,
    output wire  [31:0]  wdata,
    output wire  [ 3:0]  wstrb,
    output wire          wlast,
    output wire          wvalid,
    input  wire          wready,

    //=================================================================
    // AXI Write Response Channel
    //=================================================================
    input  wire [ 3:0]   bid,
    input  wire          bvalid,
    output wire          bready,

    //=================================================================
    // Inst SRAM interface（仅读）
    //=================================================================
    input  wire          inst_sram_req,
    input  wire          inst_sram_wr,
    input  wire [ 1:0]   inst_sram_size,
    input  wire [31:0]   inst_sram_addr,
    input  wire [ 3:0]   inst_sram_wstrb,
    input  wire [31:0]   inst_sram_wdata,
    output wire          inst_sram_addr_ok,
    output wire          inst_sram_data_ok,
    output wire [31:0]   inst_sram_rdata,

    //=================================================================
    // Data SRAM interface（读/写）
    //=================================================================
    input  wire          data_sram_req,
    input  wire          data_sram_wr,
    input  wire [ 1:0]   data_sram_size,
    input  wire [31:0]   data_sram_addr,
    input  wire [31:0]   data_sram_wdata,
    input  wire [ 3:0]   data_sram_wstrb,
    output wire          data_sram_addr_ok,
    output wire          data_sram_data_ok,
    output wire [31:0]   data_sram_rdata
);

    //=================================================================
    //  FSM States
    //=================================================================
    localparam STATE_IDLE = 3'd0;
    localparam STATE_AR   = 3'd1;
    localparam STATE_R    = 3'd2;
    localparam STATE_AW   = 3'd3;
    localparam STATE_B    = 3'd4;

    reg [2:0] state;
    reg [1:0] aw_w_hs_reg;   
    reg       master;    // 0 = inst, 1 = data
    reg       master_reg;
    //=================================================================
    //  Shortcut arrays for the two masters
    //=================================================================
    wire        sram_req   [1:0];
    wire        sram_wr    [1:0];
    wire [ 1:0] sram_size  [1:0];
    wire [31:0] sram_addr  [1:0];
    wire [ 3:0] sram_wstrb [1:0];
    wire [31:0] sram_wdata [1:0];
    
    wire [31:0] sram_rdata = rdata;
    
    assign sram_req[0]   = inst_sram_req;
    assign sram_req[1]   = data_sram_req;
    assign sram_wr[0]    = inst_sram_wr;
    assign sram_wr[1]    = data_sram_wr;
    assign sram_size[0]  = inst_sram_size;
    assign sram_size[1]  = data_sram_size;
    assign sram_addr[0]  = inst_sram_addr;
    assign sram_addr[1]  = data_sram_addr;
    assign sram_wstrb[0] = inst_sram_wstrb;
    assign sram_wstrb[1] = data_sram_wstrb;
    assign sram_wdata[0] = inst_sram_wdata;
    assign sram_wdata[1] = data_sram_wdata;

    //=================================================================
    //  Handshake detection
    //=================================================================
    wire ar_hs = (state == STATE_AR) && sram_req[master] && arready;
    wire aw_hs = (state == STATE_AW) && sram_req[master] && awready && !aw_w_hs_reg[0];
    wire aw_finish = aw_w_hs_reg[0] | aw_hs;
    wire w_hs  = (state == STATE_AW) && sram_req[master] && wready  && !aw_w_hs_reg[1];
    wire w_finish  = aw_w_hs_reg[1] | w_hs;
    wire r_hs  = (state == STATE_R)  && rvalid;
    wire b_hs  = (state == STATE_B)  && bvalid;
    
    wire sram_addr_ok = ar_hs | (aw_finish & w_finish);
    wire sram_data_ok = r_hs | b_hs;

    //=================================================================
    //  FSM
    //=================================================================  
always @(posedge aclk)begin
    if(~aresetn)begin
        master_reg <= 1'b0;
    end
    else begin
        master_reg <= master;
    end
end
    always @(posedge aclk) begin
        if (!aresetn) begin
            state       <= STATE_IDLE;
            aw_w_hs_reg  <= 2'b00;
            master  <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    aw_w_hs_reg <= 2'b00;
                    if (sram_req[0] & sram_req[1]) begin
                        master <= 1'b1;
                        state      <= sram_wr[1] ? STATE_AW : STATE_AR;
                    end else if (sram_req[0]) begin
                        master <= 1'b0;
                        state      <= sram_wr[0] ? STATE_AW : STATE_AR;
                    end else if (sram_req[1]) begin
                        master <= 1'b1;
                        state      <= sram_wr[1] ? STATE_AW : STATE_AR;
                    end
                end

                STATE_AR: if (!sram_req[master])
                                state <= STATE_IDLE;
                          else if (ar_hs)
                                state <= STATE_R;

                STATE_R: if (r_hs)
                                state <= STATE_IDLE;

                STATE_AW: begin
                    if (!sram_req[master]) begin
                        aw_w_hs_reg <= 2'b00;
                        state <= STATE_IDLE;
                    end else begin
                        if (aw_hs) aw_w_hs_reg[0] <= 1'b1;
                        if (w_hs)  aw_w_hs_reg[1] <= 1'b1;
                        if (aw_finish && w_finish) begin
                            aw_w_hs_reg <= 2'b00;
                            state <= STATE_B;
                        end
                    end
                end

                STATE_B: if (b_hs)
                                state <= STATE_IDLE;
            endcase


        end
    end

    //=================================================================
    //  AXI channel assignments
    //=================================================================
    assign arid    = {3'b000, master};
    assign araddr  = sram_addr[master];
    assign arlen   = 8'b0;
    assign arsize  = {1'b0, sram_size[master]};
    assign arburst = 2'b01;
    assign arlock  = 2'b00;
    assign arcache = 4'b0000;
    assign arprot  = 3'b000;
    assign arvalid = (state == STATE_AR) && sram_req[master];

    assign rready  = (state == STATE_R);

    assign awid    = {3'b000, master};
    assign awaddr  = sram_addr[master];
    assign awlen   = 8'b0;
    assign awsize  = {1'b0, sram_size[master]};
    assign awburst = 2'b01;
    assign awlock  = 2'b00;
    assign awcache = 4'b0000;
    assign awprot  = 3'b000;
    assign awvalid = (state == STATE_AW) && !aw_w_hs_reg[0] && sram_req[master];

    assign wid     = {3'b000, master};
    assign wdata   = sram_wdata[master];
    assign wstrb   = sram_wstrb[master];
    assign wvalid  = (state == STATE_AW) && !aw_w_hs_reg[1] && sram_req[master];
    assign wlast   = 1'b1;
    
    assign bready  = (state == STATE_B);

    assign inst_sram_addr_ok = (master_reg == 1'b0) && sram_addr_ok;
    assign data_sram_addr_ok = (master_reg == 1'b1) && sram_addr_ok;
    assign inst_sram_data_ok = (master == 1'b0) && sram_data_ok;
    assign data_sram_data_ok = (master == 1'b1) && sram_data_ok;
    assign inst_sram_rdata   = sram_rdata;
    assign data_sram_rdata   = sram_rdata;
    
endmodule
