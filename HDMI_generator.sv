// Creating HDMI(DVI) signals

module	HDMI_generator	(
	input		logic							clk_i,
	input		logic							clk_i_fast,
		
	output	logic		[39:0]			transceive_data,
	
	output	logic							new_frame,
	output	logic							Need_video,
	input		logic		[7:0]				rddata,
	
	input		logic		[1:0]				ch_select,
	input		logic							input_video_valid_clk
);


//		Horizontal timings
localparam	HAP		=	800;		//	Active pixels
localparam	HFP		=	40;		//	Front porch
localparam	HBP		=	88;		//	Back porch
localparam	HSW		=	128;		//	Sync width
localparam	H_TOTAL	=	1056;		//	Total pixels
localparam	HPOL		=	1;			//	Sync polarity
//		Vertical timings
localparam	VAL		=	600;		// Active lines
localparam	VFP		=	1;			//	Front porch
localparam	VBP		=	23;		//	Back porch
localparam	VSW		=	4;			//	Sync width
localparam	V_TOTAL	=	628;		//	Total lines
localparam	VPOL		=	1;			// Sync polarity

//		Basic	shifts for output image
localparam	H_IMAGE	=	640;
localparam	V_IMAGE	=	480;
localparam	H_SHIFT	=	(HAP - H_IMAGE) / 2;
localparam	V_SHIFT	=	(VAL - V_IMAGE) / 2;

//		Shifts	for work indicator
localparam	WI_SIZE		=	13;
localparam	WI_H_SHIFT	=	40;
localparam	WI_V_SHIFT	=	30;

//		Shift	for channel indicator
localparam	CH_H_SHIFT	=	740;
localparam	CH_V_SHIFT	=	15;

/////////////////////////////////////////////////////////////////////////////////////////////////


logic		[$clog2(H_TOTAL)-1:0]		cnt_pix;
logic		[$clog2(V_TOTAL)-1:0]		cnt_line;

logic											Hsync, Vsync, DrawArea;	//Sync signals

logic		[7:0]								data_red, data_green, data_blue;		// data codes RGB

//		Counters	of HDMI
always_ff @( posedge clk_i ) begin
	cnt_pix		<= ( cnt_pix < H_TOTAL - 1 ) ? cnt_pix + 1'b1 : '0;
	if ( cnt_pix == H_TOTAL - 1 ) 
		cnt_line <= ( cnt_line < V_TOTAL - 1 ) ? cnt_line + 1'b1 : '0;
end

//		Sync signals
always_ff @( posedge clk_i ) begin
	DrawArea	<= ( cnt_pix >= ( HSW + HBP ) && cnt_pix < ( HSW + HBP + HAP ) && cnt_line >= ( VBP ) && cnt_line < ( VBP + VAL ) );
	Hsync		<=	HPOL ? ( cnt_pix < ( HSW ) )						: 	~( cnt_pix < ( HSW ) );
	Vsync		<=	VPOL ? ( cnt_line >= ( VBP + VAL + VFP ) )	: 	~( cnt_line >= ( VBP + VAL + VFP ) );
end

assign	new_frame	= ( cnt_line == ( V_TOTAL - 1 ) && cnt_pix == ( H_TOTAL - 1 ) ) ;


//		Work indicator
logic											work_indicator;
logic				[5:0]						cnt_work_indicator;
logic				[31:0]					x, y, r;

always_comb begin
	x	=	cnt_pix - ( HSW + HBP + WI_H_SHIFT );
	y	=	cnt_line - ( VBP + WI_V_SHIFT );
	r	=	WI_SIZE;
	work_indicator	= ( ( x*x + y*y ) < r*r ) && cnt_work_indicator[5];
end

always_ff @( posedge clk_i ) begin
	cnt_work_indicator	<= ( new_frame ) ? cnt_work_indicator + 1'b1 : cnt_work_indicator;
end


//		Channel indicator
logic											channel_indicator;
logic											draw_line;
logic			[$clog2(H_TOTAL)-1:0]	ch_cnt_pix;
logic			[$clog2(V_TOTAL)-1:0]	ch_cnt_line;

always_comb begin
	channel_indicator	= ( cnt_pix >= ( HSW + HBP + CH_H_SHIFT ) && cnt_pix 	< ( HSW + HBP + CH_H_SHIFT + 13)  &&
								cnt_line	>=	( VBP + CH_V_SHIFT ) 		&& cnt_line	<	( VBP + CH_V_SHIFT + 30 ) );
	ch_cnt_pix			= cnt_pix - ( HSW + HBP + CH_H_SHIFT );
	ch_cnt_line			= cnt_line - ( VBP + CH_V_SHIFT );
end

