module alu(
  input  wire clk,
  input  wire reset,
    input  wire exe_valid,
  input  wire [18:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,
  output wire dout_tvalid
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate

wire        op_mul_w;
wire        op_mulh_w;
wire        op_mulh_wu;
wire        op_div_w;
wire        op_div_wu;
wire        op_mod_w;
wire        op_mod_wu;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];

assign op_mul_w   = alu_op[12];
assign op_mulh_w  = alu_op[13];
assign op_mulh_wu  = alu_op[14];
assign op_div_w   = alu_op[15];
assign op_div_wu  = alu_op[16];
assign op_mod_w   = alu_op[17];
assign op_mod_wu  = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;

wire [31:0] mul_w_result;
wire [31:0] mulh_w_result;
wire [31:0] mulh_wu_result;
wire [31:0] div_w_result;
wire [31:0] div_wu_result;
wire [31:0] mod_w_result;
wire [31:0] mod_wu_result;


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;


// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5


assign sr_result   = sr64_result[31:0];

 /*
==================================================
 mul result
==================================================
 */
wire [63:0] unsigned_prod, signed_prod;
assign unsigned_prod = alu_src1 * alu_src2;
assign signed_prod   = $signed(alu_src1) * $signed(alu_src2);
 
 assign mul_w_result    =signed_prod[31:0]  ;
 assign mulh_w_result   =signed_prod[63:32]  ;
 assign mulh_wu_result  =unsigned_prod[63:32];
 
 /*
==================================================
 div result
==================================================
 */
 reg caculating;
 
 //signed
 reg signed_dividend_tvalid;
 wire signed_dividend_tready;
 reg signed_divisor_tvalid;
 wire signed_divisor_tready;
 wire signed_dout_tvalid;
 wire [63:0] signed_product_div;
 
 //unsigned
 reg unsigned_dividend_tvalid;
 wire unsigned_dividend_tready;
 reg unsigned_divisor_tvalid;
 wire unsigned_divisor_tready;
 wire unsigned_dout_tvalid;
 wire [63:0] unsigned_product_div;
 
 assign div_w_result=signed_product_div[63:32];
 assign mod_w_result=signed_product_div[31:0];
 
 always @(posedge clk)begin
    if(reset)begin
        caculating<=1'b0;
    end
    else if(
    (signed_dividend_tvalid&signed_dividend_tready&
    signed_divisor_tvalid&signed_divisor_tready&~signed_dout_tvalid)|
    (unsigned_dividend_tvalid&unsigned_dividend_tready&
    unsigned_divisor_tvalid&unsigned_divisor_tready&~unsigned_dout_tvalid)    
    )begin
        caculating<=1'b1;
    end 
    else if(signed_dout_tvalid|unsigned_dout_tvalid)begin
        caculating<=1'b0;
    end
 end
 always@(posedge clk)begin
    if(reset)begin
        signed_dividend_tvalid<=1'b0;
        signed_divisor_tvalid<=1'b0; 
    end
    else if(exe_valid && (op_div_w|op_mod_w) & ~caculating)begin
        signed_dividend_tvalid<=1'b1;
        signed_divisor_tvalid<=1'b1;
    end
    else if(caculating)begin
        signed_dividend_tvalid<=1'b0;
        signed_divisor_tvalid<=1'b0;         
    end    
end 

signed_div signed_div(
    .aclk(clk),
    .s_axis_dividend_tdata(alu_src1),
    .s_axis_dividend_tready(signed_dividend_tready),
    .s_axis_dividend_tvalid(signed_dividend_tvalid),
    .s_axis_divisor_tdata(alu_src2),
    .s_axis_divisor_tready(signed_divisor_tready),
    .s_axis_divisor_tvalid(signed_divisor_tvalid),
    .m_axis_dout_tdata(signed_product_div),
    .m_axis_dout_tvalid(signed_dout_tvalid)
 );

 
assign div_wu_result=unsigned_product_div[63:32];
assign mod_wu_result=unsigned_product_div[31:0];

always@(posedge clk)begin
    if(reset)begin
       unsigned_dividend_tvalid<=1'b0;
       unsigned_divisor_tvalid<=1'b0; 
    end
     else if(exe_valid && (op_div_wu|op_mod_wu) & ~caculating)begin
       unsigned_dividend_tvalid<=1'b1;        
       unsigned_divisor_tvalid<=1'b1;
    end 
    else if(caculating)begin
       unsigned_dividend_tvalid<=1'b0;
       unsigned_divisor_tvalid<=1'b0;         
    end
end 
 
 unsigned_div unsigned_div(
    .aclk(clk),
    .s_axis_dividend_tdata(alu_src1),
    .s_axis_dividend_tready(unsigned_dividend_tready),
    .s_axis_dividend_tvalid(unsigned_dividend_tvalid),
    .s_axis_divisor_tdata(alu_src2),
    .s_axis_divisor_tready(unsigned_divisor_tready),
    .s_axis_divisor_tvalid(unsigned_divisor_tvalid),
    .m_axis_dout_tdata(unsigned_product_div),
    .m_axis_dout_tvalid(unsigned_dout_tvalid)
 );
 
 assign dout_tvalid=~(((op_div_w|op_mod_w)&~signed_dout_tvalid)|((op_div_wu|op_mod_wu)&~unsigned_dout_tvalid));
 
// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_mul_w       }} & mul_w_result)
                  | ({32{op_mulh_w       }} & mulh_w_result)
                  | ({32{op_mulh_wu       }} & mulh_wu_result)
                  | ({32{op_div_w&dout_tvalid}} &div_w_result)
                  | ({32{op_div_wu&dout_tvalid}} & div_wu_result)
                  | ({32{op_mod_w&dout_tvalid}} & mod_w_result)
                  | ({32{op_mod_wu&dout_tvalid}} & mod_wu_result)
                  ;

endmodule
