//Finite State Machine Based off 2.2 FSM

module controlDDS #(
    parameter voiceNum = 8
)
(
	input  logic Clk, 
	input  logic Reset,
	input logic [31:0] keycodes,
	input logic tick,
	input logic keyboardSelect,
	
	output logic lutValid,
	output logic pcm_valid,
	output logic wr_addrValid,
	output logic [9:0] wt_addr,
	output logic clearAccum,
	output logic [15:0] envelope,
	
	input logic [31:0] attack_step,
    input logic [31:0] decay_step,
    input logic [31:0] sustain_level,
    input logic [31:0] sustain_time,
    input logic [31:0] release_step
	
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
	
	logic [2:0] noteNum;
	logic [2:0] noteNum_next;
	logic [7:0] currentKeycode;
	logic [23:0] currentTuningWord;
	
	logic [23:0] kb1tuningWord;
	logic [23:0] kb2tuningWord;
    
//Keyboard ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    kb2Pitch pitcher(
        .keycode(currentKeycode),
        .tuning_word(kb1tuningWord)
    );
    
    kb2Pitch2 pitcher2(
        .keycode(currentKeycode),
        .tuning_word(kb2tuningWord)
    );
    
    assign currentTuningWord = keyboardSelect ? kb1tuningWord : kb2tuningWord;
    
    logic [23:0] phase_acc[voiceNum];
//    always_ff @(posedge Clk) begin
//        if (Reset)begin
//            for(integer i = 0; i < 4; i = i+1)
//                phase_acc[i] <= '0;
//        end
//        else if (curr_state == note_i) phase_acc[noteNum] <= phase_acc[noteNum] + currentTuningWord;
//    end
    logic clear_phase [voiceNum];  // one per voice slot
    
    // Voice manager sets clear_phase[i] when adsr_done
    // Phase accumulator block:
    always_ff @(posedge Clk) begin
        if (Reset) begin
            for (int i = 0; i < voiceNum; i++)
                phase_acc[i] <= '0;
        end else begin
            if (curr_state == note_i)
                phase_acc[noteNum] <= phase_acc[noteNum] + currentTuningWord;
            // Clear takes priority over accumulation
            for (int i = 0; i < voiceNum; i++)
                if (clear_phase[i])
                    phase_acc[i] <= '0;
        end
    end
    
//Voices ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
    logic [7:0] voices [voiceNum];
    logic voicePressed_r [voiceNum];
    logic voicePosedge [voiceNum];
    
    posedgeDetect voicesPosedge(
        .clk(Clk),
        .signal(voicePressed_r),
        .signalPosedge(voicePosedge)
    );
//ADSR~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
logic [15:0] adsrEnvelope [voiceNum];
logic adsr_done[voiceNum];
logic voicePressed[voiceNum];

genvar i;
generate
    for (i = 0; i < voiceNum; i = i+1)begin	
        adsr (
            .clk(Clk),
            .reset(Reset),
            .start(voicePosedge[i]),
            .pressing(voicePressed[i]),
            .envelope(adsrEnvelope[i]),
            .attack_step_value(attack_step),
            .decay_step_value(decay_step),
            .sustain_level(sustain_level),
            .sustain_time(sustain_step),
            .release_step_value(release_step),
            .adsr_idle(adsr_done[i])
            
        );
    end
endgenerate


//FSM~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
//    always_comb begin
//        for(int i = 0; i < 4; i = i+1)begin 
//            //Remove Logic
//            voices[i] = '0;
//            voicePressed[i] = '0;
//            if(voices[i] != keycodes[31:24] || voices[i] != keycodes[23:16] || voices[i] != keycodes[15:8] || voices[i] != keycodes[7:0])begin
//                voices[i] = '0;
//                voicePressed[i] = '0;
//            end else if(voices[i] != '0)begin
//                voicePressed[i] = '1;
//            end
//            //Add Logic
//            if(keycodes[i*8 +: 8] != voices[0] || keycodes[i*8 +: 8] != voices[1] || keycodes[i*8 +: 8] != voices[2] || keycodes[i*8 +: 8] != voices[3])begin
//                if(voices[0] == '0) begin
//                    voices[0] = keycodes[i*8 +:8];
//                    voicePressed[0] = '1;
//                end else if (voices[1] == '0) begin
//                    voices[1] = keycodes[i*8 +:8];
//                    voicePressed[1] = '1;
//                end else if (voices[2] == '0) begin
//                    voices[2] = keycodes[i*8 +:8];
//                    voicePressed[2] = '1;
//                end else if (voices[3] == '0) begin
//                    voices[3] = keycodes[i*8 +:8];
//                    voicePressed[3] = '1;
//                end
//            end
//        end
            
