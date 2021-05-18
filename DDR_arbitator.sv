module		DDR_arbitator
(
	input			logic				clk,
	input			logic				DDR_init_done, DDR_cal_success, DDR_calib_fail, DDR_ready,
	
	output		logic	[23:0]	addr,
	
	output		logic	[63:0]	wr_data,
	output		logic				wr_req,
	
	input			logic	[63:0]	rd_data,
	output		logic				rd_req,
	output		logic				burtsbegin,
	input			logic				rd_valid,
	
	input			logic				Start_write, Start_read,
	
	
	input			logic				DDR_arbiter_fifo_input_new_frame,
	input			logic				DDR_arbiter_fifo_input_wrclk,
	input			logic				DDR_arbiter_fifo_input_wrreq,
	input			logic	[7:0]		DDR_arbiter_fifo_input_wrdata,
	
	input			logic				DDR_arbiter_fifo_output_new_frame,
	input			logic				DDR_arbiter_fifo_output_rdclk,
	input			logic				DDR_arbiter_fifo_output_rdreq,
	output		logic	[7:0]		DDR_arbiter_fifo_output_rddata
);


logic						new_input_frame;

logic						new_output_frame;

logic		[3:0]			input_new_frame_buffer, output_new_frame_buffer;

assign	input_new_frame_buffer[0]	=	DDR_arbiter_fifo_input_new_frame;
assign	output_new_frame_buffer[0]	=	DDR_arbiter_fifo_output_new_frame;

always_ff @ ( posedge clk ) begin
	for ( int i = 1; i<= 3; i = i+1 ) begin
		input_new_frame_buffer[i]	<= input_new_frame_buffer[i-1];
		output_new_frame_buffer[i]	<= output_new_frame_buffer[i-1];
	end
	
	if ( ~new_input_frame )
		new_input_frame	<= input_new_frame_buffer[3] && ~input_new_frame_buffer[2];
	else
		new_input_frame	<= ~( state_mem == WAIT );

	if ( ~new_output_frame )
		new_output_frame	<= output_new_frame_buffer[3] && ~output_new_frame_buffer[2];
	else
		new_output_frame	<= ~( state_mem == WAIT );
		
end


initial begin
	state_mem	<= INIT;
	wr_addr_reg	<= '0;
	rd_addr_reg	<= '0;
end

enum	logic	[2:0]		{ INIT, WAIT, WRITE, READ, GET_READ_DATA } 	next_state_mem, state_mem;

logic		[23:0]		wr_addr_reg, rd_addr_reg;

logic		[3:0]			input_frames, output_frames;
logic		[19:0]		input_pix, output_pix, cnt_get_read;

assign	wr_addr_reg[23:0]		=	{ input_frames, input_pix};
assign	rd_addr_reg[23:0]		=	{ output_frames, output_pix};

always_ff @ ( posedge clk ) begin
	state_mem	<= next_state_mem;	
end	


logic	[63:0]	test_data;

always_comb begin
	case ( state_mem )
		// Waiting till the end of initial calibration
		INIT :					next_state_mem		= ( DDR_init_done && DDR_cal_success && ~DDR_calib_fail ) ? WAIT : INIT;
		// When input fifo is empty -> write this data to DDR;
		//	When output fifo is less than 640 pixels -> read data from DDR and write it to output FIFO
		WAIT : 					next_state_mem		= ( ~DDR_arbiter_fifo_input_rdempty ) 						?	WRITE	:
									( ~almost_full_output_fifo && rd_addr_reg[19:0] <= 38400 )	?	READ	:	WAIT;
		// When fifo is full enough or image is done -> WAIT
		READ : 					next_state_mem		= ( almost_full_output_fifo && cnt_get_read >= output_pix ) || ( cnt_get_read >= 38400 )	? 	WAIT : READ;
		// When fifo is empty -> WAIT
		WRITE :					next_state_mem		= ( DDR_arbiter_fifo_input_rdempty ) 		? 	WAIT	: WRITE;
		
	endcase
end

