module  master   #(
                    parameter DataWidth = 32,
                    parameter AddressWidth = 32,
                    parameter Size = 8,
                    parameter Burst = 8,
                    parameter Transfer = 4,
                    parameter Prot = 4

                  )
                  (
                    input HReady,
                    input begins, // to start a transfer in the fsm  
                    input HResp,
                    input [DataWidth-1 : 0] HRdata,
                    input HResetn,
                    input HClk,
                    input [AddressWidth-1 : 0] HAddr_req,
                    input [DataWidth-1 : 0] HWdata_req,
                    input HMastlock_req,
                    input HWrite_req,
                    input [$clog2(Size)-1 : 0] HSize_req,
                    input [$clog2(Burst)-1 : 0] HBurst_req,
                    input [7:0] beats_req, // incase of HBurst = incr
                    input [Prot-1 : 0] HProt_req,                    
                    output [AddressWidth-1 : 0] HAddr,
                    output [DataWidth-1 : 0] HWdata,
                    output HMastlock,
                    output HWrite,
                    output [$clog2(Size)-1 : 0] HSize,
                    output [$clog2(Burst)-1 : 0] HBurst,
                    output [$clog2(Transfer)-1 : 0] HTrans,
                    output [Prot-1 : 0] HProt,
                    output done, // to know if the transfer is finished 
                    output busy,  // to know if the transfer is going on or not
                    output [DataWidth-1 : 0] HRdata_out // to verify the data read
                  );

// local parameters for HSize
localparam BYTE          = 3'b000;
localparam HALFWORD      = 3'b001;
localparam WORD          = 3'b010;
localparam DOUBLEWORD    = 3'b011;
localparam QUADWORD      = 3'b100;
localparam BYTE_256      = 3'b101;
localparam BYTE_512      = 3'b110;
localparam BYTE_1024     = 3'b111;

// Local parameters for HBurst
localparam SINGLE          = 3'b000;
localparam INCR            = 3'b001;
localparam WRAP4           = 3'b010;
localparam INCR4           = 3'b011;
localparam WRAP8           = 3'b100;
localparam INCR8           = 3'b101;
localparam WRAP16          = 3'b110;
localparam INCR16          = 3'b111;

// local parameters for HTrans
localparam IDLE         = 2'b00;
//      localparam BUSY         = 2'b01;
localparam NONSEQ       = 2'b10;
localparam SEQ          = 2'b11;

// local parameters for bursttype
localparam single       = 2'd0;
localparam incrn        = 2'd1;
localparam wrap         = 2'd2;
localparam incr         = 2'd3;


// reg signals to be mapped to outputs
reg [AddressWidth-1 : 0] HAddr_reg;
reg [DataWidth-1 : 0] HWdata_reg;
reg [DataWidth-1 : 0] HRdata_out_reg;
reg HMastlock_reg;
reg HWrite_reg;
reg [$clog2(Size)-1 : 0] HSize_reg;
reg [$clog2(Burst)-1 : 0] HBurst_reg;
reg [$clog2(Transfer)-1 : 0] HTrans_reg;
reg [Prot-1 : 0] HProt_reg;

// reg signals to be assigned to output
reg [AddressWidth-1 : 0] start_Address;
reg [DataWidth-1 : 0] HWdata_next;
reg [DataWidth-1 : 0] HRdata_out_next;
reg HMastlock_next;
reg HWrite_next;
reg [$clog2(Size)-1 : 0] HSize_next;
reg [$clog2(Burst)-1 : 0] HBurst_next;
reg [$clog2(Transfer)-1 : 0] HTrans_next;
reg [Prot-1 : 0] HProt_next;

// local parameters for Master FSM states
localparam  idle = 3'd0 , start = 3'd1 , transfer = 3'd2 , waitReady = 3'd3 , done_s = 3'd4 ,error_state = 3'd5,lock_idle = 3'd6;

// state register
reg [2:0] state , next_state;

// internal signals
reg [AddressWidth-1 : 0] Next_Address;  // next address to output in a burst
reg [7:0] DataSize_req;                     // to determine the size of data in bytes 
reg [7:0] beatSize_req;                     // to determine the no of clock cycles for transfer
reg [7:0] DataSize; 
reg [7:0] beatSize; 
reg [4:0] beat_count;                   // to count up to beatsize
reg [AddressWidth-1 : 0] Wrap_Base;     // this is address to go when we reach wrap address in wrap burst
reg [AddressWidth-1 : 0] Wrap_Addr;     // once this address is reached we need to wrap to wrapbase
reg [1:0] BurstType;                   // tell if burst is wrap or incrn or incr or single


