// Cache module (2-way set-associative, 4-word block)
// 组织：2-way，每路 4 个 32-bit word（4 banks），256 行
module cache(
    input wire        clk,
    input wire        resetn,

    // cache与CPU的交互接口
    input wire        valid,  // CPU 访问cache 请求的有效信号
    input wire        op,     // 读或写
    input wire [ 7:0] index,  // vaddr[11:4] 索引
    input wire [19:0] tag,    // paddr[31:12] 标签
    input wire [ 3:0] offset, // vaddr[3:0] 偏移量
    input wire [ 3:0] wstrb,  // 字节写使能
    input wire [31:0] wdata,  // 写数据

    // 1: uncached access (bypass cache, no allocate)
    input wire        uncache,
    
    output wire        addr_ok, // 地址传输完成信号
    output wire        data_ok, // 数据传输完成信号
    output wire [31:0] rdata,   // cache读数据

    // cache与总线的交互接口
    output wire        rd_req,   // 读请求有效信号
    output wire [ 2:0] rd_type,  // 读请求类型
    output wire [31:0] rd_addr,  // 读请求起始地址

    input  wire        wr_rdy,    // 写请求能否被接收的握手信号

    input  wire        rd_rdy,   // 读请求是否被内存接收
    input  wire        ret_valid,// 返回数据有效
    input  wire        ret_last, // 读请求的最后一个返回数据
    input  wire [31:0] ret_data, // 读返回数据

    output wire        wr_req,   // 写请求有效信号
    output wire [ 2:0] wr_type,  // 写请求类型
    output wire [31:0] wr_addr,  // 写请求起始地址
    output wire [ 3:0] wr_wstrb,  // 写操作字节掩码，仅在 WRITE_BYTE, WRITE_HALFWORD, WRITE_WORD下有意义，for uncached 指令
    output wire [127:0] wr_data // 写数据

    );


wire lookup; 
wire lookup_en;
wire replace;
wire refill;
wire writehit;
wire uc_rd_req;
wire uc_rd_resp;
wire uc_wr_req;
wire uc_wr_wait;

// CPU-->cache 请求类型 (op)
localparam READ  = 1'b0;
localparam WRITE = 1'b1;

// cache-->内存 读请求类型 (rd_type)
localparam READ_BYTE     = 3'b000; //1字节
localparam READ_HALFWORD = 3'b001; //2字节
localparam READ_WORD     = 3'b010; //4字节
localparam READ_BLOCK    = 3'b100; 

// cache-->内存 写请求类型 (wr_type)
localparam WRITE_BYTE     = 3'b000;
localparam WRITE_HALFWORD = 3'b001;
localparam WRITE_WORD     = 3'b010;
localparam WRITE_BLOCK    = 3'b100;

reg         reset;
always @(posedge clk)begin
    reset <= ~resetn;
end

// tagv_ram 和 data_bank_ram
wire [ 7:0] tagv_addr;
wire [20:0] tagv_wdata;
wire [20:0] tagv_w0_rdata, tagv_w1_rdata;
wire        tagv_w0_en, tagv_w1_en;
wire        tagv_w0_we, tagv_w1_we;

wire [ 7:0] data_addr;
wire [31:0] data_wdata;
wire [31:0] data_w0_b0_rdata, data_w0_b1_rdata, data_w0_b2_rdata, data_w0_b3_rdata, data_w1_b0_rdata, data_w1_b1_rdata, data_w1_b2_rdata, data_w1_b3_rdata;
wire        data_w0_b0_en, data_w0_b1_en, data_w0_b2_en, data_w0_b3_en, data_w1_b0_en, data_w1_b1_en, data_w1_b2_en, data_w1_b3_en;
wire [ 3:0] data_w0_b0_we, data_w0_b1_we, data_w0_b2_we, data_w0_b3_we, data_w1_b0_we, data_w1_b1_we, data_w1_b2_we, data_w1_b3_we;



// Dirty
reg [255:0] dirty_way0;
reg [255:0] dirty_way1;


