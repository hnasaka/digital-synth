//Finite State Machine Based off 2.2 FSM

module controlDDS (
	input  logic Clk, 
	input  logic Reset,
	input logic [31:0] keycodes,
	input logic tick,
	input logic keyboardSelect,
	
	output logic lutValid,
	output logic pcm_valid,
	output logic wr_addrValid,
	output logic [9:0] wt_addr,
	output logic clearAccum
	
);

// Declare signals curr_state, next_state of type enum
// with enum values of s_start, s_count0, ..., s_done as the state values
// Note that the length implies a max of 8 states, so you will need to bump this up for 8-bits
	enum logic [3:0] {
		idle,
		start,
		note_i,
		accum,
		done
	} curr_state, next_state; 
	
	logic [1:0] noteNum;
	logic [1:0] noteNum_next;
	logic [7:0] currentKeycode;
	logic [23:0] currentTuningWord;
	
	logic [23:0] kb1tuningWord;
	logic [23:0] kb2tuningWord;
	
    kb2Pitch pitcher(
        .keycode(currentKeycode),
        .tuning_word(kb1tuningWord)
    );
    
    kb2Pitch2 pitcher2(
        .keycode(currentKeycode),
        .tuning_word(kb2tuningWord)
    );
    
    assign currentTuningWord = keyboardSelect ? kb1tuningWord : kb2tuningWord;
    
    logic [23:0] phase_acc[4];
    always_ff @(posedge Clk) begin
        if (Reset)begin
            for(integer i = 0; i < 4; i = i+1)
                phase_acc[i] <= '0;
        end
        else if (curr_state == note_i) phase_acc[noteNum] <= phase_acc[noteNum] + currentTuningWord;
    end
    
	always_comb
	begin
	// Assign outputs based on ‘state’
	    pcm_valid = '0;
	    wr_addrValid = '0;
	    noteNum_next = noteNum;
	    wt_addr = '0;
	    currentKeycode = '0;
	    lutValid = '0;
	    clearAccum = '0;
		unique case (curr_state) 
			idle: 
			begin
			end
            
			start: 
			begin
			     clearAccum = 'd1;
			     noteNum_next = 'd3;
			     
			end
			
			done:
			begin
			     pcm_valid = 'd1;
			end
			
			accum:
			begin
			     lutValid = 'd1; 
			     noteNum_next = noteNum - 1;  
			end
			
			note_i:
			begin
			     currentKeycode = keycodes[noteNum*8 +: 8];
			     wr_addrValid = '1;
			     wt_addr = phase_acc[noteNum][23:14];
			     
			end
			

			default: 
			begin 
			end
		endcase
	end

// Assign outputs based on state
	always_comb
	begin

		next_state  = curr_state;	//required because I haven't enumerated all possibilities below. Synthesis would infer latch without this
		unique case (curr_state) 
			idle:    
			begin
				if (tick) 
				begin
					next_state = start;
				end
			end
			
			start: next_state = note_i;
			
			note_i: next_state = accum;
			 
			
            
            accum:
            begin
               next_state = note_i;
               if(noteNum == '0) begin
                    next_state = done;
               end
               
            end
			

			done : next_state = idle;    
			
					
		endcase
	end



	//updates flip flop, current state is the only one
	always_ff @(posedge Clk)  
	begin
		if (Reset)
		begin
			curr_state <= idle;
			noteNum <= '0;
		end
		else 
		begin
		    
			curr_state <= next_state;
			noteNum <= noteNum_next;
			
		end
	end

endmodule