// State transition 
always@(*)begin
      next_state = state;
      case(state)
      idle          : next_state = (begins) ? start : idle;
      start         :begin
                        if(!HReady)
                              next_state = waitReady;
                        else if(HResp)
                              next_state = error_state;
                        else
                              next_state = transfer;
      end         
      transfer      : begin
                        if(!HReady)
                              next_state = waitReady;
                        else if(HResp)
                              next_state = error_state;
                        else if(beat_count == (beatSize-1))
                              next_state = (HMastlock_reg)? lock_idle : done_s;
                        else
                              next_state = transfer;
      end
      waitReady     : begin
                        if(HReady) begin
                              if(HResp)
                                    next_state = error_state;
                              else if(beat_count == (beatSize-1))
                                    next_state = (HMastlock_req)? lock_idle : done_s;
                              else
                                    next_state = transfer;
                        end
                        else
                              next_state = waitReady;
                      end
      error_state   : next_state = done_s;
      lock_idle     : next_state = done_s;
      done_s        : next_state = idle;
      default       : next_state = idle;
      endcase
end


// // Address generator block

// shortlisting the burst type
always@(*)begin
      if((HBurst_reg == WRAP4) | (HBurst_reg == WRAP8) | (HBurst_reg == WRAP16))
            BurstType = wrap;
      else if((HBurst_reg == INCR4) | (HBurst_reg == INCR8) | (HBurst_reg == INCR16))
            BurstType = incr;
      else if(HBurst_reg == INCR)
            BurstType = incrn;
      else 
            BurstType = single;
end

// for calculating wrapbase, wrap_address
// for HSize
always@(*)begin
      case(HSize_req)
      BYTE                      : DataSize_req = 8'd1;
      HALFWORD                  : DataSize_req = 8'd2;
      WORD                      : DataSize_req = 8'd4;
      DOUBLEWORD                : DataSize_req = 8'd8;
      QUADWORD                  : DataSize_req = 8'd16;
      BYTE_256                  : DataSize_req = 8'd32;
      BYTE_512                  : DataSize_req = 8'd64;
      BYTE_1024                 : DataSize_req = 8'd128;
      default                   : DataSize_req = 8'd4;
      endcase
end
// for HBurst
always@(*)begin
      case(HBurst_req)
      SINGLE                    : beatSize_req = 7'd1;
      WRAP4                     : beatSize_req = 7'd4;
      INCR4                     : beatSize_req = 7'd4;
      WRAP8                     : beatSize_req = 7'd8;
      INCR8                     : beatSize_req = 7'd8;
      WRAP16                    : beatSize_req = 7'd16;
      INCR16                    : beatSize_req = 7'd16;
      default                   : beatSize_req = beats_req;
     endcase
end

// for Other uses
// for HSize
always@(*)begin
      case(HSize_reg)
      BYTE                      : DataSize = 8'd1;
      HALFWORD                  : DataSize = 8'd2;
      WORD                      : DataSize = 8'd4;
      DOUBLEWORD                : DataSize = 8'd8;
      QUADWORD                  : DataSize = 8'd16;
      BYTE_256                  : DataSize = 8'd32;
      BYTE_512                  : DataSize = 8'd64;
      BYTE_1024                 : DataSize = 8'd128;
      default                   : DataSize = 8'd4;
      endcase
end
// for HBurst
always@(*)begin
      case(HBurst_reg)
      SINGLE                    : beatSize = 7'd1;
      WRAP4                     : beatSize = 7'd4;
      INCR4                     : beatSize = 7'd4;
      WRAP8                     : beatSize = 7'd8;
      INCR8                     : beatSize = 7'd8;
      WRAP16                    : beatSize = 7'd16;
      INCR16                    : beatSize = 7'd16;
      default                   : beatSize = beats_req;
     endcase
end



// Address assigning

always@(*)begin
            case(BurstType)
                  single                    : Next_Address = HAddr_reg;
                  incrn                     : Next_Address = HAddr_reg + DataSize;
                  wrap                      :   begin
                                                if(HAddr_reg + DataSize >= Wrap_Addr)
                                                      Next_Address = Wrap_Base;
                                                else
                                                      Next_Address = HAddr_reg + DataSize;
                                                end
                  incr                      : Next_Address = HAddr_reg + DataSize;
                                                
                  default                   : Next_Address = HAddr_reg + DataSize;
            endcase 
end

// output assigning