// 主状态机的状态（单状态机：包含写命中提交阶段）
// Add an explicit WRITEBACK stage so wr_req and rd_req are not asserted together.
localparam IDLE       = 11'b00000000001,
           LOOKUP     = 11'b00000000010,
           WRITEHIT   = 11'b00000000100,
           MISS       = 11'b00000001000,
           WRITEBACK  = 11'b00000010000,
           REPLACE    = 11'b00000100000,
           REFILL     = 11'b00001000000,
           UC_RD_REQ  = 11'b00010000000,
           UC_RD_RESP = 11'b00100000000,
           UC_WR_REQ  = 11'b01000000000,
           UC_WR_WAIT = 11'b10000000000;

reg [10:0] current_state;
reg [10:0] next_state;


// request buffer
reg        reg_op;
reg        reg_uncache;
reg [ 7:0] reg_index;
reg [19:0] reg_tag;
reg [ 3:0] reg_offset;
reg [ 3:0] reg_wstrb;
reg [31:0] reg_wdata;

// miss buffer
reg [ 1:0] refill_bank;  

// write hit latch (so WRITEHIT doesn't depend on tag compare timing)
reg        hit_way_reg; // 0->way0, 1->way1

// reg_bank: 当前请求在 reg_* 寄存器里选择的 bank
// offset_bank: 新到来请求的 bank，用于判断 bank 冲突
// refill_target: 表示当前回填的 bank 是否是 reg 指向的那个 bank
wire [1:0] reg_bank      = reg_offset[3:2];
wire [1:0] offset_bank   = offset[3:2];
wire       refill_target = (refill_bank == reg_bank);


// tag compare
wire        way0_v, way1_v;
wire [19:0] way0_tag, way1_tag;
wire        way0_hit, way1_hit;
wire        cache_hit;

// data select
wire [127:0] way0_load_block, way1_load_block;
wire [ 31:0] way0_load_word, way1_load_word;
wire [ 31:0] load_res;

//replace
wire         replace_way;
wire   replace_block_dirty;




// refill 
wire [31:0] refill_word;
wire [31:0] mixed_word;

//============================= 主状态机 =======================================
always @(posedge clk)begin
    if(reset)
        current_state <= IDLE;
    else 
        current_state <= next_state;
end

always @(*)begin
    case(current_state)
    IDLE:begin
        if(valid)
            next_state = LOOKUP;
        else
            next_state = IDLE;
    end
    LOOKUP:begin
        if (reg_uncache) begin
            if (reg_op == READ)
                next_state = UC_RD_REQ;
            else
                next_state = UC_WR_REQ;
        end
        else if(~cache_hit)
            next_state = MISS;
        else if(reg_op == WRITE)
            next_state = WRITEHIT;
        else
            next_state = IDLE;
    end
    WRITEHIT:begin
        next_state = IDLE;
    end
    MISS:begin
        // If victim is clean, go issue refill read.
        // If victim is dirty, wait for write channel ready then perform WRITEBACK.
        if(~replace_block_dirty)
            next_state = REPLACE;
        else if(wr_rdy)
            next_state = WRITEBACK;
        else
            next_state = MISS;
    end
    WRITEBACK: begin
        // Hold write request until the bridge indicates it can accept it.
        if(wr_rdy)
            next_state = REPLACE;
        else
            next_state = WRITEBACK;
    end
    REPLACE:begin
        if(rd_rdy)
            next_state = REFILL;
        else
            next_state = REPLACE;
    end
    REFILL:begin
        if(ret_valid & ret_last)
            next_state = IDLE;
        else
            next_state = REFILL;
    end
    UC_RD_REQ: begin
        if (rd_rdy)
            next_state = UC_RD_RESP;
        else
            next_state = UC_RD_REQ;
    end
    UC_RD_RESP: begin
        if (ret_valid && ret_last)
            next_state = IDLE;
        else
            next_state = UC_RD_RESP;
    end
    UC_WR_REQ: begin
        if (wr_rdy)
            next_state = UC_WR_WAIT;
        else
            next_state = UC_WR_REQ;
    end
    UC_WR_WAIT: begin
        if (wr_rdy)
            next_state = IDLE;
        else
            next_state = UC_WR_WAIT;
    end
    endcase
end

