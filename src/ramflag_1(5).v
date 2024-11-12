  module ramflag_1(
    input clk,                       // 
    input rst_n,
    input O_pix_clk,           //像素时钟
    input rx_sclk_t,            //三倍像素时钟
    input wire [7:0] R,        // 红色通道
    input wire [7:0] G,        // 绿色通道
    input wire [7:0] B,        // 蓝色通道
    input wire  r_Vsync_0 ,
    input wire  r_Hsync_0,
    input wire   r_DE_0,
    output  sdbpflag_wire,
    output  [15:0] wtdina_wire,
    output  [9:0] wtaddr_wire

);
wire 	   rx_sclk;  				//像素时钟

reg         vsync;
reg         hsync;
reg         de;
reg [7:0] 	current_gray;           //当前像素的灰度值
reg [15:0] 	max_gray_r;             //当前处理行内每个led对应53个像素点最大灰度值
reg [11:0]	row_pixels;             //每一行像素计数
reg [10:0]	line_pixels;            //总行数计数
reg [10:0]	row_pixels_f;           //每一行有效输出像素计数
reg [9:0]	line_pixels_f;          //总有效输出行数计数
reg [5:0] 	count_edge; 			//用于横向行像素计数边缘，最大值为53
reg [5:0]	count_edge_l;			//用于纵向行数计数边缘，最大值为53
reg [11:0] 	cnt;  					//用于延迟1250个dclk 等待配置寄存器时间。
reg [30:0] 	cnt1; 					//用于周期性发送sdbpflag信号，可以设置cnt1长度修改发送sdbpflag信号时间间隔
reg 		flag= 'd0; 				//标志配置寄存器结束，可以发送sdbp数据了;
reg 		sdbpflag;
wire [15:0]	wtdina;
reg [15:0]	wtdina_fifo; 			//储存进fifo的最大灰度
reg [9:0]	wtaddr;
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

assign rx_sclk = O_pix_clk;
assign sdbpflag_wire = sdbpflag;
assign wtdina_wire = wtdina;
assign wtaddr_wire = wtaddr;

always@(posedge rx_sclk or negedge rst_n)begin //行列场控制信号处理
        if(!rst_n)begin
            vsync <= 1;
            hsync <= 1;
            de <= 0;
        end else begin
            vsync <= r_Vsync_0;
            hsync <= r_Hsync_0;
            de <= r_DE_0;
        end
end

//cnt记满后视为配置寄存器完毕
always @(posedge clk or negedge rst_n)   //0.1ms
 begin
    if(!rst_n)
        begin
            flag <= 0;
            cnt <= 0;
        end
    else if(cnt < CNT_COUNT)
    begin
        flag <= 0;
        cnt <= cnt + 1;
    end
    else if(cnt == CNT_COUNT)
    begin
        flag <= 1;
    end
end
//cnt1用来计数sdbpflag的周期
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        cnt1 <= 0;
    else if(cnt1 >= 420_000)begin //一帧的时间16.8ms
        cnt1 <= 0;
    end
    else
        cnt1 <= cnt1 + 1;
end

//以下always块作用为控制输出信号
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        sdbpflag <= 0;
    else if(cnt1 == 1 && flag)begin
        sdbpflag <= 1;
    end
    else if(cnt1 == 30 && flag)begin
        sdbpflag <= 0;  
    end
end


//控制算法
always@(posedge rx_sclk or negedge rst_n)begin //控制整个屏幕的行计数和行数计数
	if(!rst_n)begin
		row_pixels <=0;
		line_pixels <=0;
	end else if (row_pixels >= 1377)begin //IMAGE_WIDTH_H - HPW - 1
		row_pixels <= 0;
		line_pixels <= line_pixels + 1;
	end else if (line_pixels >= 821)begin //IMAGE_HEIGHT_H - VPW -1
		line_pixels <= 0;
	end else begin
		row_pixels <= row_pixels + 1;
	end
end

