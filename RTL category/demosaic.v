module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

// Register
reg [1:0] bilinearCase;
reg [2:0] state, nextState;
reg [3:0] counter9;
reg [6:0] caseCounter, round;
reg [7:0] data [8:0]; 
reg [7:0] red, blue, green;
reg [14:0] counter, biCounter; // bicounter store the center address

// State parameter
localparam READDATA = 0; // Read data, then wirte to wdata
localparam COLOR = 1; // Choose the case of color
localparam STORE9 = 2; // Store 9 element to register data
localparam BILINEAR = 3; // Bilinear Interpolation
localparam WRITEDATA = 4; // Write data to memory
localparam FINISH = 5; // Done

// State control
always @(posedge clk or posedge reset) begin
	if(reset) 
		state <= READDATA;
	else 
		state <= nextState;
end

//next state logic
always @(*) begin
	case (state)
		READDATA: nextState = (counter == 15'd16384)? COLOR : READDATA; 
		COLOR: nextState = STORE9;
		STORE9: nextState = (counter9 == 4'd9)? BILINEAR : STORE9; 
		BILINEAR: nextState = WRITEDATA;
		WRITEDATA: nextState = (biCounter == 15'd16257)? FINISH : COLOR; 
		FINISH: nextState = FINISH;
		default: nextState = READDATA;
	endcase
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		done <= 1'd0;
		wr_r <= 1'd0;
		wr_g <= 1'd0;
		wr_b <= 1'd0;
		bilinearCase <= 2'd0;
		counter9 <= 4'd0;
		caseCounter <= 7'd0;
		round <= 7'd0;
		red <= 9'd0;
		blue <= 9'd0;
		green <= 9'd0;
		addr_r <= 14'd0;
		addr_g <= 14'd0;
		addr_b <= 14'd0;
		biCounter <= 15'd129;
		counter <= 15'd0;
	end
	else begin
		case (state)
			READDATA: begin
				if(in_en) begin
					wr_r <= 1'd1;
					wr_g <= 1'd1;
					wr_b <= 1'd1;
					addr_r <= counter;
					addr_g <= counter;
					addr_b <= counter;
					wdata_r <= data_in;
					wdata_g <= data_in;
					wdata_b <= data_in;
					counter <= counter + 1;
				end
			end

			COLOR: begin
				wr_r <= 1'd0;
				wr_g <= 1'd0;
				wr_b <= 1'd0;
				
				if(!(round & 1)) begin // Even round, 0,2,4,6,8,...
					if(!(caseCounter & 1)) // Even case, 0,2,4,6,8,...
						bilinearCase <= 2'd0;
					else // Odd case, 1,3,5,7,9,...
						bilinearCase <= 2'd1;
				end
				else begin // Odd round, 1,3,5,7,9,...
					if(!(caseCounter & 1)) // Even case, 0,2,4,6,8,...
						bilinearCase <= 2'd2;
					else // Odd case, 1,3,5,7,9,...
						bilinearCase <= 2'd3;
				end
				caseCounter <= caseCounter + 7'd1;
			end

			STORE9: begin
				wr_r <= 1'd0;
				wr_g <= 1'd0;
				wr_b <= 1'd0;	

				/*  
				 *  I use R,G,B memory to store pattern data. when in case 0(the middle color is green), I will update the missing blue and red data to memory.
				 *  In next turn is case 1(the middle color is blue). It will use previous data, but the blue and red data are changed in previous turn. So the
				 *  previous green data is the origin data.
				 */
				if(counter9 > 4'd0) begin
					case (bilinearCase)
						0: begin
							case (counter9)
								2: data[counter9 - 1] <= rdata_r;
								4: data[counter9 - 1] <= rdata_b;
								default: data[counter9 - 1] <= rdata_g;
							endcase
						end
						1: begin
							case (counter9)
								1,3: data[counter9 - 1] <= rdata_r;
								2,4: data[counter9 - 1] <= rdata_g;
								default: data[counter9 - 1] <= rdata_b;
							endcase
						end
						2: begin
							case (counter9)
								1,3: data[counter9 - 1] <= rdata_b;
								2,4: data[counter9 - 1] <= rdata_g;
								default: data[counter9 - 1] <= rdata_r;
							endcase
						end
						3: begin
							case (counter9)
								2: data[counter9 - 1] <= rdata_b;
								4: data[counter9 - 1] <= rdata_r;
								default: data[counter9 - 1] <= rdata_g;
							endcase
						end
					endcase
				end
				counter9 <= counter9 + 4'd1;
  
				case (counter9) // For y axis (row)
					0,1,2: begin
						addr_g[13:7] <= biCounter[13:7] - 7'd1;		
						addr_r[13:7] <= biCounter[13:7] - 7'd1;	
						addr_b[13:7] <= biCounter[13:7] - 7'd1;	
					end				
					3,4,5: begin
						addr_g[13:7] <= biCounter[13:7];		
						addr_r[13:7] <= biCounter[13:7];	
						addr_b[13:7] <= biCounter[13:7];	
					end				                                    
					6,7,8: begin
						addr_g[13:7] <= biCounter[13:7] + 7'd1;		
						addr_r[13:7] <= biCounter[13:7] + 7'd1;	
						addr_b[13:7] <= biCounter[13:7] + 7'd1;	
					end				
				endcase

				case (counter9) // For x axis (col)
					0,3,6: begin
						addr_g[6:0] <= biCounter[6:0] - 7'd1;	
						addr_r[6:0] <= biCounter[6:0] - 7'd1;	
						addr_b[6:0] <= biCounter[6:0] - 7'd1;	
					end					
					1,4,7: begin
						addr_g[6:0] <= biCounter[6:0];	
						addr_r[6:0] <= biCounter[6:0];	
						addr_b[6:0] <= biCounter[6:0];	
					end											                                    
					2,5,8: begin
						addr_g[6:0] <= biCounter[6:0] + 7'd1;	
						addr_r[6:0] <= biCounter[6:0] + 7'd1;	
						addr_b[6:0] <= biCounter[6:0] + 7'd1;	
					end					
				endcase
			end

			BILINEAR: begin
				//  data       case 0      case 1      case 2      case 3
				//  0 1 2      G R G       R G R       B G B       G B G
				//  3 4 5      B G B       G B G       G R G       R G R
				//  6 7 8 	   G R G       R G R       B G B       G B G
				case (bilinearCase)
					0: begin // Missing B, R on G
						red <= (data[1] + data[7]) / 2;
						blue <= (data[3] + data[5]) / 2;
						green <= data[4];
					end

					1: begin // Missing G, R on B
						green <= (data[1] + data[3] + data[5] + data[7]) / 4;
						red <= (data[0] + data[2] + data[6] + data[8]) / 4;
						blue <= data[4];
					end

					2: begin // Missing G, B on R
						green <= (data[1] + data[3] + data[5] + data[7]) / 4;
						blue <= (data[0] + data[2] + data[6] + data[8]) / 4;
						red <= data[4];
					end

					3: begin // Missing B, R on G
						blue <= (data[1] + data[7]) / 2;
						red <= (data[3] + data[5]) / 2;
						green <= data[4];
					end
				endcase
			end

			WRITEDATA: begin
				wr_r <= 1'd1;
				wr_g <= 1'd1;
				wr_b <= 1'd1;
				addr_r <= biCounter;
				addr_g <= biCounter;
				addr_b <= biCounter;
				wdata_r <= red;
				wdata_g <= green;
				wdata_b <= blue;
				if(caseCounter == 7'd126) begin // Finish one row, then initialize the caseCounter
					caseCounter <= 7'd0;
					round <= round + 7'd1;
					biCounter <= biCounter + 15'd3; // Skip the edge
				end
				else 
					biCounter <= biCounter + 15'd1;
			end	

			FINISH: begin
				done <= 1'd1;
			end
		endcase
	end
end
endmodule