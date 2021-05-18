module 	SILAR_generator 
#(parameter		TEST_IMAGE	=	0 )
(
	input			logic				clk_i,
	
	output		logic	[13:0]	data_o
);

localparam				VALID_PIX	=	640;
localparam				VALID_LINES	=	480;
localparam				ALL_PIX		=	1500;
localparam				ALL_LINES	=	500;
localparam				OFFSET		=	10;



logic	[$clog2(ALL_PIX):0]		cnt_pix;
logic	[$clog2(ALL_LINES):0]	cnt_line;

logic									Vsync, Hsync, Pixsync;

//	Pixel and line counters

always_ff @ ( posedge clk_i ) begin
	cnt_pix		<= ( cnt_pix < ALL_PIX - 1 ) ? cnt_pix + 1'b1 : '0;
	if ( cnt_pix == OFFSET )
		cnt_line <= ( cnt_line < ALL_LINES - 1 ) ? cnt_line + 1'b1 : '0;
	
end

//	Sync signals

always_comb begin
	Hsync		=	( cnt_pix < ALL_PIX - VALID_PIX*2 );
	Vsync		=	( cnt_line < ( ALL_LINES - VALID_LINES ) );
	Pixsync	=	( ~cnt_pix[0] );
end


logic									prev_Hsync, prev_Vsync;
logic				[7:0]				data_frame, data_line;
logic				[7:0]				data;

//	Testing data sequences (gradient)

always_ff @ ( posedge clk_i ) begin
	prev_Hsync	<= Hsync;
	prev_Vsync	<= Vsync;
	
	case ( TEST_IMAGE )
		0	: begin
			data_frame	<= ( ~prev_Vsync && Vsync ) ? data_frame + 1'b1 : data_frame;
			data_line	<= ( ~prev_Hsync && Hsync ) ? data_line + 1'b1 : ( ( Vsync ) ? '0 : data_line );
		end
		1	: begin
			data_frame	<= ( ~prev_Vsync && Vsync ) ? data_frame - 1'b1 : data_frame;
			data_line	<= ( ~prev_Hsync && Hsync ) ? data_line + 1'b1 : ( ( Vsync ) ? '0 : data_line );	
		end
		2	: begin
			data_frame	<=	( ~prev_Vsync && Vsync ) ? data_frame + 1'b1 : data_frame;
			data_line	<= '0;
		end
		3	: begin
			data_frame	<=	( ~prev_Vsync && Vsync ) ? data_frame - 1'b1 : data_frame;
			data_line	<= '0;
		end
		default : begin
			data_frame	<= '0;
			data_line	<= '0;
		end
	endcase

	if ( ~Hsync && ~Vsync )
		data	<=	( ~Pixsync ) ? data + 1'b1 : data;
	else
		data	<= data_frame + data_line;
end


// Assign output data

always_ff @ ( posedge clk_i ) begin
	data_o[13:12]	<= '0;
	data_o[11]		<= Vsync;
	data_o[10]		<=	Hsync;
	data_o[9]		<= Pixsync;
	data_o[8]		<= ( ~Pixsync ) ? ^{ 2'd0, data[7:2] } : ^{ data[1:0], 6'd0 };
	data_o[7:0]		<= ( ~Pixsync ) ?  { 2'd0, data[7:2] } :  { data[1:0], 6'd0 };
end

endmodule