logic		almost_full_output_fifo;

assign	almost_full_output_fifo	=	( DDR_arbiter_fifo_output_wrusedw > 160 );


always_ff @ ( posedge clk ) begin
	
	case ( state_mem )
		INIT : begin
			
		end
		
		WAIT : begin		
			
			input_pix			<= ( new_input_frame ) ? '0 : input_pix;
			input_frames		<= ( new_input_frame ) ? input_frames + 1 : input_frames;
			
			output_pix			<= ( new_output_frame ) ? '0 : output_pix;
			output_frames		<= ( new_output_frame ) ? input_frames - 1 : output_frames;
			cnt_get_read		<= ( new_output_frame ) ? '0 : cnt_get_read;
			
			aclr_output_frame	<= ( new_output_frame );
			
			wr_req		<= 1'b0;
			rd_req		<= 1'b0;
			burtsbegin	<= 1'b0;
			
			DDR_arbiter_fifo_input_rdreq	<= 1'b0;
			
		end
		
		WRITE : begin
			
			if ( ~DDR_arbiter_fifo_input_rdempty ) begin
				if ( DDR_ready && ~DDR_arbiter_fifo_input_rdreq )
					DDR_arbiter_fifo_input_rdreq	<= 1'b1;
				else
					DDR_arbiter_fifo_input_rdreq	<= 1'b0;
			end
			else begin
				DDR_arbiter_fifo_input_rdreq	<= 1'b0;
			end
			
			input_pix	<= ( DDR_arbiter_fifo_input_rdreq ) ? input_pix + 1 : input_pix;
			
			addr			<= wr_addr_reg;
			
			wr_req		<= DDR_arbiter_fifo_input_rdreq;
			
		end
		
		READ : begin
			addr			<= rd_addr_reg;
			
			if ( ~rd_req ) begin
				if ( DDR_ready && ~almost_full_output_fifo ) begin
					output_pix		<= output_pix + 1'b1;
					rd_req			<= 1'b1;
					burtsbegin		<= 1'b1;
				end
			end
			else begin
				rd_req			<= 1'b0;
				burtsbegin		<= 1'b0;
			end
			
			cnt_get_read	<= ( rd_valid ) ? cnt_get_read + 1'b1 : cnt_get_read;
			
		end
		
	endcase
	
	DDR_arbiter_fifo_output_wrreq				<= rd_valid;
	DDR_arbiter_fifo_output_wrdata			<= rd_data;
end

logic					DDR_arbiter_fifo_input_rdreq;
logic					DDR_arbiter_fifo_input_rdempty;

DDR_arbiter_fifo_input DDR_arbiter_fifo_input_0 (
	.aclr			( DDR_arbiter_fifo_input_new_frame ),
	.wrclk		( DDR_arbiter_fifo_input_wrclk ),
	.wrreq		( DDR_arbiter_fifo_input_wrreq ),
	.data			( DDR_arbiter_fifo_input_wrdata ),


	.rdclk		( clk ),
	.rdreq		( DDR_arbiter_fifo_input_rdreq ),
	.rdempty		( DDR_arbiter_fifo_input_rdempty ),
	.q				( wr_data )

);

logic					aclr_output_frame;
logic					DDR_arbiter_fifo_output_wrreq;
logic	[63:0]		DDR_arbiter_fifo_output_wrdata;
logic	[7:0]			DDR_arbiter_fifo_output_wrusedw;

DDR_arbiter_fifo_output	DDR_arbiter_fifo_output_0 (
	.wrclk		( clk ),
	.wrreq		( DDR_arbiter_fifo_output_wrreq ),
	.data			( DDR_arbiter_fifo_output_wrdata ),
	.wrusedw		( DDR_arbiter_fifo_output_wrusedw ),
	
	.aclr			( aclr_output_frame ),
	.rdclk		( DDR_arbiter_fifo_output_rdclk ),
	.rdreq		( DDR_arbiter_fifo_output_rdreq ),
	.q				( DDR_arbiter_fifo_output_rddata )
	
);


endmodule