reg [7:0] cnt_test1,cnt_test2;    
always@(posedge rx_sclk or negedge rst_n) begin
    if (!rst_n) begin
		row_pixels_f <= 0;
		count_edge_l <= 0;
		RdEn_r <= 0;
		WrEn <= 0;
		valid_g <= 0;
		line_pixels_f <= 0;
		count_edge <= 0;
        max_gray_r <= 0;
		cnt_test1 <= 0;
		cnt_test2 <= 0;
	end else if ((hsync == 0) && (vsync == 0) && (de == 1))begin
		cnt_test1 <= cnt_test1 + 1;
		if((row_pixels >= 46) && (row_pixels <= 1368) && (line_pixels >=20) && (line_pixels <= 820 )) begin//
		cnt_test2 <= cnt_test2 + 1;
			if(row_pixels_f >= IMAGE_WIDTH)begin //当整行有效像素到1280时，行像素计数归零
				row_pixels_f <= 0;
				if(count_edge_l >= BLOCK_SIZE)begin
					count_edge_l <= 0;
					if(Empty_r == 1)begin //当预处理fifo中为空时，停止预处理fifo_row的输出以及输出fifo_gray的写入
					RdEn_r <= 0;
					WrEn <= 0;
					valid_g <= 0;
					end else begin //将预处理fifo_row中的灰度值写进输出fifo_gray
					RdEn_r <= 1;
					WrEn <= 1;
					valid_g <= 1;
                    end
				end else begin
					count_edge_l <= count_edge_l + 1;//行计数加1
				end
				line_pixels_f <= line_pixels_f + 1;//总有效行计数+1
			end else if(count_edge_l >= BLOCK_SIZE)begin //每处理一行灯珠对应的53行像素，将预处理fifo_row中的整行灯珠的最大灰度值存进输出fifo_gray中
				count_edge_l <= 0;
				if(Empty_r == 1)begin //当预处理fifo中为空时，停止预处理fifo_row的输出以及输出fifo_gray的写入
					RdEn_r <= 0;
					WrEn <= 0;
					valid_g <= 0;
				end else begin //将预处理fifo_row中的灰度值写进输出fifo_gray
					RdEn_r <= 1;
					WrEn <= 1;
					valid_g <= 1;
				end	
			end else if(line_pixels_f >= IMAGE_HEIGHT)begin //当所有有效行计数到800时，行数计数归零		
				line_pixels_f <= 0;//
			end else if(count_edge >= BLOCK_SIZE) begin //行内每个53*1像素条计数满53时归零
				count_edge <= 0;
				valid_r <= 0;
			end else if(count_edge == BLOCK_SIZE -1)begin //比较当前53*1像素条最大灰度值与从寄存器中取出的上一行53*1最大灰度值作对比
				//控制186-195行的always，控制是否传灰度进fifo_row
				if(max_gray_r >= max_gray_t)begin
					gray_r <= max_gray_r;
					valid_r <= 1;
				end else if(max_gray_r <= max_gray_t)begin
					gray_r <= max_gray_t;
					valid_r <= 1;
				end else begin
					gray_r <= gray_r;
					valid_r <= 1;
				end
				count_edge <= count_edge + 1;
			end else begin
				current_gray <= (R << 2) + (R << 8) + (G << 2) + (G << 6) + (B << 2) + (B << 4); // 使用位移替代乘法
				count_edge <= count_edge + 1;
				if (current_gray > max_gray_r) begin // 更新当前块的最大灰度值
					max_gray_r <= current_gray;
				end
				row_pixels_f <= row_pixels_f + 1;			

			end
		end
	end
end
//储存fifo_row输出的灰度值，用于与下一行对应的53*1像素的灰度值做比较
reg [15:0] max_gray_t;
reg valid_r;

always@(posedge rx_sclk or negedge rst_n) 
begin
    if(!rst_n)begin
        max_gray_t <= 0;
    end
    else if(valid_r)begin
        max_gray_t <= max_gray_r_fifo_out ; 

	end
end


//将fifo_row中的灰度值转移至fifo_gray中
reg valid_g;
always@(posedge rx_sclk or negedge rst_n) 
begin
    if(!rst_n)begin
        wtdina_fifo <= 0;
    end
    else if(valid_g) begin
        wtdina_fifo <= max_gray_r_fifo_out ; 
	end
end

//控制fifo_gray输出灰度信号
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		fifo_gray_valid <= 0;
		RdEn <= 0;
		wtaddr <= 0;
	end else if(line_pixels_f >= IMAGE_HEIGHT)begin //当所有有效行计数到800时，行数计数归零
		fifo_gray_valid <= 1; //当有效行处理完毕，置fifo_gray输出有效

	end else if(fifo_gray_valid == 1 && wtaddr <= 360)begin
		RdEn <= 1;
		wtaddr <= wtaddr + 1;
	end else begin
		fifo_gray_valid <= 0;
		RdEn <= 0;
		wtaddr <= 0;
	end
end
	
reg fifo_gray_valid;//控制fifo_gray的RdEn有效
reg WrEn;
reg RdEn;
wire Full;
wire Empty;
//总输出fifo，储存所有灰度值
	FIFO_HS_Top fifo_gray(
		.Data(wtdina_fifo), //input [15:0] Data
		.WrClk(rx_sclk), //input WrClk
		.RdClk(clk), //input RdClk
		.WrEn(WrEn), //input WrEn
		.RdEn(RdEn), //input RdEn
		.Q(wtdina), //output [15:0] Q
		.Empty(Empty), //output Empty
		.Full(Full) //output Full
	);
reg [15:0] gray_r;
reg WrEn_r;
reg RdEn_r;
wire Full_r;
wire Empty_r;
wire [15:0] max_gray_r_fifo_out;

//预处理fifo，储存每行像素的灰度值
	FIFO_HS_Top fifo_row(
		.Data(gray_r), //input [15:0] Data
		.WrClk(rx_sclk), //input WrClk
		.RdClk(rx_sclk), //input RdClk
		.WrEn(valid_r), //input WrEn
		.RdEn(RdEn_r), //input RdEn
		.Q(max_gray_r_fifo_out), //output [15:0] Q
		.Empty(Empty_r), //output Empty
		.Full(Full_r) //output Full
	);
	
    


endmodule