always_ff @ ( posedge clk_i ) begin
	if ( channel_indicator)
		case ( ch_select )
			0 : begin
				draw_line <= ( ch_cnt_pix >= 7 && ch_cnt_pix <= 9 ) || ( ch_cnt_pix == 6 && ch_cnt_line >= 1 && ch_cnt_line <= 5 ) ||
								 ( ch_cnt_pix == 5 && ch_cnt_line >= 2 && ch_cnt_line <= 5 ) || ( ch_cnt_pix == 4 && ch_cnt_line >= 3 && ch_cnt_line <= 5 ) ||
								 ( ch_cnt_pix == 3 && ch_cnt_line >= 4 && ch_cnt_line <= 5 );
			end
			1 : begin
				draw_line <= ( ch_cnt_line >= 27 && ch_cnt_line <= 29 ) || ( ch_cnt_pix == 10 && ch_cnt_line >= 0 && ch_cnt_line <= 16 ) ||
				( ch_cnt_pix == 11 && ch_cnt_line >= 1 && ch_cnt_line <= 15 ) || ( ch_cnt_pix == 12 && ch_cnt_line >= 2 && ch_cnt_line <= 14 ) ||
				( ch_cnt_pix == 0 && ( ( ch_cnt_line >= 2 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 17 && ch_cnt_line <= 26 ) ) ) ||
				( ch_cnt_pix == 1 && ( ( ch_cnt_line >= 1 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 16 && ch_cnt_line <= 26 ) ) ) ||
				( ch_cnt_pix == 2 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 15 && ch_cnt_line <= 26 ) ) ) ||
				( ch_cnt_pix == 3 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 3 ) || ( ch_cnt_line >= 14 && ch_cnt_line <= 18 ) ) ) ||
				( ch_cnt_pix == 4 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 2 ) || ( ch_cnt_line >= 14 && ch_cnt_line <= 17 ) ) ) ||
				( ch_cnt_pix == 5 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 2 ) || ( ch_cnt_line >= 14 && ch_cnt_line <= 16 ) ) ) ||
				( ch_cnt_pix == 6 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 2 ) || ( ch_cnt_line >= 14 && ch_cnt_line <= 16 ) ) ) ||
				( ch_cnt_pix == 7 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 2 ) || ( ch_cnt_line >= 14 && ch_cnt_line <= 16 ) ) ) ||
				( ch_cnt_pix == 8 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 3 ) || ( ch_cnt_line >= 13 && ch_cnt_line <= 16 ) ) ) ||
				( ch_cnt_pix == 9 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 12 && ch_cnt_line <= 16 ) ) ) ||
				( ch_cnt_pix ==10 && ( ch_cnt_line >= 0 && ch_cnt_line <= 16 ) ) || ( ch_cnt_pix == 11 && ( ch_cnt_line >= 1 && ch_cnt_line <= 15 ) ) ||
				( ch_cnt_pix ==12 && ( ch_cnt_line >= 2 && ch_cnt_line <= 14 ) );
			end
			2 : begin
				draw_line <= ( ch_cnt_pix == 0 && ( ( ch_cnt_line >= 2 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 25 && ch_cnt_line <= 27 ) ) ) ||
				( ch_cnt_pix == 1 && ( ( ch_cnt_line >= 1 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 25 && ch_cnt_line <= 28 ) ) ) ||
				( ch_cnt_pix == 2 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 25 && ch_cnt_line <= 29 ) ) ) ||
				( ch_cnt_pix == 3 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 3 ) || ( ch_cnt_line >= 13 && ch_cnt_line <= 15 ) || ( ch_cnt_line >= 26 && ch_cnt_line <= 29 ) ) ) ||
		( ch_cnt_pix >= 4 && ch_cnt_pix <=7 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 2 ) || ( ch_cnt_line >= 13 && ch_cnt_line <= 15 ) || ( ch_cnt_line >= 27 && ch_cnt_line <= 29 ) ) ) ||
				( ch_cnt_pix == 8 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 3 ) || ( ch_cnt_line >= 12 && ch_cnt_line <= 16 ) || ( ch_cnt_line >= 26 && ch_cnt_line <= 29 ) ) ) ||
				( ch_cnt_pix == 9 && ( ( ch_cnt_line >= 0 && ch_cnt_line <= 4 ) || ( ch_cnt_line >= 11 && ch_cnt_line <= 17 ) || ( ch_cnt_line >= 25 && ch_cnt_line <= 29 ) ) ) ||
				( ch_cnt_pix == 10 ) ||
				( ch_cnt_pix == 11 && ( ( ch_cnt_line >= 1 && ch_cnt_line <= 14 ) || ( ch_cnt_line >= 16 && ch_cnt_line <= 28 ) ) ) ||
				( ch_cnt_pix == 12 && ( ( ch_cnt_line >= 2 && ch_cnt_line <= 13 ) || ( ch_cnt_line >= 17 && ch_cnt_line <= 27 ) ) );
			end
			3 : begin 
				draw_line <= ( ch_cnt_pix >= 10 && ch_cnt_pix <= 12 ) || ( ch_cnt_line >= 12 && ch_cnt_line <= 14 ) ||
								 ( ch_cnt_pix >= 0 && ch_cnt_pix <= 2 && ch_cnt_line >= 0 && ch_cnt_line <= 14 );
			end
		endcase
	else
		draw_line	<= 1'b0;
end

//		Video from fifo
always_comb begin
	Need_video	=	( cnt_pix 	>= ( HSW + HBP + H_SHIFT ) && 	cnt_pix 	< 	( HSW + HBP + H_SHIFT + H_IMAGE ) && 
						  cnt_line	>=	( VBP + V_SHIFT ) 		&&  	cnt_line	<	( VBP + V_SHIFT + V_IMAGE )				);
