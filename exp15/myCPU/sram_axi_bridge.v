`include "mycpu.h"

//=====================================================================
//  bridge_sram_axi
//  将 CPU 的 inst_sram / data_sram 请求 转换成 AXI 协议
//  - inst_sram：仅支持读
//  - data_sram：支持读/写
//  采用 4 个 FSM：AR、R、W、B
//=====================================================================

module bridge_sram_axi(
    input  wire          aclk,
    input  wire          aresetn,

    //=================================================================
    // AXI Read Address Channel
    //=================================================================
    output reg  [ 3:0]   arid,        // 读请求 ID 0=inst,1=data
    output reg  [31:0]   araddr,      // 读地址
    output reg  [ 7:0]   arlen,       
    output reg  [ 2:0]   arsize,      // 读数据长度 = log2(8)
    output reg  [ 1:0]   arburst,     // burst type = INCR
    output reg  [ 1:0]   arlock,
    output reg  [ 3:0]   arcache,
    output reg  [ 2:0]   arprot,
    output wire          arvalid,     // 有读请求
    input  wire          arready,     // 总线允许读请求

    //=================================================================
    // AXI Read Data Channel
    //=================================================================
    input  wire [ 3:0]   rid,         // 返回 ID
    input  wire [31:0]   rdata,       // 返回数据
    input  wire [ 1:0]   rresp,
    input  wire          rlast,       // 最后一个 byte
    input  wire          rvalid,
    output wire          rready,      // 读数据准备好接收

    //=================================================================
    // AXI Write Address Channel
    //=================================================================
    output reg  [ 3:0]   awid,        // 写地址 ID = 1
    output reg  [31:0]   awaddr,
    output reg  [ 7:0]   awlen,
    output reg  [ 2:0]   awsize,
    output reg  [ 1:0]   awburst,
    output reg  [ 1:0]   awlock,
    output reg  [ 3:0]   awcache,
    output reg  [ 2:0]   awprot,
    output wire          awvalid,
    input  wire          awready,

    //=================================================================
    // AXI Write Data Channel
    //=================================================================
    output reg  [ 3:0]   wid,         // 写 ID
    output reg  [31:0]   wdata,
    output reg  [ 3:0]   wstrb,
    output reg           wlast,
    output wire          wvalid,
    input  wire          wready,

    //=================================================================
    // AXI Write Response Channel
    //=================================================================
    input  wire [ 3:0]   bid,
    input  wire [ 1:0]   bresp,
    input  wire          bvalid,
    output wire          bready,

    //=================================================================
    // Inst SRAM interface（仅读）
    //=================================================================
    input  wire          inst_sram_req,
    input  wire          inst_sram_wr,      // 永远为 0
    input  wire [ 1:0]   inst_sram_size,
    input  wire [31:0]   inst_sram_addr,
    input  wire [ 3:0]   inst_sram_wstrb,
    input  wire [31:0]   inst_sram_wdata,
    output wire          inst_sram_addr_ok, // 发出读地址成功
    output wire          inst_sram_data_ok, // 收到读数据
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

//////////////////////////////////////////////////////////////////////////////////
// 内部信号定义
//////////////////////////////////////////////////////////////////////////////////

// FSM 状态变量，5 bit 一热编码
reg [4:0] ar_current_state, ar_next_state;  // read address
reg [4:0] r_current_state,  r_next_state;   // read data
reg [4:0] w_current_state,  w_next_state;   // write request+data
reg [4:0] b_current_state,  b_next_state;   // write response

// 响应计数器（burst 模式下可能用）
reg [1:0] ar_resp_cnt;
reg [1:0] aw_resp_cnt;
reg [1:0] wd_resp_cnt;

// 读数据双缓冲：buf[0]=inst，buf[1]=data
reg [31:0] buf_rdata [1:0];

// 检测读写冲突
wire read_block;

// 锁存 rid，用于 data_ok / inst_ok 判断
reg [3:0] rid_r;

localparam IDLE = 5'b00001;

//////////////////////////////////////////////////////////////////////////////////
// 读请求FSM（AR）
//////////////////////////////////////////////////////////////////////////////////

localparam AR_REQ_START = 5'b00010;
localparam AR_REQ_END   = 5'b00100;


// 状态跳转
always @(posedge aclk) begin
    if (!aresetn)
        ar_current_state <= IDLE;
    else
        ar_current_state <= ar_next_state;
end

// 下一个状态
always @(*) begin
    case (ar_current_state)
        IDLE:
            // 如果正在写同一个地址 → 读要阻塞
            if (read_block)
                ar_next_state = IDLE;

            // inst 或 data 的读请求
            else if ((data_sram_req & ~data_sram_wr) |
                     (inst_sram_req & ~inst_sram_wr))
                ar_next_state = AR_REQ_START;

            else
                ar_next_state = IDLE;

        AR_REQ_START:
            // 读请求 handshake 成功
            if (arvalid & arready)
                ar_next_state = AR_REQ_END;
            else
                ar_next_state = AR_REQ_START;

        AR_REQ_END:
            ar_next_state = IDLE;

        default:
            ar_next_state = IDLE;
    endcase
end

assign arvalid = ar_current_state[1];   // 只有在 START 状态发出请求

//////////////////////////////////////////////////////////////////////////////////
// 读响应通道 FSM（R）
//////////////////////////////////////////////////////////////////////////////////

localparam R_DATA_START = 5'b00010;
localparam R_DATA_END   = 5'b00100;
localparam R_DATA_NEXT   = 5'b01000;
reg con_read_reg;
always @(posedge aclk) begin
    if (!aresetn)
        con_read_reg <=1'b0;
    else if(arvalid & arready & rvalid & rready &rlast&r_current_state[1])
        con_read_reg <= 1'b1;
    else 
        con_read_reg <=1'b0;
end
always @(posedge aclk) begin
    if (!aresetn)
        r_current_state <= IDLE;
    else 
        r_current_state <= r_next_state;
end
reg round;
always @(posedge aclk) begin
    if (!aresetn)
        round <=1'b0;
    else if(r_current_state[1] & arvalid & arready)
        round <=1'b1;
    else if(rvalid & rready)
        round <=1'b0;
end

always @(*) begin
    case (r_current_state)
        IDLE:
            // AR handshake 成功或者仍有未完成的 byte
            if (arvalid & arready || |ar_resp_cnt)
                r_next_state = R_DATA_START;
            else
                r_next_state = IDLE;

        R_DATA_START:
            // 读返回最后一个 beat，结束读事务
            if(rvalid & rready & round)
                r_next_state = R_DATA_NEXT;
            else if(arvalid & arready & rvalid & rready &rlast)begin
                r_next_state = R_DATA_START;
            end               
            else if (rvalid & rready & rlast)
                r_next_state = R_DATA_END;
            else
                r_next_state = R_DATA_START;
        R_DATA_NEXT:
             if(rvalid & rready)
                r_next_state = R_DATA_END;
            else
                r_next_state = IDLE;                
        R_DATA_END:
            if(arvalid & arready)
                r_next_state = R_DATA_START;
            else
            r_next_state = IDLE;

        default:begin
            r_next_state = IDLE;
        end
    endcase
end

assign rready = r_current_state[1]|r_current_state[3]; // START 状态接收读数据

//////////////////////////////////////////////////////////////////////////////////
// 写请求 + 写数据 FSM（W）
//////////////////////////////////////////////////////////////////////////////////

localparam W_REQ_START = 5'b00010;  // 发写地址、写数据
localparam W_ADDR_RESP = 5'b00100;  // 等待写地址 handshake
localparam W_DATA_RESP = 5'b01000;  // 等待写数据 handshake
localparam W_REQ_END   = 5'b10000;  // 等待写响应 B channel

always @(posedge aclk) begin
    if (!aresetn)
        w_current_state <= IDLE;
    else
        w_current_state <= w_next_state;
end

always @(*) begin
    case (w_current_state)
        IDLE:
            if (data_sram_wr)
                w_next_state = W_REQ_START;
            else
                w_next_state = IDLE;

        W_REQ_START:
            // 地址和数据同时完成
            if ((awvalid & awready & wvalid & wready) ||
                ((|aw_resp_cnt)&(|wd_resp_cnt)))
                w_next_state = W_REQ_END;

            // 地址先成功
            else if (awvalid & awready || |aw_resp_cnt)
                w_next_state = W_ADDR_RESP;

            // 数据先成功
            else if (wvalid & wready || |wd_resp_cnt)
                w_next_state = W_DATA_RESP;

            else
                w_next_state = W_REQ_START;

        W_ADDR_RESP:
            if (wvalid & wready)
                w_next_state = W_REQ_END;
            else
                w_next_state = W_ADDR_RESP;

        W_DATA_RESP:
            if (awvalid & awready)
                w_next_state = W_REQ_END;
            else
                w_next_state = W_DATA_RESP;

        W_REQ_END:
            if (bvalid & bready)
                w_next_state = IDLE;
            else
                w_next_state = W_REQ_END;

        default:
            w_next_state = IDLE;
    endcase
end

assign awvalid = w_current_state[1] | w_current_state[3];
assign wvalid  = w_current_state[1] | w_current_state[2];

//////////////////////////////////////////////////////////////////////////////////
// 写响应 FSM（B）
//////////////////////////////////////////////////////////////////////////////////

localparam B_START = 5'b00010;
localparam B_END   = 5'b00100;

always @(posedge aclk) begin
    if (!aresetn)
        b_current_state <= IDLE;
    else
        b_current_state <= b_next_state;
end

always @(*) begin
    case (b_current_state)
        IDLE:
            // 等待 W_REQ_END 状态拉起 bready
            if (bready)
                b_next_state = B_START;
            else
                b_next_state = IDLE;

        B_START:
            if (bvalid & bready)
                b_next_state = B_END;
            else
                b_next_state = B_START;

        B_END:
            b_next_state = IDLE;

        default:
            b_next_state = IDLE;
    endcase
end

assign bready = w_current_state[4];  // 只有 W_REQ_END 状态允许写响应

//////////////////////////////////////////////////////////////////////////////////
// 读地址寄存器（ID + 地址 + size）
//////////////////////////////////////////////////////////////////////////////////

always @(posedge aclk) begin
    if (!aresetn) begin
        arid    <= 0;
        araddr  <= 0;
        arsize  <= 0;
        {arlen, arburst, arlock, arcache, arprot} <= {8'd0,2'b01,1'b0,4'd0,3'd0};
    end
    else if (ar_current_state == IDLE) begin
        // ID 选择：data 读=1，inst 读=0
        arid   <= {3'b0, data_sram_req & ~data_sram_wr};

        // 地址选择：data 优先
        araddr <= (data_sram_req & ~data_sram_wr) ? data_sram_addr : inst_sram_addr;

        // size 选择
        arsize <= (data_sram_req & ~data_sram_wr) ? 
                  {1'b0, data_sram_size} :
                  {1'b0, inst_sram_size};
    end
end

//////////////////////////////////////////////////////////////////////////////////
// 写地址寄存器
//////////////////////////////////////////////////////////////////////////////////

always @(posedge aclk) begin
    if (!aresetn) begin
        awaddr <= 0;
        awsize <= 0;
        {awlen, awburst, awlock, awcache, awprot, awid} <=
            {8'd0,2'b01,1'b0,4'd0,3'd0,4'd1};
    end
    else if (w_current_state == IDLE) begin
        awaddr <= data_sram_addr;
        awsize <= {1'b0, data_sram_size};
    end
end

//////////////////////////////////////////////////////////////////////////////////
// 写数据寄存器
//////////////////////////////////////////////////////////////////////////////////

always @(posedge aclk) begin
    if (!aresetn) begin
        wstrb <= 0;
        wdata <= 0;
        {wid, wlast} <= {4'd1, 1'b1};
    end
    else if (w_current_state == IDLE) begin
        wstrb <= data_sram_wstrb;
        wdata <= data_sram_wdata;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// 读写冲突（读写同一个地址时读要阻塞）
//////////////////////////////////////////////////////////////////////////////////

assign read_block =
    (araddr == awaddr) &
    (|w_current_state[4:1]) &
    ~b_current_state[2];

//////////////////////////////////////////////////////////////////////////////////
// 读数据缓冲（根据 rid 写入）
//////////////////////////////////////////////////////////////////////////////////

always @(posedge aclk) begin
    if (!aresetn)
        {buf_rdata[1], buf_rdata[0]} <= 64'b0;
    else if (rvalid & rready)
        buf_rdata[rid] <= rdata;
end

assign data_sram_rdata = buf_rdata[1];
assign inst_sram_rdata = buf_rdata[0];

//////////////////////////////////////////////////////////////////////////////////
// addr_ok / data_ok：SRAM 接口握手
//////////////////////////////////////////////////////////////////////////////////

assign data_sram_addr_ok =
       arid[0] & arvalid & arready |   // data read 发出地址
       wid[0] & awvalid & awready;     // data write 发出地址

assign data_sram_data_ok =
       rid_r[0] & (r_current_state[2]|con_read_reg)| // data read 收到数据
       bid[0] & bvalid & bready;       // data write 收到响应

assign inst_sram_addr_ok =
       ~arid[0] & arvalid & arready;   // inst read 发出地址

assign inst_sram_data_ok =
       ~rid_r[0] & (r_current_state[2]|r_current_state[3])| // inst read 收到数据
       ~bid[0] & bvalid & bready;

always @(posedge aclk) begin
    if (!aresetn)
        rid_r <= 0;
    else if (rvalid & rready)
        rid_r <= rid;
end

endmodule
