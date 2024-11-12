// ==============0ooo===================================================0ooo===========
// =  Copyright (C) 2014-2020 Gowin Semiconductor Technology Co.,Ltd.
// =                     All rights reserved.
// ====================================================================================
// 
//  __      __      __
//  \ \    /  \    / /   [File name   ] lvds_video_top.v
//   \ \  / /\ \  / /    [Description ] LVDS Video
//    \ \/ /  \ \/ /     [Timestamp   ] Friday November 20 14:00:30 2020
//     \  /    \  /      [version     ] 1.0
//      \/      \/
//
// ==============0ooo===================================================0ooo===========
// Code Revision History :
// ----------------------------------------------------------------------------------
// Ver:    |  Author    | Mod. Date    | Changes Made:
// ----------------------------------------------------------------------------------
// V1.0    | Caojie     | 11/20/20     | Initial version 
// ----------------------------------------------------------------------------------
// ==============0ooo===================================================0ooo===========

module lvds_video_top
(
    input          I_clk       ,  //50MHz      
    input          I_rst_n     ,
    output [3:0]   O_led       , 
    input          I_clkin_p   ,  //LVDS Input
    input          I_clkin_n   ,  //LVDS Input
    input  [3:0]   I_din_p     ,  //LVDS Input
    input  [3:0]   I_din_n     ,  //LVDS Input    
    output         O_clkout_p  ,
    output         O_clkout_n  ,
    output [3:0]   O_dout_p    ,
    output [3:0]   O_dout_n    ,
    output         LE          ,
    output         DCLK        , //12.5M
    output         SDI         ,
    output         GCLK         ,
    output         scan1       ,
    output         scan2       ,
    output         scan3       , 
    output         scan4       
);

//======================================================
reg  [31:0] run_cnt;
wire        running;

//--------------------------
wire [7:0]  r_R_0;  // Red,   8-bit data depth
wire [7:0]  r_G_0;  // Green, 8-bit data depth
wire [7:0]  r_B_0;  // Blue,  8-bit data depth
wire        r_Vsync_0;
wire        r_Hsync_0;
wire        r_DE_0   ;

wire 		rx_sclk;

//===================================================
//LED test
always @(posedge I_clk or negedge I_rst_n)//I_clk
begin
    if(!I_rst_n)
        run_cnt <= 32'd0;
    else if(run_cnt >= 32'd50_000_000) //26bits=1秒
        run_cnt <= 32'd0;
    else
        run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd25_000_000) ? 1'b1 : 1'b0;//25bits半秒，没看懂

assign  O_led[0] = 1'b1;//在0-0.5秒时O_led==1111
assign  O_led[1] = 1'b1;
assign  O_led[2] = 1'b0;
assign  O_led[3] = running;

//==============================================================
//LVDS Reciver
LVDS_7to1_RX_Top LVDS_7to1_RX_Top_inst
(
    .I_rst_n        (I_rst_n    ),
    .I_clkin_p      (I_clkin_p  ),    // LVDS clock input pair
    .I_clkin_n      (I_clkin_n  ),    // LVDS clock input pair
    .I_din_p        (I_din_p    ),    // LVDS data input pair 0
    .I_din_n        (I_din_n    ),    // LVDS data input pair 0
    .O_pllphase     (           ),
    .O_pllphase_lock(           ),
    .O_clkpat_lock  (           ),
    .O_pix_clk      (rx_sclk    ),  
    .O_vs           (r_Vsync_0  ),
    .O_hs           (r_Hsync_0  ),
    .O_de           (r_DE_0     ),
    .O_data_r       (r_R_0      ),
    .O_data_g       (r_G_0      ),
    .O_data_b       (r_B_0      )
);
//LVDDS RX 计数
reg [12:0]cnt_hs;
reg [12:0]cnt_de;
reg [12:0]cnt_vs;
reg [12:0]cnt_vs_all;
wire    hs_pos;
wire    hs_neg;
wire    de_pos;
wire    de_neg;
reg     vs_r;
reg     vs_rr;
reg     hs_r;
reg     hs_rr;
reg     de_r;
reg     de_rr;
always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
        vs_r    <=0;
        vs_rr   <=0;
        hs_r    <=0;
        hs_rr   <=0;
        de_r    <=0;
        de_rr   <=0;
     end
    else begin
        vs_r <=r_Vsync_0;
        vs_rr<=vs_r;
        hs_r <=r_Hsync_0;
        hs_rr<=hs_r;
        de_r <=r_DE_0;
        de_rr<=de_r;
    end
end

//LVDS计数
assign hs_pos = r_Hsync_0   &   !hs_r;
assign hs_neg = !r_Hsync_0  &   hs_r;
assign vs_pos = r_Vsync_0   &   !vs_r;
assign vs_neg = !r_Vsync_0  &   vs_r;
assign de_pos = r_DE_0      &   !de_r;
assign de_neg = !r_DE_0     &   de_r;
reg hs_flag;
always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
        hs_flag<=0;
       end
    else if(hs_neg)begin
        hs_flag<=1;
    end
    else if(hs_pos)begin
        hs_flag<=0;
    end
