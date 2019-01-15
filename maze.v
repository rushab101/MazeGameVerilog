// ---------------------------------------------------------------------------
// ============================ Main Module ==================================
// ---------------------------------------------------------------------------

module maze(
		SW,
		KEY,
		LEDR,
		HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
		CLOCK_50,
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,
		PS2_CLK, 
		PS2_DAT);   						//	VGA Blue[9:0]);

	input [3:0] KEY;
	input [9:0] SW;
	output [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;
	output [9:0] LEDR;
	input CLOCK_50;
	inout PS2_CLK;
	inout PS2_DAT;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

	wire reset;
	assign reset = SW[9]|Space;

	// Creates the playere the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colourg;
	wire [7:0] xg;
	wire [7:0] yg;
	wire plot;
	reg [2:0] colour;
	// Creates an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(~reset),
			.clock(CLOCK_50),
			.colour(colourg),
			.x(xg),
			.y(yg[6:0]),
			.plot(plot),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.MONOCHROME = "FALSE";
	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	defparam VGA.BACKGROUND_IMAGE = "back.mif";

	wire slow_clock;
	wire [3:0]A;
	wire Space;//resetn.

	Keyboard mykey(CLOCK_50, PS2_CLK, PS2_DAT, A[3:0], Space);
RateDivider divider(
		.interval(27'd300),
		.reset(reset),
		.en(1'b1),
		.clock_50(CLOCK_50),
		.reduced_clock(slow_clock),
		);
	
	reg [3:0] score_counter_ones, score_counter_tens;
	wire score;
	
	always@(posedge score)begin
		if(reset)begin
			score_counter_ones <= 4'b0;
			score_counter_tens <= 4'b0;
		end
		else if(score)
			if(score_counter_ones < 4'd9)
				score_counter_ones <= score_counter_ones + 1'b1;
			else begin
				score_counter_ones <= 4'b0;
				if(score_counter_tens < 4'd9)
					score_counter_tens <= score_counter_tens + 1'b1;
			end
	end
	
	
	HexDisplay hex0(
		.hex_digit(score_counter_ones[3:0]),
		.segments(HEX0)
		);
	HexDisplay hex1(
		.hex_digit(score_counter_tens[3:0]),
		.segments(HEX1)
		);
		reg en;
		reg stop;
		wire stopg;
		reg [28:0] Ni;
		 reg [28:0] No;
		 reg [7:0] Q;
		initial begin
		Ni=29'b0111111111111111111111111111;
		No=29'b0;
		Q=8'd9;
		en=1;
		stop=0;
		end
		
	
 always @ (posedge CLOCK_50)
 begin
	if(No==Ni)
	begin
	No<=0;
	en<=1;
	end
	else
	en<=0;
	No<=No+1;

 end	

	always @ (posedge reset, posedge CLOCK_50)
	begin
	if(reset)
	Q<=8'd9;
	else if (en&&!stop)//try adding !stopg
	Q<=Q-1;
	else if(!Q)
	stop<=1;
	end 
		HexDisplay hex2(
		.hex_digit(Q[3:0]),
		.segments(HEX2)
		);
	HexDisplay hex3(
		.hex_digit(Q[7:4]),
		.segments(HEX3)
		);
	HexDisplay hex4(
		.hex_digit(life),
		.segments(HEX4)
		);		

	wire timer;
	wire [3:0] life;
	SubMainModule sub_module(
		.move_up(A[2]),
		.move_down(A[1]),
		.move_left(A[0]),
		.move_right(A[3]),
		.clock_50(CLOCK_50),
		.slow_clock(slow_clock),
		.reset(reset),
		.timer(Q),
		.vga_colour(colourg),
		.vga_x(xg),
		.vga_y(yg),
		.vga_plot(plot),
		.lifeCount(life),
		.score(score),
		.stop(stopg),
		.debug_leds(LEDR));

endmodule

// ---------------------------------------------------------------------------
// ============================ Sub-Main Module ==============================
// ---------------------------------------------------------------------------

module SubMainModule(
	input move_up,
	input move_down,
	input move_left,
	input move_right,
	input clock_50,
	input slow_clock,
	input reset,
	input [7:0] timer,
	output [2:0] vga_colour,
	output [7:0] vga_x,
	output [7:0] vga_y,
	output vga_plot,
	output reg [3:0] lifeCount,
	output reg score,
	output reg stop,
	output [9:0] debug_leds);

	// The states in FSM
	localparam
				maze_TRY_player = 6'd0,
				maze_player_WAIT = 6'd1,
				maze_player = 6'd2,
				maze_GET_TARGET		= 6'd3,
				maze_GET_MAP_SPRITE 	= 6'd4,
				maze_WAIT				= 6'd5,
				maze_SET_POS			= 6'd6,

				MONSTER1_GET_TARGET		= 6'd7,
				MONSTER1_GET_MAP_SPRITE	= 6'd8,
				MONSTER1_WAIT				= 6'd9,
				MONSTER1_SET_POS			= 6'd10,

				MONSTER2_GET_TARGET		= 6'd11,
				MONSTER2_GET_MAP_SPRITE	= 6'd12,
				MONSTER2_WAIT				= 6'd13,
				MONSTER2_SET_POS			= 6'd14,

				MONSTER3_GET_TARGET		= 6'd15,
				MONSTER3_GET_MAP_SPRITE	= 6'd16,
				MONSTER3_WAIT				= 6'd17,
				MONSTER3_SET_POS			= 6'd18,

				MONSTER4_GET_TARGET		= 6'd19,
				MONSTER4_GET_MAP_SPRITE	= 6'd20,
				MONSTER4_WAIT				= 6'd21,
				MONSTER4_SET_POS			= 6'd22,
				
				MONSTER5_GET_TARGET		= 6'd23,
				MONSTER5_GET_MAP_SPRITE	= 6'd24,
				MONSTER5_WAIT				= 6'd25,
				MONSTER5_SET_POS			= 6'd26,
				
				MONSTER6_GET_TARGET		= 6'd27,
				MONSTER6_GET_MAP_SPRITE	= 6'd28,
				MONSTER6_WAIT				= 6'd29,
				MONSTER6_SET_POS			= 6'd30,

				MONSTER7_GET_TARGET		= 6'd31,
				MONSTER7_GET_MAP_SPRITE	= 6'd32,
				MONSTER7_WAIT				= 6'd33,
				MONSTER7_SET_POS			= 6'd34,				
				
				START_DISPLAY			= 6'd35,
				VIEW_DISPLAY			= 6'd36,
				STOP_DISPLAY			= 6'd37,
				
				END_GAME					= 6'd38,
				PRE=6'd39;
	
	// The coordinates of each character (it is 9 bit so that it can do signed operations)
	reg [8:0] maze_vga_x, MONSTER1_vga_x, MONSTER2_vga_x, MONSTER3_vga_x, MONSTER4_vga_x, MONSTER5_vga_x, MONSTER6_vga_x, MONSTER7_vga_x; 
	reg [8:0] maze_vga_y, MONSTER1_vga_y, MONSTER2_vga_y, MONSTER3_vga_y, MONSTER4_vga_y, MONSTER5_vga_y, MONSTER6_vga_y, MONSTER7_vga_y; 

	// The directions of each character
	reg [1:0] maze_dx, MONSTER1_dx, MONSTER2_dx, MONSTER3_dx, MONSTER4_dx, MONSTER5_dx, MONSTER6_dx, MONSTER7_dx; 
	reg [1:0] maze_dy, MONSTER1_dy, MONSTER2_dy, MONSTER3_dy, MONSTER4_dy, MONSTER5_dy, MONSTER6_dy, MONSTER7_dy; 

	// The target x and y coordinates for a character (it is 9 bit so that it can do signed operations)
	reg [8:0] target_x;
	reg [8:0] target_y;
	
	reg [4:0] char_map_x;
	reg [4:0] char_map_y;
	
	reg is_hit_maze;
	
	
	// The pins that go to the map
	reg [4:0] map_x;
	reg [4:0] map_y;
	reg [2:0] sprite_data_in;
	wire [2:0] sprite_data_out;
	reg map_readwrite; //0 for read, 1 for write
	reg preset=1'b0;
	// To start/stop the display controller
	reg reset_display;
	reg start_display = 1'b0;
	reg finished_display = 1'b0;
	reg [27:0] counter = 28'd0;
	wire is_display_running;
	wire [4:0] display_map_x, display_map_y;
	reg [27:0] wait1;
	// The current state in FSM
	reg [5:0] cur_state;
	reg pass;
	reg [3:0] passcount;
	assign debug_leds[5:0] = cur_state;
	reg key;
	initial begin
	
		map_x = 4'b0;
		map_y = 4'b0;
		sprite_data_in = 3'b000;

		maze_vga_x = 9'd10;
		maze_vga_y = 9'd5;

		MONSTER1_vga_x = 9'd25; // Moves up and down on (5, 3)
		MONSTER1_vga_y = 9'd15;

		MONSTER2_vga_x = 9'd50; // Moves left and right on (10, 3)
		MONSTER2_vga_y = 9'd15;

		MONSTER3_vga_x = 9'd10; // Moves up and down on (15, 9)
		MONSTER3_vga_y = 9'd95;

		MONSTER4_vga_x = 9'd65; // Moves left and right on (13, 19)
		MONSTER4_vga_y = 9'd95;

		MONSTER5_vga_x = 9'd75; // Moves left and right on (13, 19)
		MONSTER5_vga_y = 9'd5;
		
		
		MONSTER6_vga_x = 9'd95; // Moves left and right on (13, 19)
		MONSTER6_vga_y = 9'd5;
		
		MONSTER7_vga_x = 9'd40; // Moves left and right on (13, 19)
		MONSTER7_vga_y = 9'd55;
		
		maze_dx = 2'd0;
		maze_dy = 2'd0;

		MONSTER1_dx = 2'b00;
		MONSTER1_dy = 2'b10;

		MONSTER2_dx = 2'b01;
		MONSTER2_dy = 2'b00;

		MONSTER3_dx = 2'b01;
		MONSTER3_dy = 2'b00;

		MONSTER4_dx = 2'b10;
		MONSTER4_dy = 2'b00;
		
		MONSTER5_dx = 2'b00;
		MONSTER5_dy = 2'b01;
		
		MONSTER6_dx = 2'b00;
		MONSTER6_dy = 2'b01;

		MONSTER7_dx = 2'b01;
		MONSTER7_dy = 2'b00;		
		preset=1'b0;
		cur_state = PRE;
		target_x = 9'd0;
		target_y = 9'd0;
		is_hit_maze = 1'b0;
	
		lifeCount=4'd3;
		reset_display = 1'b1;
		wait1=28'b0;
		pass=1'b0;
		passcount=4'b0;
		key=1'b0;
		score=1'b0;
		stop=1'b0;
	end
	
	wire Wdata, Wwren; 
  wire [5:0]BGcolour;
  wire [5:0]resetBG;
  assign Wdata = 1'b0;
  assign Wwren = 1'b0;
  wire[14:0]Waddress;
  reg [7:0]wirex;
  reg [6:0]wirey;
  assign Waddress = (wirey * 8'd160) + wirex; 
  
  reg endScreenEnable;
	
	always @(posedge slow_clock, posedge reset) 
	begin
		if (reset == 1'b1) begin

			sprite_data_in <= 3'b000;

			maze_vga_x <= 9'd10;
			maze_vga_y <= 9'd5;

			MONSTER1_vga_x <= 9'd25; // Moves up and down on (5, 3)
			MONSTER1_vga_y <= 9'd15;

			MONSTER2_vga_x <= 9'd50; // Moves left and right on (10, 3)
			MONSTER2_vga_y <= 9'd15;

			MONSTER3_vga_x <= 9'd10; // Moves up and down on (15, 9)
			MONSTER3_vga_y <= 9'd95;

			MONSTER4_vga_x <= 9'd65; // Moves left and right on (13, 19)
			MONSTER4_vga_y <= 9'd95;
			score<=1'b0;
			stop<=1'b0;
			preset=1'b1;
			MONSTER5_vga_x <= 9'd75; // Moves left and right on (13, 19)
			MONSTER5_vga_y <= 9'd5;
			
			MONSTER6_vga_x <= 9'd95; // Moves left and right on (13, 19)
			MONSTER6_vga_y <= 9'd5;

			MONSTER7_vga_x <= 9'd40; // Moves left and right on (13, 19)
			MONSTER7_vga_y <= 9'd55;
			
			maze_dx <= 2'd0;
			maze_dy <= 2'd0;

			MONSTER1_dx <= 2'b00;
			MONSTER1_dy <= 2'b10;

			MONSTER2_dx <= 2'b01;
			MONSTER2_dy <= 2'b00;

			MONSTER3_dx <= 2'b01;
			MONSTER3_dy <= 2'b00;

			MONSTER4_dx <= 2'b10;
			MONSTER4_dy <= 2'b00;

			MONSTER5_dx <= 2'b00;
			MONSTER5_dy <= 2'b01;
			
			MONSTER6_dx <= 2'b00;
			MONSTER6_dy <= 2'b01;
		

			MONSTER7_dx <= 2'b01;
			MONSTER7_dy <= 2'b00;
			
				pass<=1'b0;
				passcount<=4'b0;
			wait1<=28'b0;
			cur_state <= PRE;
			target_x <= 9'd0;
			target_y <= 9'd0;
			is_hit_maze <= 1'b0;
			lifeCount<=4'd3;
			key<=1'b0;
		end
		
		else if (!timer) begin
			cur_state <= END_GAME;
		end
		
		else begin
			case (cur_state)
				// ---------------------------------------------------------------------------
				// ============================Maze Game Starts ==============================
				// ---------------------------------------------------------------------------
				PRE:
				begin
				if(preset)begin
							cur_state<=maze_GET_TARGET;
				end
				if(preset&&sprite_data_out==3'b101)begin
				preset<=1'b0;
							sprite_data_in <= 3'b100;
							map_readwrite <= 1'b1;
							cur_state<=maze_GET_TARGET;
				end
				if (move_up||move_down||move_right||move_left)
				cur_state<=maze_GET_TARGET;
				else 
				cur_state<=PRE;
				end
				
				maze_TRY_player:
					begin
						char_map_x <= maze_vga_x / 9'd5;
						char_map_y <= maze_vga_y / 9'd5;
						map_readwrite <= 1'b0;
						cur_state <= maze_player_WAIT;
					end
				maze_player_WAIT: cur_state <= maze_player;
				maze_player:
					begin
						case (sprite_data_out)
						3'b001: // wall tile
						begin
					
							sprite_data_in <= 3'b000;
							map_readwrite <= 1'b1;
							score<=1'b1;
						end
						
						3'b010: // wall tile
						begin	
							sprite_data_in <= 3'b000;
							map_readwrite <= 1'b1;
							score<=1'b1;
						end	
						
						3'b100: // wall tile
						begin
							key<=1'b1;	
							sprite_data_in <= 3'b101;
							map_readwrite <= 1'b1;
							score<=1'b0;
						end
						3'b101: // wall tile
						begin
							key<=1'b1;	
							sprite_data_in <= 3'b100;
							map_readwrite <= 1'b1;
							score<=1'b0;
						end						
						default:
						begin	
							score<=1'b0;
						end
						endcase
						cur_state <= maze_GET_TARGET; 
					end
				maze_GET_TARGET:
				begin
			
					cur_state <= maze_GET_MAP_SPRITE;
				
					if(move_up)
						maze_dy <= 2'b10;
					else if(move_down)
						maze_dy <= 2'b01;
					else if(move_left)
						maze_dx <= 2'b10;
					else if(move_right)
						maze_dx <= 2'b01;
					else
						begin
							maze_dx <= 2'b00;
							maze_dy <= 2'b00;
						end
						
					case (maze_dx)
						2'b01: target_x <= maze_vga_x + 9'd1;//takes maze current pos and moves right	
						2'b10: target_x <= maze_vga_x - 9'd1;//takes maze current pos and moves left	
						default: target_x <= maze_vga_x;	
					endcase
					
					case (maze_dy)
						2'b01: target_y <= maze_vga_y + 9'd1;//moves down
						2'b10: target_y <= maze_vga_y - 9'd1;//moves up
						default: target_y <= maze_vga_y;
					endcase
					
				end
				
				
				maze_GET_MAP_SPRITE:
				begin
					case(maze_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(maze_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					
					map_readwrite <= 1'b0;
					cur_state <= maze_WAIT;				
				end
				maze_WAIT:
				begin
	
					cur_state <= maze_SET_POS;

				end

				maze_SET_POS:
				begin
					
					case (sprite_data_out)
						3'b011: // wall tile
						begin
							maze_vga_x <= maze_vga_x;
							maze_vga_y <= maze_vga_y;
							maze_dx <= 2'd0;
							maze_dy <= 2'd0;
						end
						
						
						default: // A black tile
						begin
							maze_vga_x <= target_x;
							maze_vga_y <= target_y;
						end
					endcase
					if (maze_vga_x==9'd95&&maze_vga_y==9'd95&&key==1'b1)
					cur_state <= END_GAME;
					else
					cur_state <= MONSTER1_GET_TARGET;
				end

				// ---------------------------------------------------------------------------
				// ============================ MONSTER 1 ====================================
				// ---------------------------------------------------------------------------
				MONSTER1_GET_TARGET:
				begin
					cur_state <= MONSTER1_GET_MAP_SPRITE;	

					case (MONSTER1_dx)
						2'b01: target_x <= MONSTER1_vga_x + 9'd1;	
						2'b10: target_x <= MONSTER1_vga_x - 9'd1;	
						default: target_x <= MONSTER1_vga_x;	
					endcase
					
					case (MONSTER1_dy)
						2'b01: target_y <= MONSTER1_vga_y + 9'd1;
						2'b10: target_y <= MONSTER1_vga_y - 9'd1;
						default: target_y <= MONSTER1_vga_y;
					endcase
				end
				MONSTER1_GET_MAP_SPRITE:
				begin
				case(MONSTER1_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
				case(MONSTER1_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER1_WAIT;
				end
					

					
				MONSTER1_WAIT:
				begin
					cur_state <= MONSTER1_SET_POS;
				end
				
				MONSTER1_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER1_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER1_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
						pass<=1'b1;
					end
					else if (sprite_data_out == 3'b011) begin // Negative directions
						MONSTER1_dx <= ~MONSTER1_dx;
						MONSTER1_dy <= ~MONSTER1_dy;
					end

					else begin
						if(pass==1'b1)begin
						passcount<=passcount+1;
						end
						if(passcount==4'b1111)begin
						pass<=1'b0;
						passcount<=4'b0;
						end
						is_hit_maze <= 1'b0;
						
						MONSTER1_vga_x <= target_x;
						MONSTER1_vga_y <= target_y;						
					end
					//if(is_hit_maze==1'b0)
					cur_state <= MONSTER2_GET_TARGET;
				end

				// ---------------------------------------------------------------------------
				// ============================ MONSTER 2 ====================================
				// ---------------------------------------------------------------------------
				MONSTER2_GET_TARGET:
				begin
					cur_state <= MONSTER2_GET_MAP_SPRITE;

					case (MONSTER2_dx)
						2'b01: target_x <= MONSTER2_vga_x + 9'd1;	
						2'b10: target_x <= MONSTER2_vga_x - 9'd1;	
						default: target_x <= MONSTER2_vga_x;	
					endcase
					
					case (MONSTER2_dy)
						2'b01: target_y <= MONSTER2_vga_y - 9'd1;
						2'b10: target_y <= MONSTER2_vga_y + 9'd1;
						default: target_y <= MONSTER2_vga_y;
					endcase
					

				end
				MONSTER2_GET_MAP_SPRITE:
				begin
					case(MONSTER2_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(MONSTER2_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER2_WAIT;
				end			
				
				MONSTER2_WAIT:
				begin
					cur_state <= MONSTER2_SET_POS;
				end

				MONSTER2_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER2_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER2_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						pass<=1'b1;
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
					end
					
					else if (sprite_data_out == 3'b011) begin // If the monster hits the wall, goes in the opposite direction
						MONSTER2_dx <= ~MONSTER2_dx;
						MONSTER2_dy <= ~MONSTER2_dy;
					end

					else begin
					
					if(pass==1'b1)begin
					passcount<=passcount+1;
					end
					
					if(passcount==4'b1111)begin
					pass<=1'b0;
					passcount<=4'b0;
					end
					
						is_hit_maze <= 1'b0;
						MONSTER2_vga_x <= target_x;
						MONSTER2_vga_y <= target_y;						
					end
			
					cur_state <= MONSTER3_GET_TARGET;
				
				end

				// ---------------------------------------------------------------------------
				// ============================ MONSTER 3 ====================================
				// ---------------------------------------------------------------------------
				MONSTER3_GET_TARGET:
				begin
					cur_state <= MONSTER3_GET_MAP_SPRITE;
					case (MONSTER3_dx)
						2'b01: target_x <= MONSTER3_vga_x + 9'd1;	
						2'b10: target_x <= MONSTER3_vga_x - 9'd1;	
						default: target_x <= MONSTER3_vga_x;	
					endcase
					
					case (MONSTER3_dy)
						2'b01: target_y <= MONSTER3_vga_y - 9'd1;
						2'b10: target_y <= MONSTER3_vga_y + 9'd1;
						default: target_y <= MONSTER3_vga_y;
					endcase
				end
				MONSTER3_GET_MAP_SPRITE:
				begin
				begin
					case(MONSTER3_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(MONSTER3_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER3_WAIT;
				end			

				end
				MONSTER3_WAIT:
				begin
					cur_state <= MONSTER3_SET_POS;
				end
				MONSTER3_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER3_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER3_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						pass<=1'b1;
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
					end
					else if (sprite_data_out == 3'b011) begin // If the monster hits the wall, goes in the opposite direction
						MONSTER3_dx <= ~MONSTER3_dx;
						MONSTER3_dy <= ~MONSTER3_dy;
					end

					else begin
					if(pass==1'b1)begin
					passcount<=passcount+1;
					end
					
					if(passcount==4'b1111)begin
					pass<=1'b0;
					passcount<=4'b0;
					end
						is_hit_maze <= 1'b0;
						MONSTER3_vga_x <= target_x;
						MONSTER3_vga_y <= target_y;						
					end
					cur_state <= MONSTER4_GET_TARGET;
				end

				// ---------------------------------------------------------------------------
				// ============================ MONSTER 4 ====================================
				// ---------------------------------------------------------------------------
				MONSTER4_GET_TARGET:
				begin
					cur_state <= MONSTER4_GET_MAP_SPRITE;

					case (MONSTER4_dx)
						2'b01: target_x <= MONSTER4_vga_x + 9'd1;	
						2'b10: target_x <= MONSTER4_vga_x - 9'd1;	
						default: target_x <= MONSTER4_vga_x;	
					endcase
					
					case (MONSTER4_dy)
						2'b01: target_y <= MONSTER4_vga_y + 9'd1;
						2'b10: target_y <= MONSTER4_vga_y - 9'd1;
						default: target_y <= MONSTER4_vga_y;
					endcase
				end
				MONSTER4_GET_MAP_SPRITE:
				begin
					case(MONSTER4_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(MONSTER4_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER4_WAIT;
				end			
				
				MONSTER4_WAIT:
				begin
					cur_state <= MONSTER4_SET_POS;
				end
				MONSTER4_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER4_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER4_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						pass<=1'b1;
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
					end
					else if (sprite_data_out == 3'b011) begin // If the monster hits the wall, goes in the opposite direction
						MONSTER4_dx <= ~MONSTER4_dx;
						MONSTER4_dy <= ~MONSTER4_dy;
					end

					else begin
					if(pass==1'b1)begin
					passcount<=passcount+1;
					end
					
					if(passcount==4'b1111)begin
					pass<=1'b0;
					passcount<=4'b0;
					end
						is_hit_maze <= 1'b0;
						MONSTER4_vga_x <= target_x;
						MONSTER4_vga_y <= target_y;						
					end
					
					cur_state <= MONSTER5_GET_TARGET;

				end
				MONSTER5_GET_TARGET:
				begin
					cur_state <= MONSTER5_GET_MAP_SPRITE;

					case (MONSTER5_dx)
					2'b01: target_x <= MONSTER5_vga_x + 9'd1;	
					2'b10: target_x <= MONSTER5_vga_x - 9'd1;	
					default: target_x <= MONSTER5_vga_x;	
					endcase

					case (MONSTER5_dy)
					2'b01: target_y <= MONSTER5_vga_y + 9'd1;
					2'b10: target_y <= MONSTER5_vga_y - 9'd1;
					default: target_y <= MONSTER5_vga_y;
					endcase
				end
				MONSTER5_GET_MAP_SPRITE:
				begin
					case(MONSTER5_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(MONSTER5_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER5_WAIT;
				end			
				
				MONSTER5_WAIT:
				begin
					cur_state <= MONSTER5_SET_POS;
				end
				MONSTER5_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER5_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER5_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						pass<=1'b1;
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
					end
					else if (sprite_data_out == 3'b011) begin // If the monster hits the wall, goes in the opposite direction
						MONSTER5_dx <= ~MONSTER5_dx;
						MONSTER5_dy <= ~MONSTER5_dy;
					end

					else begin
					if(pass==1'b1)begin
					passcount<=passcount+1;
					end
					
					if(passcount==4'b1111)begin
					pass<=1'b0;
					passcount<=4'b0;
					end
						is_hit_maze <= 1'b0;
						MONSTER5_vga_x <= target_x;
						MONSTER5_vga_y <= target_y;						
					end
				
					cur_state <= MONSTER6_GET_TARGET;
	
				end
				MONSTER6_GET_TARGET:
				begin
					cur_state <= MONSTER6_GET_MAP_SPRITE;

					case (MONSTER6_dx)
					2'b01: target_x <= MONSTER6_vga_x + 9'd1;	
					2'b10: target_x <= MONSTER6_vga_x - 9'd1;	
					default: target_x <= MONSTER6_vga_x;	
					endcase

					case (MONSTER6_dy)
					2'b01: target_y <= MONSTER6_vga_y + 9'd1;
					2'b10: target_y <= MONSTER6_vga_y - 9'd1;
					default: target_y <= MONSTER6_vga_y;
					endcase
				end
				MONSTER6_GET_MAP_SPRITE:
				begin
					case(MONSTER6_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(MONSTER6_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER6_WAIT;
				end			
				
				MONSTER6_WAIT:
				begin
					cur_state <= MONSTER6_SET_POS;
				end
				MONSTER6_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER6_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER6_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						pass<=1'b1;
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
					end
					else if (sprite_data_out == 3'b011) begin // If the monster hits the wall, goes in the opposite direction
						MONSTER6_dx <= ~MONSTER6_dx;
						MONSTER6_dy <= ~MONSTER6_dy;
					end

					else begin
					if(pass==1'b1)begin
					passcount<=passcount+1;
					end
					
					if(passcount==4'b1111)begin
					pass<=1'b0;
					passcount<=4'b0;
					end
						is_hit_maze <= 1'b0;
						MONSTER6_vga_x <= target_x;
						MONSTER6_vga_y <= target_y;						
					end
					
			
					cur_state <= MONSTER7_GET_TARGET;
		
				end
				MONSTER7_GET_TARGET:
				begin
					cur_state <= MONSTER7_GET_MAP_SPRITE;

					case (MONSTER7_dx)
					2'b01: target_x <= MONSTER7_vga_x + 9'd1;	
					2'b10: target_x <= MONSTER7_vga_x - 9'd1;	
					default: target_x <= MONSTER7_vga_x;	
					endcase

					case (MONSTER7_dy)
					2'b01: target_y <= MONSTER7_vga_y + 9'd1;
					2'b10: target_y <= MONSTER7_vga_y - 9'd1;
					default: target_y <= MONSTER7_vga_y;
					endcase
				end
				MONSTER7_GET_MAP_SPRITE:
				begin
					case(MONSTER7_dx)
						2'b01: char_map_x <= (target_x + 9'd4) / 9'd5;
						default: char_map_x <= target_x / 9'd5;
					endcase
					case(MONSTER7_dy)
						2'b01: char_map_y <= (target_y + 9'd4)/ 9'd5;
						default: char_map_y <= target_y / 9'd5;
					endcase
					map_readwrite <= 1'b0;
					cur_state <= MONSTER7_WAIT;
				end			
				
				MONSTER7_WAIT:
				begin
					cur_state <= MONSTER7_SET_POS;
				end
				MONSTER7_SET_POS:
				begin
					if (maze_vga_x / 9'd5 == MONSTER7_vga_x / 9'd5 && maze_vga_y / 9'd5 == MONSTER7_vga_y / 9'd5&&pass==1'b0) 
					begin // If hit maze
						pass<=1'b1;
						is_hit_maze <= 1'b1;
						lifeCount<=lifeCount-1;
					end
					else if (sprite_data_out == 3'b011) begin // If the monster hits the wall, goes in the opposite direction
						MONSTER7_dx <= ~MONSTER7_dx;
						MONSTER7_dy <= ~MONSTER7_dy;
					end

					else begin
					if(pass==1'b1)begin
					passcount<=passcount+1;
					end
					
					if(passcount==4'b1111)begin
					pass<=1'b0;
					passcount<=4'b0;
					end
						is_hit_maze <= 1'b0;
						MONSTER7_vga_x <= target_x;
						MONSTER7_vga_y <= target_y;						
					end

					cur_state <= START_DISPLAY;
		
				end				
				// ---------------------------------------------------------------------------
				// ============================ DISPLAY ======================================
				// ---------------------------------------------------------------------------
				START_DISPLAY:
				begin
					reset_display <= 1'b0;
					start_display <= 1'b1;
					counter <= 28'd0;
					cur_state <= VIEW_DISPLAY;
				end
				VIEW_DISPLAY:
				begin
					reset_display <= 1'b0;
					
					if (start_display == 1'b1) begin
						counter <= counter + 28'd1;
						start_display <= 1'b0;
						cur_state <= VIEW_DISPLAY;
					end
					else if (start_display == 1'b0 && counter <= 28'd11300) begin
						counter <= counter + 28'd1;
						cur_state <= VIEW_DISPLAY;
					end
					else if (start_display == 1'b0 && counter > 28'd11300)begin
						counter <= 28'd0;
						cur_state <= STOP_DISPLAY;
					end
				end
				STOP_DISPLAY:
				begin
					reset_display <= 1'b1;
					counter <= 28'd0;
					
					if (lifeCount==4'd0) begin
						cur_state <= END_GAME;
					end
					else begin
						cur_state <= maze_TRY_player;
					end
				end
				
				END_GAME:
				begin
						
			endScreenEnable <= 1'b1;


	stop<=1'b1;
	

					counter <= 28'd0;
					
					
				end
			endcase			
		end
	end
	
	always @(*)
	begin
		if (cur_state == VIEW_DISPLAY) begin
			map_x = display_map_x;
			map_y = display_map_y;
		end
		else begin
			map_x = char_map_x;
			map_y = char_map_y;
		end
	end
	
		
	// The map, containing map data
	MapController map(
		.map_x(map_x),
		.map_y(map_y),
		.sprite_data_in(sprite_data_in),
		.sprite_data_out(sprite_data_out),
		.readwrite(map_readwrite),
		.clock_50(clock_50));

	DisplayController display_controller(
		.en(1'b1),
		.map_x(display_map_x),
		.map_y(display_map_y),
		.sprite_type(sprite_data_out),
		
		.maze_orientation({move_left,move_right,move_up,move_down}),		
		.maze_vga_x(maze_vga_x[7:0]),
		.maze_vga_y(maze_vga_y[7:0]),
		
		.MONSTER1_vga_x(MONSTER1_vga_x[7:0]),
		.MONSTER1_vga_y(MONSTER1_vga_y[7:0]),
		
		.MONSTER2_vga_x(MONSTER2_vga_x[7:0]),
		.MONSTER2_vga_y(MONSTER2_vga_y[7:0]),
		
		.MONSTER3_vga_x(MONSTER3_vga_x[7:0]),
		.MONSTER3_vga_y(MONSTER3_vga_y[7:0]),
		
		.MONSTER4_vga_x(MONSTER4_vga_x[7:0]),
		.MONSTER4_vga_y(MONSTER4_vga_y[7:0]),
		.MONSTER5_vga_x(MONSTER5_vga_x[7:0]),
		.MONSTER5_vga_y(MONSTER5_vga_y[7:0]),
		.MONSTER6_vga_x(MONSTER6_vga_x[7:0]),
		.MONSTER6_vga_y(MONSTER6_vga_y[7:0]),
		.MONSTER7_vga_x(MONSTER7_vga_x[7:0]),
		.MONSTER7_vga_y(MONSTER7_vga_y[7:0]),
		.vga_plot(vga_plot),
		.vga_x(vga_x),
		.vga_y(vga_y),
		.vga_color(vga_colour),
		.reset(reset_display || reset),
		.clock_50(clock_50),
		.is_display_running(is_display_running));

endmodule

// ---------------------------------------------------------------------------
// ============================ MONSTER 4 ====================================
// ---------------------------------------------------------------------------

module RateDivider(
	input [27:0] interval,
	input reset,
	input en,
	input clock_50,
	output reg reduced_clock);

	reg [27:0] cur_time;

	always @(posedge clock_50)
	begin
		if (reset == 1'b1)
		begin
			cur_time <= interval;
			reduced_clock <= 1'b0;
		end
		else if (en == 1'b1)
		begin
			if (cur_time == 27'd1) 
			begin
				cur_time <= interval;
				reduced_clock <= ~reduced_clock;
			end
			else
			begin
				cur_time <= cur_time - 1'b1;
			end
		end
	end
endmodule




module HexDisplay(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule

module Keyboard(CLOCK_50, PS2_CLK, PS2_DAT, A[3:0], Space);
	input CLOCK_50;
	output reg Space;
	output reg [3:0]A;
	wire [7:0]info;
	wire enable;
	inout PS2_CLK;
	inout PS2_DAT;
	wire resetk;
	assign resetk = 0;
	PS2_Controller PS2( //Keyboard controller
		.CLOCK_50(CLOCK_50), 
		.reset(resetk),
		.PS2_CLK(PS2_CLK),
		.PS2_DAT(PS2_DAT),
		.received_data(info[7:0]),
		.received_data_en(enable)
	);
	
	reg [1:0]counter;
	always@ (posedge enable)begin
		if(info == 8'hF0)
			counter <= 2'b00;
		else
			counter <= counter + 1'b1;
	end
	
	always@ (posedge CLOCK_50)begin
		if(counter == 2'b10)begin
			if(info == 8'h6B)
				A[0] = 1;
			if(info == 8'h72)
				A[1] = 1;
			if(info == 8'h75)
				A[2] = 1;
			if(info == 8'h74)
				A[3] = 1;
			if(info == 8'h29)
				Space = 1;
		end
		if(info == 8'hF0)begin
			A[3:0] = 0;
			Space = 0;
		end
	end
	
endmodule

module MapController(
	input [4:0] map_x,
	input [4:0] map_y,
	input [2:0] sprite_data_in,
	output [2:0] sprite_data_out,
	input readwrite,
	input clock_50);

	wire [8:0] extended_map_x = {3'b000, map_x};

	wire [8:0] extended_map_y = {3'b000, map_y};


	wire [8:0] client_address;
	assign client_address = (9'd21 * extended_map_y) + extended_map_x;
	
	Map map(
		.address(client_address),
		.clock(clock_50),
		.data(sprite_data_in),
		.wren(readwrite),
		.q(sprite_data_out)
		);

endmodule

module MapDisplayController(
	input en, 
	output reg unsigned [4:0] map_x, 
	output reg unsigned [4:0] map_y, 
	input [2:0] sprite_type, 
	output reg vga_plot, 
	output unsigned [7:0] vga_x,
	output unsigned [7:0] vga_y,
	output reg [2:0] vga_color,
	input reset, 
	input clock_50,
	output [7:0] debug_leds);
	reg postreset;
	reg unsigned [2:0] cur_sprite_x;
	reg unsigned [2:0] cur_sprite_y;
	
	//In Quartus where all registers must be initilaized to a value regardless of the clock cycle.  
	initial 
	begin
		map_x = 5'd0;
		map_y = 5'd0;
		cur_sprite_x = 3'd0;
		cur_sprite_y = 3'd0;
		vga_plot = 1'b0;
		vga_color = 3'd0;
		postreset=1'b0;
	end 

	always @(posedge clock_50) 
	begin
		if (reset == 1'b1) 
		begin
			map_x <= 5'd0;
			map_y <= 5'd0;
			cur_sprite_x <= 3'd0;
			cur_sprite_y <= 3'd0;	
			vga_plot <= 1'b1;
			postreset<=1'b1;
		end

		else
		begin
			// If we are currently drawing the sprite
			if (cur_sprite_y != 3'd4 || cur_sprite_x != 3'd4)
			begin			
				if(cur_sprite_x < 3'd4)
					cur_sprite_x <= cur_sprite_x + 3'd1;
					
				else //if (cur_sprite_x == 3'd4)
				begin
					cur_sprite_x <= 3'd0;
					cur_sprite_y <= cur_sprite_y + 3'd1;
				end
			end
			// If we have finished drawing the sprite
			else 
			begin
				cur_sprite_x <= 3'd0;
				cur_sprite_y <= 3'd0;
				
				// Reset the current sprite coordinates
				if (map_x == 5'd20)
				begin
					map_x <= 5'd0;											
					
					if (map_y == 5'd20)
					begin
						map_y <= 5'd0;
					end
					else
					begin
						map_y <= map_y + 5'd1;
					end
				end
				else 
				begin
					map_x <= map_x + 5'd1;					
				end	
			end		
		end
	end	

	// Determine the absolute pixel coordinates on the screen
	assign vga_x = ({3'b000, map_x} * 8'd5) + {5'd0, cur_sprite_x} + 8'd26;
	assign vga_y = ({3'b000, map_y} * 8'd5) + {5'd0, cur_sprite_y} + 8'd1;

	// Determining the sprite
	reg [4:0] row0;
	reg [4:0] row1;
	reg [4:0] row2;
	reg [4:0] row3;
	reg [4:0] row4;

	reg [2:0] sprite_color;

	always @(*)
	begin			
		if (sprite_type == 3'b000||sprite_type == 3'b001||sprite_type == 3'b010) // A black tile
		begin
			row0 = 5'b11111;
			row1 = 5'b11111;
			row2 = 5'b11111;
			row3 = 5'b11111;
			row4 = 5'b11111;

			sprite_color = 3'b000;
		end
		else if (sprite_type == 3'b011) // A wall
		begin
			row0 = 5'b11110;
			row1 = 5'b11111;
			row2 = 5'b11111;
			row3 = 5'b11111;
			row4 = 5'b11111;

			sprite_color = 3'b010;
		end
		else if (sprite_type == 3'b100) // A key
		begin
			row0 = 5'b01100;
			row1 = 5'b01000;
			row2 = 5'b01000;
			row3 = 5'b01100;
			row4 = 5'b01100;

			sprite_color = 3'b111;
		end
		else if (sprite_type == 3'b101) // key blink Animation
		begin
			row0 = 5'b11111;
			row1 = 5'b11111;
			row2 = 5'b11111;
			row3 = 5'b11111;
			row4 = 5'b11111;

			sprite_color = 3'b000;
		end
		else
		begin
			row0 = 5'b11111;
			row1 = 5'b11111;
			row2 = 5'b11111;
			row3 = 5'b11111;
			row4 = 5'b11111;

			sprite_color = 3'b010;
		end
	end
	
	reg [6:0] selected_row;
	always @(*)
	begin
		case (cur_sprite_y)
			4'd0: selected_row = row0;
			4'd1: selected_row = row1;
			4'd2: selected_row = row2;
			4'd3: selected_row = row3;
			4'd4: selected_row = row4;

			default: selected_row = row0;
		endcase
	end
	
	reg selected_col;
	always @(*)
	begin
		case (cur_sprite_x)
			4'd0: selected_col = selected_row[0];
			4'd1: selected_col = selected_row[1];
			4'd2: selected_col = selected_row[2];
			4'd3: selected_col = selected_row[3];
			4'd4: selected_col = selected_row[4];

			default: selected_col = selected_row[0];
		endcase
	end
	
	always @(*)
	begin
		case (selected_col)
			1'b1: vga_color = sprite_color;
			1'b0: vga_color = 3'b000;
		endcase
	end
endmodule

module DisplayController(
	input en, 
	output [4:0] map_x, 
	output [4:0] map_y, 
	input [2:0] sprite_type, 
	
	input [3:0] maze_orientation,
	input [7:0] maze_vga_x,
	input [7:0] maze_vga_y,
	
	input [7:0] MONSTER1_vga_x,
	input [7:0] MONSTER1_vga_y,
	
	input [7:0] MONSTER2_vga_x,
	input [7:0] MONSTER2_vga_y,
	
	input [7:0] MONSTER3_vga_x,
	input [7:0] MONSTER3_vga_y,
	
	input [7:0] MONSTER4_vga_x,
	input [7:0] MONSTER4_vga_y,
	input [7:0] MONSTER5_vga_x,
	input [7:0] MONSTER5_vga_y,
	input [7:0] MONSTER6_vga_x,
	input [7:0] MONSTER6_vga_y,
	input [7:0] MONSTER7_vga_x,
	input [7:0] MONSTER7_vga_y,
	output reg vga_plot, 
	output reg [7:0] vga_x,
	output reg [7:0] vga_y,
	output reg [2:0] vga_color,
	
	input reset, 
	input clock_50,
	output reg is_display_running);
	
	// A clock, used to determine which display controller to use.
	reg unsigned selected_display_controller;
	reg unsigned [14:0] current_time;
	
	// Determines what the character controller is currently displaying
	wire [2:0] character_type;
	reg unsigned [7:0] x_out, y_out;
	
	initial
	begin
		selected_display_controller = 1'b0;
		current_time = 15'd0;
		x_out = 8'd0;
		y_out = 8'd0;
	end

	always @(posedge clock_50)
	begin
		if (reset == 1'b1) begin
			current_time = 15'd0;
			selected_display_controller = 1'b0;
			is_display_running <= 1'b0;
		end
		
		else begin
			if (current_time < 15'd11025)
			begin
				is_display_running <= 1'b1;
				current_time <= current_time + 15'd1;
				selected_display_controller <= 1'b0;
			end
			else if (current_time >= 15'd11025 && current_time <= 15'd11125)/////?
			begin
				is_display_running <= 1'b1;
				current_time <= current_time + 15'd1;
				selected_display_controller <= 1'b1;
			end
			else 
			begin
				is_display_running <= 1'b0;
				current_time <= 15'd0;
				selected_display_controller <= 1'b0;    			
			end
		end		
	end
	
	// A mux used to control which character to select
	always @(*)
	begin
		case (character_type)
			// maze
			3'd0: begin 
				x_out = maze_vga_x;
				y_out = maze_vga_y;
			end
			
			// MONSTER 1
			3'd1: begin
				x_out = MONSTER1_vga_x;
				y_out = MONSTER1_vga_y;
			end
			
			// MONSTER 2
			3'd2: begin
				x_out = MONSTER2_vga_x;
				y_out = MONSTER2_vga_y;
			end
			
			// MONSTER 3
			3'd3: begin
				x_out = MONSTER3_vga_x;
				y_out = MONSTER3_vga_y;
			end
			
			// MONSTER 4
			3'd4: begin//
				x_out = MONSTER4_vga_x;
				y_out = MONSTER4_vga_y;
			end
			
			//MONSTER 5
			3'd5: begin//
			x_out = MONSTER5_vga_x;
			y_out = MONSTER5_vga_y;
			end
			//MONSTER 6
			3'd6: begin//
			x_out = MONSTER6_vga_x;
			y_out = MONSTER6_vga_y;
			end
			//MONSTER 7
			3'd7: begin//
			x_out = MONSTER7_vga_x;
			y_out = MONSTER7_vga_y;
			end
			
			default: begin
				x_out = 8'd0;
				y_out = 8'd0;
			end
		endcase
	end

	// The VGA output pins from the various controllers.
	wire [7:0] vga_x_cdc;
	wire [7:0] vga_y_cdc;
	wire [7:0] vga_x_mdc;
	wire [7:0] vga_y_mdc;
	wire [2:0] vga_color_cdc;
	wire [2:0] vga_color_mdc;
	wire vga_plot_cdc;
	wire vga_plot_mdc;

	CharacterDisplayController cdc_controller(
		.en(en),
		.maze_orientation(maze_orientation),
		.character_type(character_type),
		.char_x(x_out),
		.char_y(y_out),
		.vga_plot(vga_plot_cdc),
		.vga_x(vga_x_cdc),
		.vga_y(vga_y_cdc),
		.vga_color(vga_color_cdc),
		.reset(reset),
		.clock_50(clock_50)
	);

	MapDisplayController mdc_controller(
		.en(en), 
		.map_x(map_x), 
		.map_y(map_y), 
		.sprite_type(sprite_type), 
		.vga_plot(vga_plot_mdc), 
		.vga_x(vga_x_mdc), 
		.vga_y(vga_y_mdc), 
		.vga_color(vga_color_mdc),
		.reset(reset), 
		.clock_50(clock_50), 
		.debug_leds(debug_leds)
	);
	
	// The mux, used to select which vga pins to use
	always @(*)
	begin		
		if (selected_display_controller == 1'b0)
		begin
			vga_x = vga_x_mdc;
			vga_y = vga_y_mdc;
			vga_color = vga_color_mdc;
			vga_plot = vga_plot_mdc;	
		end
		else 
		begin
			vga_x = vga_x_cdc;
			vga_y = vga_y_cdc;
			vga_color = vga_color_cdc;
			vga_plot = vga_plot_cdc;	
		end
	end

endmodule

module CharacterDisplayController(
	input en,
	input [3:0] maze_orientation,
	output reg [2:0] character_type,
	input unsigned [7:0] char_x,
	input unsigned [7:0] char_y,
	output reg vga_plot,
	output [7:0] vga_x,
	output [7:0] vga_y,
	output reg [2:0] vga_color,
	input reset,
	input clock_50);
	// Drawing the pixels of each character and of each of their bitmaps
	reg unsigned [2:0] cur_sprite_x;
	reg unsigned [2:0] cur_sprite_y;

	//In Quartus where all registers must be initilaized to a value regardless of the clock cycle.
	initial
	begin
		character_type = 3'd0;
		cur_sprite_x = 3'd0;
		cur_sprite_y = 3'd0;
	end

	always @(posedge clock_50)
	begin
		if (reset == 1'b1)
		begin
			character_type <= 3'd0;
			cur_sprite_x <= 3'd0;
			cur_sprite_y <= 3'd0;
		end
		else 
		begin
			// If we are currently drawing the sprite
			if (cur_sprite_y != 3'd4 || cur_sprite_x != 3'd4)
			begin
				if(cur_sprite_x < 3'd4)
				begin
					cur_sprite_x <= cur_sprite_x + 3'd1;
				end

				else // if (cur_sprite_x == 3'd4)
				begin
					cur_sprite_x <= 3'd0;
					cur_sprite_y <= cur_sprite_y + 3'd1;
				end
			end

			// If we have finished drawing the sprite
			else
			begin
				cur_sprite_x <= 3'd0;
				cur_sprite_y <= 3'd0;

				if (character_type == 3'd7)
				begin
					character_type <= 3'd0;
				end
				else
				begin
					character_type <= character_type + 3'd1;
				end
			end
		end
	end

	// Determine the absolute pixel coordinates on the screen
	assign vga_x = char_x + {5'd00000, cur_sprite_x} + 8'd26;
	assign vga_y = char_y + {5'd00000, cur_sprite_y} + 8'd1;

	// Determining the bitmap of the characters
	reg [4:0] row0;
	reg [4:0] row1;
	reg [4:0] row2;
	reg [4:0] row3;
	reg [4:0] row4;

	reg [2:0] sprite_color;

	always @(*)
	begin
		if (character_type == 3'b000) // maze
		begin
			if (maze_orientation == 4'b1000) // Facing left
			begin
				row0 = 5'b11000;
				row1 = 5'b11100;
				row2 = 5'b10011;
				row3 = 5'b11100;
				row4 = 5'b11000;
			end
			else if (maze_orientation == 4'b0100)// Facing right
			begin
				row0 = 5'b00011;
				row1 = 5'b00111;
				row2 = 5'b11001;
				row3 = 5'b00111;
				row4 = 5'b00011;
			end
			else if (maze_orientation == 4'b0010)// Facing up
			begin
				row0 = 5'b00100;
				row1 = 5'b00100;
				row2 = 5'b01010;
				row3 = 5'b11011;
				row4 = 5'b11111;
			end
			else // Facing down
			begin
				row0 = 5'b11111;
				row1 = 5'b11011;
				row2 = 5'b01010;
				row3 = 5'b00100;
				row4 = 5'b00100;
			end			
			sprite_color = 3'b100;
		end
		else // The MONSTERs
		begin
			row0 = 5'b10001;
			row1 = 5'b01110;
			row2 = 5'b00100;
			row3 = 5'b01110;
			row4 = 5'b10001;

			case (character_type)
				3'b001: sprite_color = 3'b001; 
				3'b010: sprite_color = 3'b001; 
				3'b011: sprite_color = 3'b001; 
				3'b100: sprite_color = 3'b001;
				3'b101: sprite_color = 3'b001;
				3'b110: sprite_color = 3'b001;
				3'b111: sprite_color = 3'b001;
				default: sprite_color = 3'b000;
			endcase
		end
	end

	reg [6:0] selected_row;
	always @(*)
	begin
		case (cur_sprite_y)
			4'd0: selected_row = row0;
			4'd1: selected_row = row1;
			4'd2: selected_row = row2;
			4'd3: selected_row = row3;
			4'd4: selected_row = row4;

			default: selected_row = row0;
		endcase
	end

	reg selected_col;
	always @(*)
	begin
		case (cur_sprite_x)
			4'd0: selected_col = selected_row[0];
			4'd1: selected_col = selected_row[1];
			4'd2: selected_col = selected_row[2];
			4'd3: selected_col = selected_row[3];
			4'd4: selected_col = selected_row[4];

			default: selected_col = selected_row[0];
		endcase
	end

	always @(*)
	begin
		vga_color = sprite_color;

		if (selected_col == 1'b1 && reset == 1'b0)
		begin
			vga_plot = 1'b1;
		end
		else
		begin
			vga_plot = 1'b0;
		end
	end

endmodule










