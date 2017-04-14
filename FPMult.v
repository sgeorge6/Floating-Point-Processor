module FPMult(clk,FP1,FP2,FP3);

input reg [31:0] FP1; //first input
input reg [31:0] FP2; //second input
input clk;

output reg [31:0] FP3; //output

reg [2:0] state, next_state;
reg [11:0] tempX; //for multiplying 
reg [9:0] tempY; //for multiplying

reg [9:0] temp_E3a;
reg [10:0] temp_E3b;
reg [22:0] temp_p;
reg tempc;
reg [23:0] temp_M3b; //2's complement of M3
reg [23:0] temp_M3a; //sum of M1+M2
reg [24:0] temp_M3c; //25bit version of M3
reg [22:0] temp_M3d;

//MANTISSA
wire [22:0] M1; 
wire [22:0] M2;
wire [22:0] M3;
//EXPONENT
wire [7:0] E1;
wire [7:0] E2;
wire [7:0] E3;
//SIGN
wire S1; 
wire S2;
wire S3;

wire [8:0] E1_Sign;
wire [8:0] E2_Sign;

assign M1 = FP1[22:0];
assign M2 = FP2[22:0];
assign M3 = FP3[22:0];
assign E1 = FP1[30:23];
assign E2 = FP2[30:23];
assign E3 = FP3[30:23];
assign S1 = FP1[31];
assign S2 = FP2[31];
assign S3 = FP3[31];
assign E1_Sign <= {1'b0,E1[7:0]};
assign E2_Sign <= {1'b0,E2[7:0]};

always@(posedge CLK) begin
    if(reset) state <= 3'b000;
    else state <= next_state;
end

always @(state)
begin

   case(state)
        //Calculate Sign Bit
            //S3 = S2 ^ S1
        4'b0000:
            begin
            S3[31] <= S2[31] ^ S1[31];
            next_state <= 4'b0001;
            end
        //Calculate Exponent
        4'b001:
            begin
            temp_E3a <= E1_Sign + E2_Sign; //Two's complement addition of E1 and E2 9bit
            //temp_E2 = temporary E2
            temp_E3b <= temp_E3a + 9'b0_1000_0001; //Adding 2's complement of -127
            next_state <= 3'b0010;
            end
        //Calculate Mantissa
        4'b0010:
            begin
                //M3 = M1 + M2 + M1M2
                {tempc,temp_p} <= M1[11:0]+ M2[11:0];
                temp_p[22:12] <= M1[22:12] ;
                next_state <= 3'b0011;
            end
        4'b0011:
            begin
                temp_M3a <= temp_p[22:12]+ tempc + M2[22:12]; //M1 + M2 = temp_M3a
                next_state <= 4'b0100;
            end
        4'b0100: begin
                tempY <= M2[22:18] * M1[22:18]; // 2^10 * xs
                next_state <= 4'b0101;
            end
        4'b0101: begin
                tempX <= M2[17:12] * M2[17:12]; // 2^12
                next_state <= 4'b0110
            end
        4'b0110:begin
                {tempY,tempX} <= {tempY, tempX} + ((M2[22:18] * M1[17:12]) << 6);
                next_state <= 4'b0111;
            end
        4'b0111:begin
                temp_M3b <= {tempY, tempX} + ((M2[17:12] * M1[22:18])<< 6);
                next_state <= 4'b0111;
                end
        4'b0111: begin
                temp_M3c <= temp_M3a[22:0] + temp_M3b[22:0]; 
                if (temp_M3c[24:23]==2'b00)
                    begin
                        temp_E3b <= temp_E3b;
                        temp_M3d <= temp_M3c[22:0];
                    end
                else if (temp_M3c[24:23]==2'b01)
                    begin
                        temp_E3b <= temp_E3b + 11'b000_0000_0001;
                        temp_M3d <= {1'b0,(temp_M3c[24:23] + 1) >> 1};
                    end
                else if (temp_M3c[24:23]==2'b10)
                    begin
                        temp_E3b <= temp_E3b + 11'b000_0000_0010;
                        temp_M3d <= {2'b00,(temp_M3c[24:23] + 1) >> 2};
                    end
                next_state <= 4'b1000;
            end
        4'b1000: begin
                M3 <= temp_M3d;
                E3 <= ~[temp_E3b[7:0]] + 8'b0000_0001 + 8'b0111_1111;
                next_state <= 4'1001;
            end
        4'b1001: begin
                FP3 <= {S3,E3,M3};
                state <= 4'b0000;
            end
        default: state <= 3'b000;
    endcase 
 end
endmodule 