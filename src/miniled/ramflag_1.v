module ramflag_1(
    input clk,                       // 主时钟
    input rst_n,
    input O_pix_clk,           //像素时钟
    input rx_sclk_t,            //三倍像素时钟
    input wire [7:0] R,        // 红色通道
    input wire [7:0] G,        // 绿色通道
    input wire [7:0] B,        // 蓝色通道
    input wire  r_Vsync_0,
    input wire  r_Hsync_0,
    input wire   r_DE_0,
    output  sdbpflag_wire,
    output  [15:0] wtdina_wire,
    output  [9:0] wtaddr_wire
);


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


wire rx_sclk;   //像素时钟
reg vsync;
reg hsync;
reg de;
reg [7:0] current_gray;           //当前像素的灰度值
reg [15:0] max_gray_row;           //当前处理行内每个led对应53个像素点最大灰度值（优化命名）
reg [11:0] row_pixels;             //每一行像素计数
reg [10:0] line_pixels;            //总行数计数
reg [10:0] row_pixels_f;           //每一行有效输出像素计数
reg [9:0] line_pixels_f;          //总有效输出行数计数
reg [5:0] count_edge;             //用于横向行像素计数边缘，最大值为53
reg [5:0] count_edge_l;            //用于纵向行数计数边缘，最大值为53
reg [11:0] cnt;                    //用于延迟1250个dclk等待配置寄存器时间。
reg [30:0] cnt1;                   //用于周期性发送sdbpflag信号，可以设置cnt1长度修改发送sdbpflag信号时间间隔
reg flag = 1'b0;                   //标志配置寄存器结束，可以发送sdbp数据了;
reg sdbpflag;
wire [15:0] wtdina;
reg [15:0] wtdina_fifo;            //储存进fifo的最大灰度
reg [9:0] wtaddr;

// 定义状态机状态
localparam IDLE = 2'b00;
localparam CALCULATE = 2'b01;
localparam ADJUST = 2'b10;

reg [1:0] current_state, next_state;


