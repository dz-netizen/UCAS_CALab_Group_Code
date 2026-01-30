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

    //================== dcache interface ===================
    input  wire          dcache_rd_req,
    input  wire  [ 2:0]  dcache_rd_type,
    input  wire [31:0]   dcache_rd_addr,
    output wire          dcache_rd_rdy,
    output wire          dcache_ret_valid,
    output wire          dcache_ret_last,
    output wire [31:0]   dcache_ret_data,

    input  wire          dcache_wr_req,
    input  wire  [ 2:0]  dcache_wr_type,
    input  wire [31:0]   dcache_wr_addr,
    input  wire [ 3:0]   dcache_wr_wstrb,
    input  wire [127:0]  dcache_wr_data,
    output wire          dcache_wr_rdy
    
);

    //=================================================================
    //  FSM States
    //=================================================================
    localparam STATE_IDLE = 3'd0;
    localparam STATE_AR   = 3'd1;
    localparam STATE_R    = 3'd2;
    localparam STATE_AW   = 3'd3;
    localparam STATE_W    = 3'd4;
    localparam STATE_B    = 3'd5;

    reg [2:0] state;
    reg       master;    // 0 = icache, 1 = dcache
    reg       master_reg;

    //=================================================================
    //  Latch request info to keep AXI signals stable during handshake
    //=================================================================
    reg        req_hold;
    reg        wr_hold;
    reg        master_hold;
    reg [ 2:0] type_hold;
    reg [31:0] addr_hold;
    reg [ 3:0] wstrb_hold;
    reg [127:0] wdata_hold;
    reg [1:0]  wbeat_cnt;
    reg [1:0]  rbeat_cnt;

    //=================================================================
    //  Request selection (dcache has priority over icache)
    //=================================================================
    wire icache_req = icache_rd_req | icache_wr_req;
    wire dcache_req = dcache_rd_req | dcache_wr_req;
    wire sel_dcache = dcache_req;

    wire sel_req    = sel_dcache ? dcache_req : icache_req;
    wire sel_wr     = sel_dcache ? dcache_wr_req : icache_wr_req;
    wire [2:0] sel_type = sel_dcache ? (sel_wr ? dcache_wr_type : dcache_rd_type)
                                     : (sel_wr ? icache_wr_type : icache_rd_type);
    wire [31:0] sel_addr = sel_dcache ? (sel_wr ? dcache_wr_addr : dcache_rd_addr)
                                      : (sel_wr ? icache_wr_addr : icache_rd_addr);
    wire [3:0] sel_wstrb = sel_dcache ? dcache_wr_wstrb : icache_wr_wstrb;
    wire [127:0] sel_wdata = sel_dcache ? dcache_wr_data : {96'b0, icache_wr_data};

    // translate type to AXI arsize/awsize and burst length
    wire sel_is_block = (sel_type == 3'b100);
    wire [2:0] axi_size = 3'b010; // 4 bytes (32-bit data bus)
    // NOTE: Some memory systems in labs may not support AXI bursts.
    // We keep write-burst as-is, but emulate READ_BLOCK as 4 single-beat reads.

    //=================================================================
    //  Handshake detection
    //=================================================================
    wire ar_hs = (state == STATE_AR) && req_hold && arready;
    wire r_hs  = (state == STATE_R)  && rvalid;
    wire aw_hs = (state == STATE_AW) && req_hold && awready;
    wire w_hs  = (state == STATE_W)  && req_hold && wready;
    wire b_hs  = (state == STATE_B)  && bvalid;

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
            master      <= 1'b0;
            req_hold    <= 1'b0;
            wr_hold     <= 1'b0;
            master_hold <= 1'b0;
            type_hold   <= 3'b0;
            addr_hold   <= 32'b0;
            wstrb_hold  <= 4'b0;
            wdata_hold  <= 128'b0;
            wbeat_cnt   <= 2'b0;
            rbeat_cnt   <= 2'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    req_hold <= 1'b0;
                    if (sel_req) begin
                        master      <= sel_dcache;
                        req_hold    <= 1'b1;
                        wr_hold     <= sel_wr;
                        master_hold <= sel_dcache;
                        type_hold   <= sel_type;
                        addr_hold   <= sel_addr;
                        wstrb_hold  <= sel_wstrb;
                        wdata_hold  <= sel_wdata;
                        wbeat_cnt   <= 2'b0;
                        rbeat_cnt   <= 2'b0;
                        state       <= sel_wr ? STATE_AW : STATE_AR;
                    end
                end

                STATE_AR: begin
                    if (ar_hs) begin
                        state <= STATE_R;
                    end
                end

                STATE_R: begin
                    if (r_hs) begin
                        // For READ_BLOCK: emulate 4-beat burst using 4 single-beat reads.
                        // Ignore external rlast and generate our own completion after 4 beats.
                        if (!wr_hold && (type_hold == 3'b100)) begin
                            if (rbeat_cnt == 2'b11) begin
                                req_hold <= 1'b0;
                                state <= STATE_IDLE;
                            end else begin
                                rbeat_cnt <= rbeat_cnt + 1'b1;
                                addr_hold <= addr_hold + 32'd4;
                                state <= STATE_AR;
                            end
                        end
                        else begin
                            // Normal single-beat read
                            if (rlast) begin
                                req_hold <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                    end
                end

                STATE_AW: begin
                    if (aw_hs) begin
                        wbeat_cnt <= 2'b0;
                        state <= STATE_W;
                    end
                end

                STATE_W: begin
                    if (w_hs) begin
                        if ((type_hold == 3'b100) && (wbeat_cnt != 2'b11)) begin
                            wbeat_cnt <= wbeat_cnt + 1'b1;
                        end else begin
                            state <= STATE_B;
                        end
                    end
                end

                STATE_B: begin
                    if (b_hs) begin
                        req_hold <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

    //=================================================================
    //  AXI channel assignments
    //=================================================================
    assign arid    = {3'b000, master_hold};
    assign araddr  = addr_hold;
    // Emulate READ_BLOCK using single-beat reads (arlen=0).
    assign arlen   = 8'd0;
    assign arsize  = axi_size;
    assign arburst = 2'b01;
    assign arlock  = 2'b00;
    assign arcache = 4'b0000;
    assign arprot  = 3'b000;
    assign arvalid = (state == STATE_AR) && req_hold;

    assign rready  = (state == STATE_R);

    assign awid    = {3'b000, master_hold};
    assign awaddr  = addr_hold;
    assign awlen   = (type_hold == 3'b100) ? 8'd3 : 8'd0;
    assign awsize  = axi_size;
    assign awburst = 2'b01;
    assign awlock  = 2'b00;
    assign awcache = 4'b0000;
    assign awprot  = 3'b000;
    assign awvalid = (state == STATE_AW) && req_hold;

    assign wid     = {3'b000, master_hold};
    assign wdata   = (type_hold == 3'b100) ?
                     (wbeat_cnt == 2'b00 ? wdata_hold[ 31:  0] :
                      wbeat_cnt == 2'b01 ? wdata_hold[ 63: 32] :
                      wbeat_cnt == 2'b10 ? wdata_hold[ 95: 64] :
                                           wdata_hold[127: 96])
                     : wdata_hold[31:0];
    assign wstrb   = (type_hold == 3'b100) ? 4'b1111 : wstrb_hold;
    assign wvalid  = (state == STATE_W) && req_hold;
    assign wlast   = (type_hold != 3'b100) ? 1'b1 : (wbeat_cnt == 2'b11);
    
    assign bready  = (state == STATE_B);

    // Ready/return routing for caches
    // Only assert *_rd_rdy for the first address handshake of a READ_BLOCK.
    wire is_read_block = (!wr_hold) && (type_hold == 3'b100);
    wire first_ar_of_block = (rbeat_cnt == 2'b00);

    assign icache_rd_rdy     = (master_hold == 1'b0) && ar_hs && !wr_hold && (!is_read_block || first_ar_of_block);
    assign dcache_rd_rdy     = (master_hold == 1'b1) && ar_hs && !wr_hold && (!is_read_block || first_ar_of_block);

    assign icache_ret_valid  = (master_hold == 1'b0) && (state == STATE_R) && rvalid;
    assign dcache_ret_valid  = (master_hold == 1'b1) && (state == STATE_R) && rvalid;

    // For READ_BLOCK, generate ret_last on the 4th returned beat.
    assign icache_ret_last   = (master_hold == 1'b0) && (is_read_block ? (rvalid && (rbeat_cnt == 2'b11)) : rlast);
    assign dcache_ret_last   = (master_hold == 1'b1) && (is_read_block ? (rvalid && (rbeat_cnt == 2'b11)) : rlast);

    assign icache_ret_data   = rdata;
    assign dcache_ret_data   = rdata;

    // dcache write-back ready: indicate bridge can accept a write request
    assign dcache_wr_rdy     = (state == STATE_IDLE);
    
endmodule
