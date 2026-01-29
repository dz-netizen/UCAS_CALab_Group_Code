// ============================================================
// Top module of the CPU
// ����
//   1. CPU ���� mycpu_core
//   2. AXI <-> SRAM �Ž� my_bridge_sram_axi
//   3. ���Ⱪ¶ AXI �ӿڡ�debug д�ؽӿ�
// ============================================================

module mycpu_top( 
    input  wire        aclk,       // AXI ʱ��
    input  wire        aresetn,    // AXI ��λ������Ч��

    // ---------------- AXI Read Requie Channel ----------------
    output wire [ 3:0] arid,       // ������ ID
    output wire [31:0] araddr,     // �������ַ
    output wire [ 7:0] arlen,      //�������䳤�ȣ����ݴ���������
    output wire [ 2:0] arsize,     // ���������С�����ݴ���ÿ�ĵ��ֽ�����
    output wire [ 1:0] arburst,    // ��������
    output wire [ 1:0] arlock,     // ԭ����
    output wire [ 3:0] arcache,    // Cache ����
    output wire [ 2:0] arprot,     // ��������
    output wire        arvalid,    // �������ַ��Ч
    input  wire        arready,    // �������ַ�����ź�(�ӷ�׼�����ܵ�ַ���䣩

    // ---------------- AXI Read response Channel ----------------
    input  wire [ 3:0] rid,        // ���صĶ� ID
    input  wire [31:0] rdata,      // ���ص�����
    input  wire [ 1:0] rresp,      // ����Ӧ [���Ժ���]
    input  wire        rlast,       // ���������һ�����ݵ�ָʾ�ź�
    input  wire        rvalid,      // ������������Ч
    output wire        rready,      // ����׼���ý���

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
    input  wire        bvalid,  //д������Ӧ��Ч
    output wire        bready,  //д������Ӧ�����ź�

    // ---------------- Debug Trace Interface ----------------
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);


    // ============================================================
    // SRAM-like interface wires (Instruction)
    // CPU ���Ž�֮��� SRAM �ӿ�
    // ============================================================
    wire        inst_sram_req;        // ����
    wire        inst_sram_wr;         // ��/д
    wire [ 1:0] inst_sram_size;       // ���ʴ�С
    wire [ 3:0] inst_sram_wstrb;      // �ֽ�д����
    wire [31:0] inst_sram_addr;       // ���ʵ�ַ
    wire [31:0] inst_sram_wdata;      // д����
    wire        inst_sram_addr_ok;    // ��ַ�׶�����
    wire        inst_sram_data_ok;    // ������Ч
    wire [31:0] inst_sram_rdata;      // ��������

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

    //============ icache ===================

    wire    icache_rd_req;
    wire [2:0] icache_rd_type;
    wire [31:0] icache_rd_addr;

    wire    icache_wr_rdy = 1'b1;

    wire    icache_rd_rdy;
    wire    icache_ret_valid;
    wire [31:0]    icache_ret_data;
    wire    icache_ret_last;
    
    wire    icache_wr_req = 1'b0;
    wire [2:0]  icache_wr_type = 3'b000;
    wire [31:0] icache_wr_addr = 32'b0;
    wire [3:0] icache_wr_wstrb = 4'b0000;
    wire [31:0] icache_wr_data = 32'b0;

    wire [31:0]   inst_sram_vaddr;
    wire [31:0]   data_sram_vaddr;

    wire [3:0]   icache_wstrb;
    wire [31:0]   icache_wdata;

    wire [31:0]  icache_rdata;

    wire    icache_addr_ok;
    wire    icache_data_ok;

    // cache write-back outputs (icache is read-only in this design, but ports must be connected)
    wire        icache_wb_wr_req;
    wire [ 2:0] icache_wb_wr_type;
    wire [31:0] icache_wb_wr_addr;
    wire [ 3:0] icache_wb_wr_wstrb;
    wire [127:0] icache_wb_wr_data;

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
        .inst_sram_addr_ok  (icache_addr_ok     ),
        .inst_sram_data_ok  (icache_data_ok     ),
        .inst_sram_rdata    (icache_rdata       ),

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

        // Debug д�ؿ�
        .debug_wb_pc        (debug_wb_pc        ),
        .debug_wb_rf_we     (debug_wb_rf_we     ),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum   ),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata  ),

        //virture   address
        .inst_sram_vaddr    (inst_sram_vaddr),
        .data_sram_vaddr    (data_sram_vaddr)
    ); 


    // ============================================================
    // AXI Bridge (SRAM �� AXI)
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

        // // --- Inst SRAM ---
        // .inst_sram_req      (inst_sram_req      ),
        // .inst_sram_wr       (inst_sram_wr       ),
        // .inst_sram_size     (inst_sram_size     ),
        // .inst_sram_addr     (inst_sram_addr     ),
        // .inst_sram_wstrb    (inst_sram_wstrb    ),
        // .inst_sram_wdata    (inst_sram_wdata    ),
        // .inst_sram_addr_ok  (inst_sram_addr_ok  ),
        // .inst_sram_data_ok  (inst_sram_data_ok  ),
        // .inst_sram_rdata    (inst_sram_rdata    ),

        // --- icache ---
        .icache_rd_req(icache_rd_req),
        .icache_rd_type(icache_rd_type),
        .icache_rd_addr(icache_rd_addr),

        .icache_rd_rdy(icache_rd_rdy),

        .icache_ret_valid(icache_ret_valid),
        .icache_ret_last(icache_ret_last),
        .icache_ret_data(icache_ret_data),

        .icache_wr_req(icache_wr_req),
        .icache_wr_type(icache_wr_type),
        .icache_wr_addr(icache_wr_addr),
        .icache_wr_wstrb(icache_wr_wstrb),
        .icache_wr_data(icache_wr_data),

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

cache icache(
        .clk    (aclk),
        .resetn(aresetn),

        // icache <=> cpu
        .valid(inst_sram_req),
        .op(inst_sram_wr),
        .index(inst_sram_vaddr[11:4]),
        .tag(inst_sram_addr[31:12]),
        .offset(inst_sram_vaddr[3:0]),
        .wstrb(icache_wstrb),
        .wdata(icache_wdata),

        .addr_ok(icache_addr_ok),
        .data_ok(icache_data_ok),
        .rdata(icache_rdata),

        // icache <=> axi
        .rd_req(icache_rd_req),
        .rd_type(icache_rd_type),
        .rd_addr(icache_rd_addr),

        .wr_rdy(icache_wr_rdy),

        .rd_rdy(icache_rd_rdy),
        .ret_valid(icache_ret_valid),
        .ret_last(icache_ret_last),
        .ret_data(icache_ret_data),

        .wr_req (icache_wb_wr_req),
        .wr_type(icache_wb_wr_type),
        .wr_addr(icache_wb_wr_addr),
        .wr_wstrb(icache_wb_wr_wstrb),
        .wr_data(icache_wb_wr_data)
);

    // Instruction fetch is read-only
    assign icache_wstrb = inst_sram_wstrb;
    assign icache_wdata = inst_sram_wdata;

endmodule