end

reg de_flag;
always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
        de_flag<=0;
       end
    else if(de_pos)begin
        de_flag<=1;
    end
    else if(de_neg)begin
        de_flag<=0;
    end
end
reg de_flag;

always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
       cnt_hs<=0;
       end
    else if(hs_pos)begin
        cnt_hs<=0;
    end
    else if(hs_neg)begin
        cnt_hs<=1;
    end
    else if(hs_flag)begin
        cnt_hs <=cnt_hs + 1;
    end
end

always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
       cnt_de<=0;
       end
    else if(hs_pos)begin
        cnt_de<=1;
    end
    else if(hs_neg)begin
        cnt_de<=0;
    end
    else if(hs_flag)begin
        cnt_de <=cnt_de + 1;
    end
end

always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
       cnt_vs<=1;
    end
    else if(vs_neg||vs_pos)begin
        cnt_vs<=0;
    end
    else if(de_pos)begin
        cnt_vs <=cnt_vs + 1;
    end
end

always@(posedge rx_sclk or negedge I_rst_n)begin
    if(!I_rst_n)begin
       cnt_vs_all<=0;
    end
    else if(vs_neg||vs_pos)begin
        cnt_vs_all<=1;
    end
    else if(de_pos)begin
        cnt_vs_all <=cnt_vs_all + 1;
    end
end
//===================================================================================
//LVDS TX
LVDS_7to1_TX_Top LVDS_7to1_TX_Top_inst
(
    .I_rst_n       (I_rst_n     ),
    .I_pix_clk     (rx_sclk     ), //x1                       
    .I_vs          (r_Vsync_0   ), 
    .I_hs          (r_Hsync_0   ),
    .I_de          (r_DE_0      ),
    .I_data_r      (r_R_0       ),
    .I_data_g      (r_G_0       ),
    .I_data_b      (r_B_0       ), 
    .O_clkout_p    (O_clkout_p  ), 
    .O_clkout_n    (O_clkout_n  ),
    .O_dout_p      (O_dout_p    ),    
    .O_dout_n      (O_dout_n    ) 
);
//miniled

wire clk25M;
wire clk1M;
wire sdbpflag;
wire [9:0]wtaddr;
wire [6:0]cntlatch;
wire frame_flag;
wire latch_flag;
wire [95:0]datain;
wire [15:0]wtdina;
//PLL分频
SPI7001_25M_1M_rPLL SPI7001_25M_1M_rPLL_inst(
         .clkout(clk25M), //output clkout
         .clkoutd(clk1M), //output clkoutd
         .clkin(I_clk) //input clkin
);
//ramflag_1是模拟分区背光算法后控制灯板点亮的模块（通过信号sdbpflag、wtaddr、wtdina传入LED驱动芯片接口模块进行后续输出）
wire rx_sclk_t;

ramflag_1 u1(
    .clk(clk25M),
    .rst_n(I_rst_n),
    .O_pix_clk(rx_sclk),
    .rx_sclk_t(rx_sclk_t),
    .R(r_R_0),
    .G(r_G_0),
    .B(r_B_0),
    .r_Vsync_0(r_Vsync_0),
    .r_Hsync_0(r_Hsync_0),
    .r_DE_0(r_DE_0),
    .sdbpflag_wire(sdbpflag),//写入一帧起始信号
    .wtdina_wire(wtdina),//写入的灰度值
    .wtaddr_wire(wtaddr)//灯板上灯珠位置对应的地址

);
//以下代码不建议做修改
sram_top_gowin_top u2(
    .clka(clk25M),
    .clkb(clk1M),
    .sdbpflag(sdbpflag),
    .wtaddr(wtaddr),
    .wtdina(wtdina),
    .rst_n(I_rst_n),
    .latch_flag(latch_flag),
    .frame_flag(frame_flag),
    .datain(datain),
    .cntlatch(cntlatch)
);

SPI7001_gowin_top u3(
    .clock(clk25M),
    .clk_1M(clk1M),
    .rst_n(I_rst_n),
    .frame_f(frame_flag),
    .rgb_f(latch_flag),
    .rgb_data(datain),
    .cntlatch(cntlatch),
    .LE(LE),
    .DCLK(DCLK),
    .SDI(SDI),
    .GCLK(GCLK),
    .scan1(scan1),
    .scan2(scan2),
    .scan3(scan3),
    .scan4(scan4),
    .scan1_wire(scan1_wire)
);

Gray_rPLL Gpll_inst (
.clkout(rx_sclk_t), 
.reset_p(~I_rst_n), 
.clkin(rx_sclk)
);

endmodule