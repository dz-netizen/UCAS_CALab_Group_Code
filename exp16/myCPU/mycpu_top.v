// ============================================================
// Top module of the CPU
// 负责：
//   1. CPU 核心 mycpu_core
//   2. AXI <-> SRAM 桥接 my_bridge_sram_axi
//   3. 对外暴露 AXI 接口、debug 写回接口
// ============================================================

module mycpu_top( 
    input  wire        aclk,       // AXI 时钟
    input  wire        aresetn,    // AXI 复位（低有效）

    // ---------------- AXI Read Requie Channel ----------------
    output wire [ 3:0] arid,       // 读请求 ID
    output wire [31:0] araddr,     // 读请求地址
    output wire [ 7:0] arlen,      //读请求传输长度（数据传输拍数）
    output wire [ 2:0] arsize,     // 读请求传输大小（数据传输每拍的字节数）
    output wire [ 1:0] arburst,    // 传输类型
    output wire [ 1:0] arlock,     // 原子锁
    output wire [ 3:0] arcache,    // Cache 属性
    output wire [ 2:0] arprot,     // 保护类型
    output wire        arvalid,    // 读请求地址有效
    input  wire        arready,    // 读请求地址握手信号(从方准备接受地址传输）

    // ---------------- AXI Read response Channel ----------------
    input  wire [ 3:0] rid,        // 返回的读 ID
    input  wire [31:0] rdata,      // 返回的数据
    input  wire [ 1:0] rresp,      // 读响应 [可以忽略]
    input  wire        rlast,       // 读请求最后一拍数据的指示信号
    input  wire        rvalid,      // 读请求数据有效
    output wire        rready,      // 主机准备好接收

    // ---------------- AXI Write Require Channel ----------------
    output wire [ 3:0] awid,    
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    // ---------------- AXI Write Data Channel ----------------
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    // ---------------- AXI Write Response Channel ----------------
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,  //写请求响应有效
    output wire        bready,  //写请求响应握手信号

    // ---------------- Debug Trace Interface ----------------
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);


    // ============================================================
    // SRAM-like interface wires (Instruction)
    // CPU 与桥接之间的 SRAM 接口
    // ============================================================
    wire        inst_sram_req;        // 请求
    wire        inst_sram_wr;         // 读/写
    wire [ 1:0] inst_sram_size;       // 访问大小
    wire [ 3:0] inst_sram_wstrb;      // 字节写掩码
    wire [31:0] inst_sram_addr;       // 访问地址
    wire [31:0] inst_sram_wdata;      // 写数据
    wire        inst_sram_addr_ok;    // 地址阶段握手
    wire        inst_sram_data_ok;    // 数据有效
    wire [31:0] inst_sram_rdata;      // 读回数据

    // ============================================================
    // SRAM-like interface wires (Data)
    // ============================================================
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [ 1:0] data_sram_size;
    wire [ 3:0] data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_addr_ok;
    wire        data_sram_data_ok;
    wire [31:0] data_sram_rdata;


    // ============================================================
    // CPU Core
    // ============================================================
    mycpu_core my_core(
        .clk            (aclk       ),
        .resetn         (aresetn    ),

        // --- Inst SRAM ---
        .inst_sram_req      (inst_sram_req      ),
        .inst_sram_wr       (inst_sram_wr       ),
        .inst_sram_size     (inst_sram_size     ),
        .inst_sram_wstrb    (inst_sram_wstrb    ),
        .inst_sram_addr     (inst_sram_addr     ),
        .inst_sram_wdata    (inst_sram_wdata    ),
        .inst_sram_addr_ok  (inst_sram_addr_ok  ),
        .inst_sram_data_ok  (inst_sram_data_ok  ),
        .inst_sram_rdata    (inst_sram_rdata    ),

        // AXI id（仅用于指令读）
        .arid           (arid               ),

        // --- Data SRAM ---
        .data_sram_req      (data_sram_req      ),
        .data_sram_wr       (data_sram_wr       ),
        .data_sram_size     (data_sram_size     ),
        .data_sram_wstrb    (data_sram_wstrb    ),
        .data_sram_addr     (data_sram_addr     ),
        .data_sram_wdata    (data_sram_wdata    ),
        .data_sram_addr_ok  (data_sram_addr_ok  ),
        .data_sram_data_ok  (data_sram_data_ok  ),
        .data_sram_rdata    (data_sram_rdata    ),

        // Debug 写回口
        .debug_wb_pc        (debug_wb_pc        ),
        .debug_wb_rf_we     (debug_wb_rf_we     ),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum   ),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata  )
    ); 


    // ============================================================
    // AXI Bridge (SRAM → AXI)
    // ============================================================
    bridge_sram_axi my_bridge_sram_axi(
        .aclk               (aclk               ),
        .aresetn            (aresetn            ),

        // --- AXI Read Address ---
        .arid               (arid               ),
        .araddr             (araddr             ),
        .arlen              (arlen              ),
        .arsize             (arsize             ),
        .arburst            (arburst            ),
        .arlock             (arlock             ),
        .arcache            (arcache            ),
        .arprot             (arprot             ),
        .arvalid            (arvalid            ),
        .arready            (arready            ),

        // --- AXI Read Data ---
        .rid                (rid                ),
        .rdata              (rdata              ),
        .rvalid             (rvalid             ),
        .rlast              (rlast              ),
        .rready             (rready             ),

        // --- AXI Write Address ---
        .awid               (awid               ),
        .awaddr             (awaddr             ),
        .awlen              (awlen              ),
        .awsize             (awsize             ),
        .awburst            (awburst            ),
        .awlock             (awlock             ),
        .awcache            (awcache            ),
        .awprot             (awprot             ),
        .awvalid            (awvalid            ),
        .awready            (awready            ),

        // --- AXI Write Data ---
        .wid                (wid                ),
        .wdata              (wdata              ),
        .wstrb              (wstrb              ),
        .wlast              (wlast              ),
        .wvalid             (wvalid             ),
        .wready             (wready             ),

        // --- AXI Write Response ---
        .bid                (bid                ),
        .bvalid             (bvalid             ),
        .bready             (bready             ),

        // --- Inst SRAM ---
        .inst_sram_req      (inst_sram_req      ),
        .inst_sram_wr       (inst_sram_wr       ),
        .inst_sram_size     (inst_sram_size     ),
        .inst_sram_addr     (inst_sram_addr     ),
        .inst_sram_wstrb    (inst_sram_wstrb    ),
        .inst_sram_wdata    (inst_sram_wdata    ),
        .inst_sram_addr_ok  (inst_sram_addr_ok  ),
        .inst_sram_data_ok  (inst_sram_data_ok  ),
        .inst_sram_rdata    (inst_sram_rdata    ),

        // --- Data SRAM ---
        .data_sram_req      (data_sram_req      ),
        .data_sram_wr       (data_sram_wr       ),
        .data_sram_size     (data_sram_size     ),
        .data_sram_addr     (data_sram_addr     ),
        .data_sram_wstrb    (data_sram_wstrb    ),
        .data_sram_wdata    (data_sram_wdata    ),
        .data_sram_addr_ok  (data_sram_addr_ok  ),
        .data_sram_data_ok  (data_sram_data_ok  ),
        .data_sram_rdata    (data_sram_rdata    )
    );

endmodule
