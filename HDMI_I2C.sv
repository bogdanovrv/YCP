//	Module using for enable TMDS171I	(TMDS RETIMER)

module	HDMI_I2C (
	input			logic					clk_i,
	
	inout			logic					SCL,
	inout			logic					SDA
);

localparam		CLOCK_DIVIDER						=	100;	// Divider from 40 MHz to 400 kHz
localparam		INIT_DELAY_START					=	50_000;
localparam		DEVICE_ADDRESS_WRITE				=	186;
localparam		DEVICE_ADDRESS_MISC_CONTROL	=	9;
localparam		DEVICE_DATA_MISC_CONTROL		=	22;

logic		[7:0]		cnt_clk;
logic					clk;

// Creating clock 400kHz
always_ff @( posedge clk_i ) begin
	cnt_clk		<= ( cnt_clk < (CLOCK_DIVIDER-1) ) ? cnt_clk + 1'b1 : '0;
	clk			<= ( cnt_clk == 0 ) ? ~clk : clk;
end


initial begin
	init_start	=	'0;
	words			= 	'd3;
end

logic		[15:0]	cnt_init_start;
logic					init_start;

//	Creating start impulse after INIT_DELAY_START time 50_000 = 125 ms
always_ff @ ( posedge clk ) begin
	cnt_init_start	<= ( cnt_init_start < INIT_DELAY_START ) ? cnt_init_start + 1'b1 : cnt_init_start;
	init_start		<= ( cnt_init_start == INIT_DELAY_START - 1 );
end

enum	logic[2:0]	{ WAIT, START, WORK, STOP } state_I2C, next_state_I2C;

logic		[7:0]			cnt_SCL, cnt_SDA;

logic		[7:0]			cnt_words;
logic		[7:0]			words;
logic		[2:0][7:0]	work_data;


always_ff @ ( posedge clk ) begin	
	state_I2C	<= next_state_I2C;
end

//	Conditions for transition of state_I2C
always_comb begin
	case ( state_I2C )
		WAIT		:	next_state_I2C	=	( init_start ) ? START : WAIT;
		
		START 	:	next_state_I2C	=	( ~SDA ) ? WORK	:	START;
		
		WORK 		: 	next_state_I2C	=	( cnt_SDA == 8 && cnt_SCL == 3 && cnt_words == words - 1 ) ? STOP	: WORK;
		
		STOP 		: 	next_state_I2C	=	( SCL ) ? WAIT	:	STOP;
	endcase
end

always_ff @ ( posedge clk ) begin
	case ( state_I2C )
		WAIT	: begin
			SDA					<= 'Z;
			SCL					<= 'Z;
			for ( int i = 7; i>= 0; i-- ) begin
				work_data[0][i]		<= DEVICE_ADDRESS_WRITE[7-i];
				work_data[1][i]		<=	DEVICE_ADDRESS_MISC_CONTROL[7-i];
				work_data[2][i]		<=	DEVICE_DATA_MISC_CONTROL[7-i];
			end
			
			cnt_words			<= '0;
			cnt_SDA				<= '0;
			cnt_SCL				<= '0;
		end
		
		START	: begin
			SDA		<=	'0;
			SCL		<= ( ~SDA ) ? '0 : 'Z;
		end
		
		WORK : begin
			cnt_SCL	<= ( cnt_SCL < 3 ) ? cnt_SCL + 1'd1 : '0;
			if ( cnt_SCL == 3 ) begin
				cnt_SDA		<=	( cnt_SDA < 8 ) 	? cnt_SDA + 1'd1 : '0;
				cnt_words	<= ( cnt_SDA == 8 ) 	? cnt_words + 1'd1 : cnt_words;
			end
			
			case ( cnt_SCL )
				0	:	SCL	<=	'0;
				1	:	SCL	<= 'Z;
				2	:	SCL	<= 'Z;
				3	:	SCL	<= '0;
			endcase
			
			if ( cnt_words < 8 )
				SDA	<=	( work_data[cnt_words][cnt_SDA] ) ? 'Z : '0;
			else
				SDA	<= 'Z;
		end

		STOP		: begin
			SCL	<= 'Z;
			SDA	<=	( SCL ) ? 'Z : '0;
		end
	endcase
end



endmodule
