`timescale 1ns/1ns
module ramflag_tb();

reg clk;
reg rst_n;
reg O_pix_clk;
reg [7:0] R;
reg [7:0] G;
reg [7:0] B;
wire r_Vsync_0 ;
wire r_Hsync_0;
reg r_DE_0;
wire sdbpflag_wire;
wire [15:0] wtdina_wire;
wire [9:0] wtaddr_wire;

always #14 O_pix_clk = ~O_pix_clk;
always #40 clk = ~clk;


parameter BLOCK_SIZE = 53;      	// 每个像素块的边长
parameter IMAGE_WIDTH = 1280;    	// 屏幕宽度
parameter IMAGE_WIDTH_H = 1420;
parameter IMAGE_HEIGHT = 800;     	// 屏幕高度
parameter IMAGE_HEIGHT_H = 824;
parameter TOTAL_BLOCKS = 360;     	// 总块数
parameter PIXELS_PER_BLOCK = 2809; 	// 每个块的总像素数(53*53)
parameter HPW = 42; //行使能像素
parameter HFP = 51; //行场前延像素
parameter HBP = 47; //行场后沿像素
parameter VPW = 2; //列使能行数
parameter VFP = 1; //列场前行数
parameter VBP = 21; //列场后行数
parameter CNT_COUNT =2500; //cnt的值


initial begin
rst_n = 1;
end

reg [10:0]hcnt

always@(posedge O_pix_clk or negedge rst_n)begin
	if (!rst_n)begin
	hcnt <= 0;
	end else if(hcnt == IMAGE_WIDTH_H - 1)
	hcnt <= 0;
	else begin
	hcnt <= hcnt + 1;
	end
end
wire hs_end;
assign r_Hsync_0 = (hcnt <=HPW - 1)? 1:0;

reg vcnt[9:0]
always@(posedge O_pix_clk or negedge rst_n)begin
	if (!rst_n)begin
	vcnt <= 0;
	else if(hcnt == IMAGE_WIDTH_H - 1)
		if(vcnt >= IMAGE_HEIGHT_H - 1)
		vcnt<= 0;
		else
		vcnt <= vcnt + 1;
	else 
	vcnt <= vcnt;
end
	
assign r_Vsync_0 <= (vcnt <= VPW - 1)?1:0;
	
	
always@(posedge O_pix_clk or negedge rst_n)begin
	if(!rst_n==0)begin
	R <= 0;
	G <= 0;
	B <= 0;
	r_DE_0 <= 0;
	r_Hsync_0 <= 0;
	r_Vsync_0 <= 0;
	end else if(r_Vsync_0 == 0&&r_Vsync_0==0)begin
	R <= R + 1;
	G <= G + 1;
	B <= B + 1;
	end else begin
	R <= 0;
	G <= 0;
	B <= 0;
	end
end
ramflag_1 r1(
	.clk(clk),                       // 
    .rst_n(rst_n),
    .O_pix_clk(O_pix_clk),           //像素时钟
    .rx_sclk_t(rx_sclk_t),            //三倍像素时钟
    .R(R),        // 红色通道
    .G(G),        // 绿色通道
    .B(B),        // 蓝色通道
    .r_Vsync_0(r_Vsync_0) ,
    .r_Hsync_0(r_Hsync_0),
    .r_DE_0(r_DE_0),
    .sdbpflag_wire(sdbpflag_wire),
    .wtdina_wire(wtdina_wire),
    .wtaddr_wire(wtaddr_wire)
endmodule