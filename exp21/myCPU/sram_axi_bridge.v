`include "mycpu.h"

//=====================================================================
//  bridge_sram_axi
//  �� CPU �� inst_sram / data_sram ���� ת���� AXI Э��
//  - inst_sram����֧�ֶ�
//  - data_sram��֧�ֶ�/д
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
    // Inst SRAM interface��������
    //=================================================================
    // input  wire          inst_sram_req,
    // input  wire          inst_sram_wr,
    // input  wire [ 1:0]   inst_sram_size,
    // input  wire [31:0]   inst_sram_addr,
    // input  wire [ 3:0]   inst_sram_wstrb,
    // input  wire [31:0]   inst_sram_wdata,
    // output wire          icache_rd_rdy,
    // output wire          inst_sram_data_ok,
    // output wire [31:0]   inst_sram_rdata,

    //================== icache interface ===================
    input  wire          icache_rd_req,
    input  wire  [ 2:0]      icache_rd_type,
    input  wire [31:0]   icache_rd_addr,

    output wire          icache_rd_rdy, //icache_rd_addr_ok

    output wire          icache_ret_valid, //icache_rd_data_ok
    output wire          icache_ret_last,
    output wire [31:0]   icache_ret_data, // icache_rd_rdata 
    
    input wire          icache_wr_req,
    input wire  [ 2:0]      icache_wr_type,
    input wire [31:0]   icache_wr_addr,
    input wire [ 3:0]   icache_wr_wstrb,
    input wire [31:0]   icache_wr_data,

    //=================================================================
    // Data SRAM interface����/д��
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
    //  Latch request info to keep AXI signals stable during handshake
    //=================================================================
    reg        req_hold;
    reg        wr_hold;
    reg        master_hold;
    reg [ 1:0] size_hold;
    reg [31:0] addr_hold;
    reg [ 3:0] wstrb_hold;
    reg [31:0] wdata_hold;

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
    
    // icache may issue read (refill) and potentially write-back; treat either as a request
    assign sram_req[0]   = icache_rd_req;
    assign sram_req[1]   = data_sram_req;
    assign sram_wr[0]    = icache_wr_req;
    assign sram_wr[1]    = data_sram_wr;
    assign sram_size[0]  = 2'b10; // arsize = 4 bytes
    assign sram_size[1]  = data_sram_size;
    assign sram_addr[0]  = icache_rd_addr;
    assign sram_addr[1]  = data_sram_addr;
    assign sram_wstrb[0] = icache_wr_wstrb;
    assign sram_wstrb[1] = data_sram_wstrb;
    assign sram_wdata[0] = icache_wr_data;
    assign sram_wdata[1] = data_sram_wdata;

    //=================================================================
    //  Handshake detection
    //=================================================================
    wire ar_hs = (state == STATE_AR) && req_hold && arready;
    wire aw_hs = (state == STATE_AW) && req_hold && awready && !aw_w_hs_reg[0];
    wire aw_finish = aw_w_hs_reg[0] | aw_hs;
    wire w_hs  = (state == STATE_AW) && req_hold && wready  && !aw_w_hs_reg[1];
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
            req_hold    <= 1'b0;
            wr_hold     <= 1'b0;
            master_hold <= 1'b0;
            size_hold   <= 2'b00;
            addr_hold   <= 32'b0;
            wstrb_hold  <= 4'b0;
            wdata_hold  <= 32'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    aw_w_hs_reg <= 2'b00;
                    req_hold    <= 1'b0;
                    if (sram_req[0] & sram_req[1]) begin
                        master <= 1'b1;
                        req_hold    <= 1'b1;
                        wr_hold     <= sram_wr[1];
                        master_hold <= 1'b1;
                        size_hold   <= sram_size[1];
                        addr_hold   <= sram_addr[1];
                        wstrb_hold  <= sram_wstrb[1];
                        wdata_hold  <= sram_wdata[1];
                        state      <= sram_wr[1] ? STATE_AW : STATE_AR;
                    end else if (sram_req[0]) begin
                        master <= 1'b0;
                        req_hold    <= 1'b1;
                        wr_hold     <= sram_wr[0];
                        master_hold <= 1'b0;
                        size_hold   <= sram_size[0];
                        addr_hold   <= sram_addr[0];
                        wstrb_hold  <= sram_wstrb[0];
                        wdata_hold  <= sram_wdata[0];
                        state      <= sram_wr[0] ? STATE_AW : STATE_AR;
                    end else if (sram_req[1]) begin
                        master <= 1'b1;
                        req_hold    <= 1'b1;
                        wr_hold     <= sram_wr[1];
                        master_hold <= 1'b1;
                        size_hold   <= sram_size[1];
                        addr_hold   <= sram_addr[1];
                        wstrb_hold  <= sram_wstrb[1];
                        wdata_hold  <= sram_wdata[1];
                        state      <= sram_wr[1] ? STATE_AW : STATE_AR;
                    end
                end

                STATE_AR: if (ar_hs)
                                state <= STATE_R;

                STATE_R: if (r_hs & rlast) begin
                                req_hold <= 1'b0;
                                state <= STATE_IDLE;
                          end

                STATE_AW: begin
                    if (aw_hs) aw_w_hs_reg[0] <= 1'b1;
                    if (w_hs)  aw_w_hs_reg[1] <= 1'b1;
                    if (aw_finish && w_finish) begin
                        aw_w_hs_reg <= 2'b00;
                        state <= STATE_B;
                    end
                end

                STATE_B: if (b_hs) begin
                                req_hold <= 1'b0;
                                state <= STATE_IDLE;
                         end
            endcase


        end
    end

    //=================================================================
    //  AXI channel assignments
    //=================================================================
    assign arid    = {3'b000, master_hold};
    assign araddr  = addr_hold;
    assign arlen   = (master_hold == 1'b0) ? 8'b11 : 8'b0;
    assign arsize  = {1'b0, size_hold};
    assign arburst = 2'b01;
    assign arlock  = 2'b00;
    assign arcache = 4'b0000;
    assign arprot  = 3'b000;
    assign arvalid = (state == STATE_AR) && req_hold;

    assign rready  = (state == STATE_R);

    assign awid    = {3'b000, master_hold};
    assign awaddr  = addr_hold;
    assign awlen   = 8'b0;
    assign awsize  = {1'b0, size_hold};
    assign awburst = 2'b01;
    assign awlock  = 2'b00;
    assign awcache = 4'b0000;
    assign awprot  = 3'b000;
    assign awvalid = (state == STATE_AW) && !aw_w_hs_reg[0] && req_hold;

    assign wid     = {3'b000, master_hold};
    assign wdata   = wdata_hold;
    assign wstrb   = wstrb_hold;
    assign wvalid  = (state == STATE_AW) && !aw_w_hs_reg[1] && req_hold;
    assign wlast   = 1'b1;
    
    assign bready  = (state == STATE_B);

    // For icache, only the read address handshake is meaningful
    // Route addr_ok based on the *held* transaction master.
    assign icache_rd_rdy =  (master_hold == 1'b0) && sram_addr_ok;
    assign data_sram_addr_ok = (master_hold == 1'b1) && sram_addr_ok;
    assign icache_ret_valid = (master_hold == 1'b0) && sram_data_ok;
    assign data_sram_data_ok = (master_hold == 1'b1) && sram_data_ok;
    assign icache_ret_last = (master_hold == 1'b0) &&rlast;
    assign icache_ret_data   = sram_rdata;
    assign data_sram_rdata   = sram_rdata;
    
endmodule