//    end

logic [7:0] voices_r [voiceNum];      // registered - persist after key release

always_ff @(posedge Clk) begin
    if (Reset) begin
        for (int i = 0; i < voiceNum; i++) begin
            voices_r[i]      <= '0;
            voicePressed_r[i] <= 1'b0;
        end
    end else begin
        // Update voice pressed state from keycodes
        for (int i = 0; i < voiceNum; i++) begin
            // Check if this voice's key is still in keycodes
            if (voices_r[i] != '0) begin
                if (voices_r[i] != keycodes[7:0]   &&
                    voices_r[i] != keycodes[15:8]  &&
                    voices_r[i] != keycodes[23:16] &&
                    voices_r[i] != keycodes[31:24]) begin
                    // Key released - mark not pressed but keep voice for release
                    voicePressed_r[i] <= 1'b0;
                    // Only clear voice when ADSR done
                    if (adsr_done[i])
                        voices_r[i] <= '0;
                        clear_phase[i] <= '1;
                end else begin
                    voicePressed_r[i] <= 1'b1;
                    clear_phase[i] <= '0;
                end
            end
        end
        // Assign new keycodes to empty voice slots
        // Find an empty slot for new keycodes - priority: slot 0 first
        for (int i = 0; i < 4; i++) begin
            logic [7:0] kc;
            kc = keycodes[i*8 +: 8];
            
            if (kc != '0 &&
                kc != voices_r[0] &&
                kc != voices_r[1] &&
                kc != voices_r[2] &&
                kc != voices_r[3] &&
                kc != voices_r[4] &&
                kc != voices_r[5] &&
                kc != voices_r[6] &&
                kc != voices_r[7]) begin
                // New key - assign to first empty slot found
                if      (voices_r[0] == '0) begin
                    voices_r[0]       <= kc;
                    voicePressed_r[0] <= 1'b1;
                end else if (voices_r[1] == '0) begin
                    voices_r[1]       <= kc;
                    voicePressed_r[1] <= 1'b1;
                end else if (voices_r[2] == '0) begin
                    voices_r[2]       <= kc;
                    voicePressed_r[2] <= 1'b1;
                end else if (voices_r[3] == '0) begin
                    voices_r[3]       <= kc;
                    voicePressed_r[3] <= 1'b1;
                end else if (voices_r[4] == '0) begin
                    voices_r[4]       <= kc;
                    voicePressed_r[4] <= 1'b1;
                end else if (voices_r[5] == '0) begin
                    voices_r[5]       <= kc;
                    voicePressed_r[5] <= 1'b1;
                end else if (voices_r[6] == '0) begin
                    voices_r[6]       <= kc;
                    voicePressed_r[6] <= 1'b1;
                end else if (voices_r[7] == '0) begin
                    voices_r[7]       <= kc;
                    voicePressed_r[7] <= 1'b1;
                end
            end
        end
    end
end
 
 //FSM~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
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
	    envelope = '0;
		unique case (curr_state) 
			idle: 
			begin
			end
            
			start: 
			begin
			     clearAccum = 'd1;
			     noteNum_next = 'd7;
			     
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
//			     currentKeycode = keycodes[noteNum*8 +: 8];
                 if(voices_r[noteNum] != '0) begin
                     currentKeycode = voices_r[noteNum];
                     wr_addrValid = '1;
                     wt_addr = phase_acc[noteNum][23:14];
                     envelope = adsrEnvelope[noteNum];
			     end
			     
			end
			

			default: 
			begin 
			end
		endcase
	end

//NEXT-STATE-LOGIC~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