end


always_ff @( posedge clk_i ) begin
	if ( work_indicator ) begin
		data_red		<= input_video_valid_clk ? '0	: 'hFF;
		data_green	<= input_video_valid_clk ? 'd128 : 'hFF;
		data_blue	<= input_video_valid_clk ? '0 : 'h00;
	end
	else if ( draw_line ) begin
		data_red		<= 'hFF;
		data_green	<= 'hFF;
		data_blue	<= 'hFF;
	end
	else begin
		data_red		<=	( Need_video ) ? rddata[7:0] : '0;
		data_green	<=	( Need_video ) ? rddata[7:0] : '0;
		data_blue	<=	( Need_video ) ? rddata[7:0] : '0;
	end
end


//	Encode 8/10b

logic		[9:0]		TMDS_red, TMDS_green, TMDS_blue;

TMDS_encoder	TMDS_encoder_red		( .clk( clk_i ), .VD ( data_red ), 		.VDE( DrawArea ), .CD( '0 ), 					 .TMDS( TMDS_red ) );
TMDS_encoder	TMDS_encoder_green	( .clk( clk_i ), .VD ( data_green ), 	.VDE( DrawArea ), .CD( '0 ), 					 .TMDS( TMDS_green ) );
TMDS_encoder	TMDS_encoder_blue		( .clk( clk_i ), .VD ( data_blue ), 	.VDE( DrawArea ), .CD( { Vsync, Hsync } ), .TMDS( TMDS_blue ) );

always_comb begin
//write data
	wr_data_fifo[79:0]		=	{	
		TMDS_red[9], 	TMDS_red[9], 	TMDS_red[8], 	TMDS_red[8], 	TMDS_red[7], 	TMDS_red[7], 	TMDS_red[6], 	TMDS_red[6],	TMDS_red[5], 	TMDS_red[5],
		TMDS_green[9], TMDS_green[9], TMDS_green[8], TMDS_green[8], TMDS_green[7], TMDS_green[7], TMDS_green[6], TMDS_green[6],	TMDS_green[5], TMDS_green[5],
		TMDS_blue[9], 	TMDS_blue[9], 	TMDS_blue[8], 	TMDS_blue[8], 	TMDS_blue[7], 	TMDS_blue[7], 	TMDS_blue[6], 	TMDS_blue[6],	TMDS_blue[5], 	TMDS_blue[5],
		10'h3FF,
		
		TMDS_red[4], 	TMDS_red[4], 	TMDS_red[3], 	TMDS_red[3], 	TMDS_red[2], 	TMDS_red[2], 	TMDS_red[1], 	TMDS_red[1],	TMDS_red[0], 	TMDS_red[0],
		TMDS_green[4], TMDS_green[4], TMDS_green[3], TMDS_green[3], TMDS_green[2], TMDS_green[2], TMDS_green[1], TMDS_green[1],	TMDS_green[0], TMDS_green[0],
		TMDS_blue[4], 	TMDS_blue[4], 	TMDS_blue[3], 	TMDS_blue[3], 	TMDS_blue[2], 	TMDS_blue[2], 	TMDS_blue[1], 	TMDS_blue[1],	TMDS_blue[0], 	TMDS_blue[0],
		10'h000	};
end

logic		[79:0]	wr_data_fifo;

HDMI_generator_fifo	HDMI_generator_fifo_inst (
	.wrclk 	( clk_i ),
	.wrreq 	( 1'b1 ),
	.data 	( wr_data_fifo ),

	.rdclk	( clk_i_fast ),
	.rdreq 	( 1'b1 ),
	.q 		( transceive_data )
);



endmodule


//Encoder 8b/10b

module TMDS_encoder(
	input 					clk,
	input 		[7:0] 	VD,  // video data (red, green or blue)
	input 		[1:0] 	CD,  // control data
	input 					VDE,  // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
	output logic [9:0] 	TMDS = 0
);

logic [3:0] Nb1s;
logic XNOR;
logic [8:0] q_m;
logic [3:0] balance_acc;
logic [3:0] balance, balance_acc_inc, balance_acc_new;
logic			balance_sign_eq, invert_q_m;
logic	[9:0]	TMDS_data, TMDS_code;

always_comb begin
	balance				= q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
	balance_sign_eq 	= (balance[3] == balance_acc[3]);
	invert_q_m 			= (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;
	balance_acc_inc 	= balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
	balance_acc_new 	= invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;
	TMDS_data 			= {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
	TMDS_code 			= CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : (CD[0] ? 10'b0010101011 : 10'b1101010100);
	q_m 					= {~XNOR, q_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};
	XNOR 					= (Nb1s>4'd4) || (Nb1s==4'd4 && VD[0]==1'b0);
	Nb1s 					= VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
end
	
	
always @(posedge clk) TMDS 			<= VDE ? TMDS_data : TMDS_code;
always @(posedge clk) balance_acc 	<= VDE ? balance_acc_new : 4'h0;
endmodule