// 状态机逻辑
always @(posedge clk or posedge rst_n) begin
    if (rst_n == 1'b0) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
        case (current_state)
            IDLE: begin
                if (pixel_data_in_valid) begin
                    // 初始化相关变量
                    row_pixels <= 0;
                    line_pixels <= 0;
                    count_edge <= 0;
                    count_edge_l <= 0;
                    max_gray_row <= 0;
                    next_state <= CALCULATE;
                end else begin
                    next_state <= IDLE;
                end
            end
            CALCULATE: begin
                if (hsync == 1'b0 && vsync == 1'b0 && de == 1'b1) begin
                    if (row_pixels >= 46 && row_pixels <= 1368 && line_pixels >= 20 && line_pixels <= 820) begin
                        if (row_pixels_f >= IMAGE_WIDTH) begin
                            row_pixels_f <= 0;
                            if (count_edge_l >= BLOCK_SIZE) begin
                                count_edge_l <= 0;
                                if (Empty_r == 1'b1) begin
                                    // 当预处理fifo中为空时，停止预处理fifo_row的输出以及输出fifo_gray的写入
                                    RdEn_r <= 1'b0;
                                    WrEn <= 1'b0;
                                    valid_g <= 1'b0;
                                end else begin
                                    // 将预处理fifo_row中的灰度值写进输出fifo_gray
                                    RdEn_r <= 1'b1;
                                    WrEn <= 1'b1;
                                    valid_g <= 1'b1;
                                end
                            end else begin
                                count_edge_l <= count_edge_l + 1;
                            end
                            line_pixels_f <= line_pixels_f + 1;
                        end else if (count_edge_l >= BLOCK_SIZE) begin
                            count_edge_l <= 0;
                            if (Empty_r == 1'b1) begin
                                RdEn_r <= 1'b0;
                                WrEn <= 1'b0;
                                valid_g <= 1'b0;
                            end else begin
                                RdEn_r <= 1'b1;
                                WrEn <= 1'b1;
                                valid_g <= 1'b1;
                            end
                        end else if (line_pixels_f >= IMAGE_HEIGHT) begin
                            line_pixels_f <= 0;
                        end else if (count_edge >= BLOCK_SIZE) begin
                            count_edge <= 0;
                        end else if (count_edge == BLOCK_SIZE - 1) begin
                            if (max_gray_row >= max_gray_prev_row) begin
                                gray_r <= max_gray_row;
                                valid_r <= 1'b1;
                            end else if (max_gray_row <= max_gray_prev_row) begin
                                gray_r <= max_gray_prev_row;
                                valid_r <= 1'b1;
                            end else begin
                                gray_r <= gray_r;
                                valid_r <= 1'b1;
                            end
                        end else begin
                            current_gray <= (R << 2) + (R << 8) + (G << 2) + (G << 6) + (B << 2) + (B << 4);
                            count_edge <= count_edge + 1;
                            if (current_gray > max_gray_row) begin
                                max_gray_row <= current_gray;
                            end
                            row_pixels_f <= row_pixels_f + 1;
                        end
                    end
                end
                // 当满足一定条件时切换到ADJUST状态
                if (line_pixels_f >= IMAGE_HEIGHT && count_edge_l >= BLOCK_SIZE) begin
                    next_state <= ADJUST;
                end else begin
                    next_state <= CALCULATE;
                end
            end
            ADJUST: begin
                // 根据平均亮度计算 local dimming factor
                if (avg_brightness < 8'h40) begin
                    local_dimming_factor <= 8'h60;
                end else if (avg_brightness < 8'h80) begin
                    local_dimming_factor <= 8'h80;
                end else begin
                    local_dimming_factor <= 8'hA0;
                end
                adjusted_pixel_data <= temp_pixel_data * local_dimming_factor / 255;
                next_state <= IDLE;
            end
            default: begin
                // 处理无效状态，回到IDLE状态
                next_state <= IDLE;
            end
        endcase
    end
end

// 同步复位处理
always @(posedge clk) begin
    if (rst_n == 1'b0) begin
        flag <= 1'b0;
        cnt <= 0;
        cnt1 <= 0;
        sdbpflag <= 1'b0;
        // 其他需要复位的信号
    end else begin
        // 正常逻辑操作
    end
end

//cnt记满后视为配置寄存器完毕
always @(posedge clk) begin
    if (cnt < CNT_COUNT) begin
        flag <= 1'b0;
        cnt <= cnt + 1;
    end else if (cnt == CNT_COUNT) begin
        flag <= 1'b1;
    end
end

//cnt1用来计数sdbpflag的周期
always @(posedge clk) begin
    if (cnt1 >= 420_000) begin
        cnt1 <= 0;
    end else begin
        cnt1 <= cnt1 + 1;
    end
end

// 以下always块作用为控制输出信号
always @(posedge clk) begin
    if (cnt1 == 1 && flag) begin
        sdbpflag <= 1'b1;
    end else if (cnt1 == 30 && flag) begin
        sdbpflag <= 1'b0;
    end
end

// 控制算法
always @(posedge rx_sclk) begin
    if (rst_n == 1'b0) begin
        vsync <= 1'b1;
        hsync <= 1'b1;
        de <= 1'b0;
    end else begin
        vsync <= r_Vsync_0;
        hsync <= r_Hsync_0;
        de <= r_DE_0;
    end
end

// 跨时钟域同步信号（从rx_sclk到clk）
reg [15:0] max_gray_prev_row_sync;
always @(posedge clk) begin
    max_gray_prev_row_sync <= max_gray_prev_row;
end
reg [7:0] temp_pixel_data_sync;
always @(posedge clk) begin
    temp_pixel_data_sync <= temp_pixel_data;
end

// 计算灰度值和相关控制逻辑
always @(posedge rx_sclk) begin
    if (rst_n == 1'b0) begin
        row_pixels <= 0;
        line_pixels <= 0;
    end else if (row_pixels >= 1377) begin
        row_pixels <= 0;
        line_pixels <= line_pixels + 1;
    end else if (line_pixels >= 821) begin
        line_pixels <= 0;
    end else begin
        row_pixels <= row_pixels + 1;
    end
end

// 将fifo_row中的灰度值转移至fifo_gray中
reg valid_g;
always @(posedge rx_sclk) begin
    if (rst_n == 1'b0) begin
        wtdina_fifo <= 0;
    end else if (valid_g) begin
        wtdina_fifo <= max_gray_row_fifo_out;
    end
end

// 控制fifo_gray输出灰度信号
always @(posedge clk) begin
    if (rst_n == 1'b0) begin
        fifo_gray_valid <= 1'b0;
        RdEn <= 1'b0;
        wtaddr <= 0;
    end else if (line_pixels_f >= IMAGE_HEIGHT) begin
        fifo_gray_valid <= 1'b1;
    end else if (fifo_gray_valid == 1'b1 && wtaddr <= 360) begin
        RdEn <= 1'b1;
        wtaddr <= wtaddr + 1;
    end else begin
        fifo_gray_valid <= 1'b0;
        RdEn <= 1'b0;
        wtaddr <= 0;
    end
end

reg fifo_gray_valid;
reg WrEn;
reg RdEn;
wire Full;
wire Empty;

// 总输出fifo，储存所有灰度值
FIFO_HS_Top fifo_gray(
  .Data(wtdina_fifo),
  .WrClk(rx_sclk),
  .RdClk(clk),
  .WrEn(WrEn),
  .RdEn(RdEn),
  .Q(wtdina),
  .Empty(Empty),
  .Full(Full)
);

reg gray_r;
reg WrEn_r;
reg RdEn_r;
wire Full_r;
wire Empty_r;
wire [15:0] max_gray_row_fifo_out;

// 预处理fifo，储存每行像素的灰度值
FIFO_HS_Top fifo_row(
  .Data(gray_r),
  .WrClk(rx_sclk),
  .RdClk(rx_sclk),
  .WrEn(WrEn_r),
  .RdEn(RdEn_r),
  .Q(max_gray_row_fifo_out),
  .Empty(Empty_r),
  .Full(Full_r)
);

// 储存fifo_row输出的灰度值，用于与下一行对应的53*1像素的灰度值做比较
reg [15:0] max_gray_prev_row;
reg valid_r;
always @(posedge rx_sclk) begin
    if (rst_n == 1'b0) begin
        max_gray_prev_row <= 0;
    end else if (valid_r) begin
        max_gray_prev_row <= max_gray_row_fifo_out;
    end
end

assign rx_sclk = O_pix_clk;
assign sdbpflag_wire = sdbpflag;
assign wtdina_wire = wtdina;
assign wtaddr_wire = wtaddr;

endmodule