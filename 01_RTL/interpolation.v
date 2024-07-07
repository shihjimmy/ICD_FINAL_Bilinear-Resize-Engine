module interpolation (
    input              clk,
    input              RST,
    input              START,
    input      [5:0]   H0,
    input      [5:0]   V0,
    input      [3:0]   SW,
    input      [3:0]   SH,
    output             REN,
    input      [7:0]   R_DATA,
    output     [7:0]   O_DATA,
    output             O_VALID,
    output reg [11:0]  ADDR
);

    localparam IDLE = 4'd0;
    localparam READ = 4'd1;
    localparam READ_a = 4'd2;
    localparam READ_b = 4'd3;
    localparam READ_c = 4'd4;
    localparam READ_d = 4'd5;
    localparam CALC = 4'd6;
    localparam CALC_1 = 4'd7;
    localparam CALC_2 = 4'd8;
    localparam CALC_3 = 4'd9;
    localparam OUT = 4'd10;
    localparam OUT2 = 4'd11;

    reg [3:0] state_r, state_w;
    reg [5:0] tmp1, tmp2, tmp3, tmp4;
    reg [8:0] tmp5;
    

    reg [8:0] x, y, border_x, border_y;
    reg [8:0] coord_x, coord_y;
    reg same_row1, same_row2;
    reg same_col1, same_col2;
    reg [3:0] check;
    reg get_next_row;
    reg get_next_col;
    reg overflow, overflow2, overflow3;

    reg [7:0] data_a_r, data_a_w;
    reg [7:0] data_b_r, data_b_w;
    reg [7:0] data_c_r, data_c_w;
    reg [7:0] data_d_r, data_d_w;

    reg [5:0] H_r, H_w;
    reg [5:0] V_r, V_w;
    reg [3:0] SW_r, SW_w;
    reg [3:0] SH_r, SH_w;

    reg [3:0] height, wide;

    reg [4:0] count_x_r, count_x_w; 
    reg [4:0] count_y_r, count_y_w;

    reg [3:0] count_SW_r, count_SW_w;
    reg [3:0] count_SH_r, count_SH_w;

    reg [7:0] interpolation_a, interpolation_b;
    reg [7:0] bilinear_1_r, bilinear_1_w;
    reg [7:0] bilinear_2_r, bilinear_2_w;
    reg [8:0] length;
    reg [8:0] tmp6, tmp7;
    reg [16:0] tmp8, tmp9, tmp10;
    reg [20:0] tmp11, tmp12, tmp13;
    reg [7:0] result;
  
    /* OUTPUT */
    assign O_DATA = bilinear_1_r;
    assign O_VALID = (state_r == OUT || state_r == OUT2);
    assign REN =  !((state_r <= 4'd4) && (state_r >= 4'd1));

    always@ (*) begin
        tmp1 = H_r + count_SW_r;
        tmp2 = V_r + count_SH_r;
        tmp3 = tmp1 + 1'b1;
        tmp4 = tmp2 + 1'b1;
    end

    always@ (*) begin
        case(state_r)
            READ:    ADDR = {tmp2, tmp1};
            READ_a:  ADDR = {tmp2, tmp3};
            READ_b:  ADDR = {tmp4, tmp1};
            READ_c:  ADDR = {tmp4, tmp3};
            default: ADDR = 0;
        endcase
    end
    

    /* input storage */
    always@ (*) begin
        if(START) begin
            H_w = H0;
            V_w = V0;
            SW_w = SW;
            SH_w = SH;
        end
        else begin
            H_w = H_r;
            V_w = V_r;
            SW_w = SW_r;
            SH_w = SH_r;
        end
    end
    
    always@ (posedge clk or posedge RST) begin
        if(RST) begin
            H_r  <= 0;
            V_r  <= 0;
            SW_r <= 0;
            SH_r <= 0;
        end
        else begin
            H_r  <= H_w;
            V_r  <= V_w;
            SW_r <= SW_w;
            SH_r <= SH_w;
        end
    end


    /* data storage */
    always@ (*) begin
        if(state_r == READ_a) begin
            data_a_w = R_DATA;
        end
        else begin
            data_a_w = data_a_r;
        end
    end

    always@ (*) begin
        if(state_r == READ_b) begin
            data_b_w = R_DATA;
        end
        else begin
            data_b_w = data_b_r;
        end
    end

    always@ (*) begin
        if(state_r == READ_c) begin
            data_c_w = R_DATA;
        end
        else begin
            data_c_w = data_c_r;
        end
    end

    always@ (*) begin
        if(state_r == READ_d) begin
            data_d_w = R_DATA;
        end
        else begin
            data_d_w = data_d_r;
        end
    end

    always@ (posedge clk or posedge RST) begin
        if(RST) begin
            data_a_r <= 0;
            data_b_r <= 0;
            data_c_r <= 0;
            data_d_r <= 0;
        end
        else begin
            data_a_r <= data_a_w;
            data_b_r <= data_b_w;
            data_c_r <= data_c_w;
            data_d_r <= data_d_w;
        end
    end


    /* xy counter */
    always@ (*) begin
        if(state_r == OUT || state_r == OUT2) begin
            count_x_w = (count_x_r[4]) ? 5'd0 : (count_x_r + 1'b1);
            count_y_w = (count_x_r[4]) ? (count_y_r + 1'b1) : count_y_r;
        end
        else if(state_r == IDLE) begin
            count_x_w = 0;
            count_y_w = 0;
        end
        else begin 
            count_x_w = count_x_r;
            count_y_w = count_y_r;
        end
    end

    always@ (posedge clk or posedge RST) begin
        if(RST) begin
            count_x_r <= 0;
            count_y_r <= 0;
        end
        else begin
            count_x_r <= count_x_w;
            count_y_r <= count_y_w;
        end
    end


    /* coordinate transformation */
    always@ (*) begin
        x = {count_SW_r, 4'd0};
        y = {count_SH_r, 4'd0};
        wide = SW_r - 1'b1;
        height = SH_r - 1'b1;

        border_x = {(count_SW_r+1'b1), 4'd0};
        border_y = {(count_SH_r+1'b1), 4'd0};
        coord_x = count_x_r * wide;
        coord_y = count_y_r * height;
    end

    always@ (*) begin
        tmp5 = coord_x + wide;
        get_next_col = tmp5 > border_x;
        get_next_row = (coord_y + height) > border_y;
        
        overflow  = tmp5 > {wide, 4'd0};  // for the normal case
        overflow2 = (wide==0) && (count_x_r[4]); // for the nx1 case
        overflow3 = (height==0) && (count_x_r[4]);// for the 1xn case

        same_row1 = (coord_y == y); 
        same_col1 = (coord_x == x); 
        same_row2 = (coord_y == border_y);
        same_col2 = (coord_x == border_x);
        check = {same_row1, same_col1, same_row2, same_col2};
    end


    /* SW, SH counter */
    always@ (*) begin
        if(state_r == IDLE) begin
            count_SW_w = 0;
            count_SH_w = 0;
        end
        else if(state_r == OUT)begin
            count_SW_w = (overflow || overflow3) ? 0 : (get_next_col) ?  (count_SW_r + 1'b1) : count_SW_r;
            count_SH_w = ((overflow || overflow2) & get_next_row) ? (count_SH_r + 1'b1) : count_SH_r;
        end
        else begin
            count_SW_w = count_SW_r;
            count_SH_w = count_SH_r;
        end
    end

    always@ (posedge clk or posedge RST) begin
        if(RST) begin
            count_SW_r <= 0;
            count_SH_r <= 0;
        end
        else begin
            count_SW_r <= count_SW_w;
            count_SH_r <= count_SH_w;
        end
    end


    /* state transition */
    always@ (*) begin
        case(state_r)
            IDLE: state_w = (START) ? READ : IDLE;
            READ: state_w = READ_a;
            READ_a: state_w = (SW_r==1 && SH_r==1) ? OUT2 : READ_b;
            READ_b: state_w = READ_c;
            READ_c: state_w = READ_d;
            READ_d: state_w = CALC;
            
            CALC: begin
                case(check)
                    4'b1100: state_w = OUT; // same row, same col --> output (a)
                    4'b1001: state_w = OUT; // same row, same col --> output (b)
                    4'b0110: state_w = OUT; // same row, same col --> output (c)
                    4'b0011: state_w = OUT; // same row, same col --> output (d)    
                    default: state_w = CALC_1;
                endcase
            end
            CALC_1: state_w = (&(~check)) ? CALC_2 : OUT;  
            CALC_2: state_w = CALC_3;
            CALC_3: state_w = OUT;

            OUT: begin
                if(count_x_r[4] & count_y_r[4]) begin
                    state_w = IDLE;
                end
                else if(overflow2 & get_next_row) begin
                    state_w = READ;
                end
                else if(!get_next_col) begin
                    state_w = CALC;
                end
                else begin
                    state_w = READ;
                end
            end

            OUT2: begin
                if(count_x_r[4] & count_y_r[4]) begin
                    state_w = IDLE;
                end
                else begin
                    state_w = OUT2;
                end
            end

            default: state_w = IDLE;
        endcase
    end

    always@ (posedge clk or posedge RST) begin
        if(RST) begin
            state_r <= IDLE;
        end
        else begin
            state_r <= state_w;
        end
    end
    

    /* interpolation */
    always@ (*) begin
        tmp6 = (coord_x - x);
        tmp7 = (coord_y - y);
    end


    always@ (*) begin
        if(state_r == CALC_1) begin
            case(check) 
                4'b1000: begin
                    interpolation_a = data_a_r;
                    interpolation_b = data_b_r;
                    length = tmp6;
                end
                
                4'b0100:begin
                    interpolation_a = data_a_r;
                    interpolation_b = data_c_r;
                    length = tmp7;
                end
                
                4'b0010:begin
                    interpolation_a = data_c_r;
                    interpolation_b = data_d_r;
                    length = tmp6;
                end
                
                4'b0001:begin
                    interpolation_a = data_b_r;
                    interpolation_b = data_d_r;
                    length = tmp7;
                end
                
                4'b0000:begin
                    interpolation_a = data_a_r;
                    interpolation_b = data_c_r;
                    length = tmp7;
                end
                
                default:begin
                    interpolation_a = 0;
                    interpolation_b = 0;
                    length = 0;
                end
            endcase
        end
        else if(state_r == CALC_2) begin
            interpolation_a = data_b_r;
            interpolation_b = data_d_r;
            length = tmp7;
        end
        else if(state_r == CALC_3) begin
            interpolation_a = bilinear_1_r;
            interpolation_b = bilinear_2_r;
            length = tmp6;
        end
        else begin
            interpolation_a = 0;
            interpolation_b = 0;
            length = 0;
        end
    end

    always@ (*) begin
        tmp8 = interpolation_b * length;
        tmp9 = {9'b000010000} - length;
        tmp10 = interpolation_a * tmp9;
        tmp11 = {4'd0, tmp8};
        tmp12 = {4'd0, tmp10};
        tmp13 = tmp11 + tmp12;
        result = (&(~tmp13[20:12])) ? tmp13[11:4] : 8'd255;
    end

    always@ (*) begin
        if(state_r == CALC) begin
            case(check)
                4'b1100: bilinear_1_w = data_a_r; // same row, same col --> output (a)
                4'b1001: bilinear_1_w = data_b_r; // same row, same col --> output (b)
                4'b0110: bilinear_1_w = data_c_r; // same row, same col --> output (c)
                4'b0011: bilinear_1_w = data_d_r; // same row, same col --> output (d)
                default: bilinear_1_w = 0;
            endcase 
        end
        else if(state_r == CALC_1 || state_r == CALC_3) begin
            bilinear_1_w = result;
        end
        else if(state_r == OUT || state_r == IDLE) begin
            bilinear_1_w = 0;
        end
        else if(state_r == READ_a && state_w == OUT2) begin
            bilinear_1_w = data_a_w;
        end
        else begin
            bilinear_1_w = bilinear_1_r;
        end
    end

    always@ (*) begin
        if(state_r == CALC_2) begin
            bilinear_2_w = result;
        end
        else if(state_r == OUT) begin
            bilinear_2_w = 0;
        end
        else begin
            bilinear_2_w = bilinear_2_r;
        end
    end

    always@ (posedge clk or posedge RST) begin
        if(RST) begin
            bilinear_1_r <= 0;
            bilinear_2_r <= 0;
        end
        else begin
            bilinear_1_r <= bilinear_1_w;
            bilinear_2_r <= bilinear_2_w;
        end
    end

endmodule