always@(*)begin

            case(state)

            idle                          : HTrans_next = IDLE;
            start                         : begin
                                              HTrans_next = NONSEQ;
                                              HSize_next = HSize_req;
                                              HBurst_next = HBurst_req;
                                              HProt_next  = HProt_req;
                                              HWrite_next = HWrite_req;
                                              HMastlock_next  = HMastlock_req;
                                              start_Address      = HAddr_req; 
            end
            transfer                      :  begin
                                             HTrans_next = SEQ;
                                             if(HWrite_next)begin
                                             case(HSize_reg)
                                             BYTE           : begin
                                                                  case(HAddr_reg[1:0])
                                                                  2'b00          : HWdata_next = {24'd0,HWdata_req[7:0]};
                                                                  2'b01          : HWdata_next = {16'd0,HWdata_req[7:0],8'd0};
                                                                  2'b10          : HWdata_next = {8'd0,HWdata_req[7:0],16'd0};
                                                                  2'b11          : HWdata_next = {HWdata_req[7:0],24'd0};
                                                                  default        : HWdata_next = {24'd0,HWdata_req[7:0]};
                                                                  endcase
                                             end 
                                             HALFWORD       : begin
                                                                  case(HAddr_reg[1])
                                                                  1'b0           : HWdata_next = {16'd0,HWdata_req[15:0]};
                                                                  1'b1           : HWdata_next = {HWdata_req[15:0],16'd0};
                                                                  default        : HWdata_next = {16'd0,HWdata_req[15:0]};
                                                                  endcase
                                             end
                                             default        : HWdata_next = HWdata_req;
                                             endcase   
                                             end
                                             else
                                                HRdata_out_next = HRdata;
            end
            error_state                   :  HTrans_next = IDLE;
            lock_idle                     :  HTrans_next = IDLE;
            done_s                        :  HTrans_next = IDLE;
            waitReady                     :  begin
                                             HTrans_next     = HTrans_reg;
                                             HBurst_next     = HBurst_reg;
                                             HSize_next      = HSize_reg;
                                             HWrite_next     = HWrite_reg;
                                             HWdata_next     = HWdata_reg;
                                             HMastlock_next  = HMastlock_reg;
                                             HProt_next      = HProt_reg;                                            
            end
            default                       : begin
                                              HTrans_next     = HTrans_reg;
                                              HBurst_next     = HBurst_reg;
                                              HSize_next      = HSize_reg;
                                              HWrite_next     = HWrite_reg;
                                              HWdata_next     = HWdata_reg;
                                              HMastlock_next  = HMastlock_reg;
                                              HProt_next      = HProt_reg;
                                              start_Address   = HAddr_reg;
            end               
      endcase
end



// State assigning
always@(posedge HClk,negedge HResetn)begin
      if(!HResetn)begin
            HAddr_reg           <= 32'd0;
            HSize_reg           <= BYTE;
            HBurst_reg          <= SINGLE;
            HTrans_reg          <= IDLE;
            HProt_reg           <= 4'b1100;
            HMastlock_reg       <= 0;
            HWrite_reg          <= 1;
            state               <= idle;
            beat_count          <= 7'd0;
      end

      else begin
            state  <= next_state;
            if(HReady)begin
            HTrans_reg    <= HTrans_next;
            HSize_reg     <= HSize_next;
            HBurst_reg    <= HBurst_next; 
            HWrite_reg    <= HWrite_next;     
            HMastlock_reg <= HMastlock_next;
            case(state)
                  start               :     begin 
                                              HAddr_reg  <= start_Address;
                                              beat_count <= 7'd0;
                                              Wrap_Base <= start_Address & (~(beatSize_req*DataSize_req-1));
                                              Wrap_Addr <= (start_Address & (~(beatSize_req*DataSize_req-1))) + (beatSize_req*DataSize_req);                                              
                  end
                  transfer            :     begin
                                              HWdata_reg <= HWdata_next;
                                              HRdata_out_reg <= HRdata_out_next;
                                              beat_count <= beat_count + 1;
                                              HAddr_reg  <= Next_Address;
                                              if(beat_count == (beatSize-1))begin
                                                beat_count <= 0;
                                                HTrans_reg <= IDLE;
                                              end
                  end
                  default             : HMastlock_reg <= HMastlock_next;
            endcase
            end
      end
end
                   
// output assigning

assign HAddr = HAddr_reg;
assign HWdata = HWdata_reg;
assign HMastlock = HMastlock_reg;
assign HWrite = HWrite_reg;
assign HSize = HSize_reg;
assign HBurst = HBurst_reg;
assign HTrans = HTrans_reg;
assign HProt = HProt_reg;
assign done = (state == done_s);
assign busy = (state != idle);
assign HRdata_out = HRdata_out_reg; 

endmodule