// 控制信号
assign lookup = (current_state == IDLE) && valid;
assign writehit = (current_state == WRITEHIT);
assign replace = (current_state == MISS && ((~replace_block_dirty) || wr_rdy)) ||
                 (current_state == WRITEBACK) ||
                 (current_state == REPLACE);
assign refill = (current_state == REFILL);

assign uc_rd_req  = (current_state == UC_RD_REQ);
assign uc_rd_resp = (current_state == UC_RD_RESP);
assign uc_wr_req  = (current_state == UC_WR_REQ);
assign uc_wr_wait = (current_state == UC_WR_WAIT);

assign lookup_en = (current_state == IDLE) && valid;
                




//============================= look up  =============================

assign tagv_w0_en = lookup_en || ((replace || refill) && (replace_way == 1'b0));
assign tagv_w1_en = lookup_en || ((replace || refill) && (replace_way == 1'b1));

assign {way0_tag, way0_v} = tagv_w0_rdata;
assign {way1_tag, way1_v} = tagv_w1_rdata;
assign way0_hit = way0_v && (way0_tag == reg_tag);
assign way1_hit = way1_v && (way1_tag == reg_tag);
assign cache_hit = way0_hit || way1_hit;

assign tagv_wdata = {reg_tag, 1'b1}; 
assign tagv_addr  = {8{lookup_en}} & index |
                    {8{replace || refill}} & reg_index;

// tagv ram write enable: only write tag when refill is at the requested word
assign tagv_w0_we = refill && (replace_way == 1'b0) && ret_valid && refill_target;
assign tagv_w1_we = refill && (replace_way == 1'b1) && ret_valid && refill_target;




//dirty 表（同步写异步读） 
always @(posedge clk)begin
    if(reset)begin
        dirty_way0 <= 256'b0;
        dirty_way1 <= 256'b0;
    end
    else if(writehit)begin
        if(hit_way_reg == 1'b0)
            dirty_way0[reg_index] <= 1'b1;
        else
            dirty_way1[reg_index] <= 1'b1;
    end
    else if(refill)begin
        if(replace_way == 1'b0)
            dirty_way0[reg_index] <= 1'b0;
        else if(replace_way == 1'b1)
            dirty_way1[reg_index] <= 1'b0;
    end
end

//============================= replace ==============================================
// 2-way LRU metadata: 1 bit per set
// lru_way[i] == 0: way0 is LRU (victim)
// lru_way[i] == 1: way1 is LRU (victim)
reg  [255:0] lru_way;
reg          replace_way_reg;

wire replace_way_comb = (!way0_v) ? 1'b0 :
                        (!way1_v) ? 1'b1 :
                        lru_way[reg_index];

// Latch victim way once per miss, keep stable through REPLACE/REFILL
always @(posedge clk) begin
    if (reset) begin
        replace_way_reg <= 1'b0;
    end
    else if (current_state == LOOKUP && next_state == MISS) begin
        replace_way_reg <= replace_way_comb;
    end
end

assign replace_way = replace_way_reg;

// Update LRU on every cache hit (read or write) and when refill completes
always @(posedge clk) begin
    if (reset) begin
        lru_way <= 256'b0;
    end
    else if ((current_state == LOOKUP) && cache_hit && valid) begin
        if (way0_hit)
            lru_way[reg_index] <= 1'b1; // way1 becomes LRU
        else if (way1_hit)
            lru_way[reg_index] <= 1'b0; // way0 becomes LRU
    end
    else if ((current_state == REFILL) && ret_valid && ret_last) begin
        lru_way[reg_index] <= ~replace_way_reg;
    end
end

assign replace_block_dirty = (replace_way == 1'b0) && dirty_way0[reg_index] && way0_v 
                        || (replace_way == 1'b1) && dirty_way1[reg_index] && way1_v;


//================================ refill ================================

//request buffer    
always @(posedge clk)begin
    if(reset)begin
        reg_op <= 1'b0;
        reg_uncache <= 1'b0;
        reg_index <= 8'b0;
        reg_tag <= 20'b0;
        reg_offset <= 4'b0;
        reg_wstrb <= 4'b0;
        reg_wdata <= 32'b0;
    end
    // Must capture the request for both hit and miss
    else if(lookup_en == 1)begin
        reg_op <= op;
        reg_uncache <= uncache;
        reg_index <= index;
        reg_tag <= tag;
        reg_offset <= offset;
        reg_wstrb <= wstrb;
        reg_wdata <= wdata;
    end
end

// Latch hit way for write-hit commit stage
always @(posedge clk) begin
    if (reset) begin
        hit_way_reg <= 1'b0;
    end
    else if ((current_state == LOOKUP) && cache_hit) begin
        hit_way_reg <= way1_hit;
    end
end

// miss buffer 
always @(posedge clk)begin
    if(reset) begin
        refill_bank <= 2'b0;
    end
    // start of a new refill: align beat counter to the first returned word (bank0)
    // Use rd_rdy (read accepted) directly to avoid depending on next_state.
    else if((current_state == REPLACE) && rd_rdy) begin
        refill_bank <= 2'b0;
    end
    else if(current_state == REFILL) begin
        // Increment beat counter on each actually returned beat.
        // This keeps refill_bank aligned with the current ret_data even if ret_valid has bubbles.
        if(ret_valid)
            refill_bank <= refill_bank + 1'b1;
    end
end


assign data_w0_b0_en = lookup_en && (offset_bank == 2'b00) ||
                       writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b00) ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w0_b1_en = lookup_en && (offset_bank == 2'b01) ||
                       writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b01) ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w0_b2_en = lookup_en && (offset_bank == 2'b10) ||
                       writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b10) ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w0_b3_en = lookup_en && (offset_bank == 2'b11) ||
                       writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b11) ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w1_b0_en = lookup_en && (offset_bank == 2'b00) ||
                       writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b00) ||
                       (replace || refill) && (replace_way == 1'b1);
assign data_w1_b1_en = lookup_en && (offset_bank == 2'b01) ||
                       writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b01) ||
                       (replace || refill) && (replace_way == 1'b1);
assign data_w1_b2_en = lookup_en && (offset_bank == 2'b10) ||
                       writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b10) ||
                       (replace || refill) && (replace_way == 1'b1);
assign data_w1_b3_en = lookup_en && (offset_bank == 2'b11) ||
                       writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b11) ||
                       (replace || refill) && (replace_way == 1'b1);

assign data_w0_b0_we = {4{writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b00)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b0) && (refill_bank == 2'b00) && ret_valid}} & {4'b1111};
assign data_w0_b1_we = {4{writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b01)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b0) && (refill_bank == 2'b01) && ret_valid}} & {4'b1111};
assign data_w0_b2_we = {4{writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b10)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b0) && (refill_bank == 2'b10) && ret_valid}} & {4'b1111};
assign data_w0_b3_we = {4{writehit && (hit_way_reg == 1'b0) && (reg_bank == 2'b11)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b0) && (refill_bank == 2'b11) && ret_valid}} & {4'b1111};
assign data_w1_b0_we = {4{writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b00)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b1) && (refill_bank == 2'b00) && ret_valid}} & {4'b1111};
assign data_w1_b1_we = {4{writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b01)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b1) && (refill_bank == 2'b01) && ret_valid}} & {4'b1111};
assign data_w1_b2_we = {4{writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b10)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b1) && (refill_bank == 2'b10) && ret_valid}} & {4'b1111};
assign data_w1_b3_we = {4{writehit && (hit_way_reg == 1'b1) && (reg_bank == 2'b11)}} & reg_wstrb |
                       {4{refill && (replace_way == 1'b1) && (refill_bank == 2'b11) && ret_valid}} & {4'b1111};


assign mixed_word = {{reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24]},
                     {reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16]},
                     {reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8]},
                     {reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0]}};
assign refill_word = (refill_target && (reg_op == WRITE)) ? mixed_word : ret_data;

assign data_wdata = refill ? refill_word :
                            (writehit ? reg_wdata : 32'b0);

assign data_addr  = (replace || refill)? reg_index :
                                        (writehit ? reg_index :
                                                    (lookup_en ? index : 8'b0));


//================================ cache --> CPU  ================================
// addr_ok should only be asserted after the CPU issues a request (valid=1)
// and cache accepts it.
assign addr_ok = lookup_en;
assign data_ok = ((current_state == LOOKUP) && !reg_uncache && cache_hit && (reg_op == READ)) ||
                 (current_state == WRITEHIT) ||
                 ((current_state == REFILL) && ret_valid && refill_target) ||
                 (uc_rd_resp && ret_valid) ||
                 (uc_wr_wait && wr_rdy);
assign rdata   = load_res;

//================================ cache --> AXI ================================

// load 
assign way0_load_block = {data_w0_b3_rdata, data_w0_b2_rdata, data_w0_b1_rdata, data_w0_b0_rdata};
assign way1_load_block = {data_w1_b3_rdata, data_w1_b2_rdata, data_w1_b1_rdata, data_w1_b0_rdata};

assign way0_load_word = way0_load_block[reg_bank*32 +: 32];
assign way1_load_word = way1_load_block[reg_bank*32 +: 32];
assign load_res =
    ({32{way0_hit}} & way0_load_word) |
    ({32{way1_hit}} & way1_load_word) |
    ({32{(current_state == REFILL) || uc_rd_resp}} & ret_data);

assign rd_req = (current_state == REPLACE) || uc_rd_req;
assign rd_type = uc_rd_req ? READ_WORD : READ_BLOCK;
assign rd_addr = uc_rd_req ? {reg_tag, reg_index, reg_offset[3:2], 2'b00}
                            : {reg_tag, reg_index, 4'b0000};

assign wr_req = ((current_state == WRITEBACK) && replace_block_dirty) || uc_wr_req;
assign wr_type = uc_wr_req ? WRITE_WORD : WRITE_BLOCK;
assign wr_addr = uc_wr_req ? {reg_tag, reg_index, reg_offset[3:2], 2'b00} :
                 ({32{replace_way == 1'b0}} & {way0_tag, reg_index, 4'b0000} |
                  {32{replace_way == 1'b1}} & {way1_tag, reg_index, 4'b0000});
assign wr_wstrb = uc_wr_req ? reg_wstrb : 4'b1111;
assign wr_data = uc_wr_req ? {96'b0, reg_wdata} :
                 ({128{replace_way == 1'b0}} & way0_load_block |
                  {128{replace_way == 1'b1}} & way1_load_block);

// ============================== 实例化 ================================
// Tag V 域：每一路用 256*21 bit 的 ram 实现
tagv_ram tagv_way0(
    .addra(tagv_addr),
    .clka(clk),
    .dina(tagv_wdata),
    .douta(tagv_w0_rdata),
    .ena(tagv_w0_en),
    .wea(tagv_w0_we)
);
tagv_ram tagv_way1(
    .addra(tagv_addr),
    .clka(clk),
    .dina(tagv_wdata),
    .douta(tagv_w1_rdata),
    .ena(tagv_w1_en),
    .wea(tagv_w1_we)
);

// data block：每一路拆分成4个 bank，每个 bank 用 256*32 bit 的 ram 实现
data_bank_ram data_way0_bank0(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b0_rdata),
    .ena(data_w0_b0_en),
    .wea(data_w0_b0_we)
);
data_bank_ram data_way0_bank1(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b1_rdata),
    .ena(data_w0_b1_en),
    .wea(data_w0_b1_we)
);
data_bank_ram data_way0_bank2(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b2_rdata),
    .ena(data_w0_b2_en),
    .wea(data_w0_b2_we)
);
data_bank_ram data_way0_bank3(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b3_rdata),
    .ena(data_w0_b3_en),
    .wea(data_w0_b3_we)
);
data_bank_ram data_way1_bank0(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b0_rdata),
    .ena(data_w1_b0_en),
    .wea(data_w1_b0_we)
);
data_bank_ram data_way1_bank1(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b1_rdata),
    .ena(data_w1_b1_en),
    .wea(data_w1_b1_we)
);
data_bank_ram data_way1_bank2(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b2_rdata),
    .ena(data_w1_b2_en),
    .wea(data_w1_b2_we)
);
data_bank_ram data_way1_bank3(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b3_rdata),
    .ena(data_w1_b3_en),
    .wea(data_w1_b3_we)
);

endmodule
