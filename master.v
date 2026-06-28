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
                    input HResp,
                    input [DataWidth-1 : 0] HRdata,
                    input HResetn,
                    input HClk,
                    output [AddressWidth-1 : 0] HAddr,
                    output [DataWidth-1 : 0] HWdata,
                    output HMastlock,
                    output HWrite,
                    output [$clog2(Size)-1 : 0] HSize,
                    output [$clog2(Burst)-1 : 0] HBurst,
                    output [$clog2(Transfer)-1 : 0] HTrans,
                    output [Prot-1 : 0] HProt
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
localparam BUSY         = 2'b01;
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
reg HMastlock_reg;
reg HWrite_reg;
reg [$clog2(Size)-1 : 0] HSize_reg;
reg [$clog2(Burst)-1 : 0] HBurst_reg;
reg [$clog2(Transfer)-1 : 0] HTrans_reg;
reg [Prot-1 : 0] HProt_reg;

// reg signals to be assigned to output
reg [AddressWidth-1 : 0] start_Address;
reg [DataWidth-1 : 0] HWdata_next;
reg HMastlock_next;
reg HWrite_next;
reg [$clog2(Size)-1 : 0] HSize_next;
reg [$clog2(Burst)-1 : 0] HBurst_next;
reg [$clog2(Transfer)-1 : 0] HTrans_next;
reg [Prot-1 : 0] HProt_next;

// local parameters for Master FSM states
localparam  idle = 0 , start = 1 , transfer = 2 , waitReady = 3 , done = 4;

// state register
reg [2:0] state , next_state;

// internal signals
reg [AddressWidth-1 : 0] Next_Address;  // next address to output in a burst
reg [7:0] DataSize;                     // to determine the size of data in bytes 
reg [4:0] beatSize;                     // to determine the no of clock cycles for transfer
reg [4:0] beat_count;                   // to count up to beatsize
reg [AddressWidth-1 : 0] Address_Bound; // while incrementing in incrN burst this is the limit
reg [AddressWidth-1 : 0] Wrap_Base;     // this is address to go when we reach wrap address in wrap burst
reg [AddressWidth-1 : 0] Wrap_Addr;     // once this address is reached we need to wrap to wrapbase
reg [6:0] wrapSize;                     // this tells the size in bytes of wrap
reg [1:0] BurstType;                   // tell if burst is wrap or incrn or incr or single


// State transition 
always@(*)begin
      case(state)
      idle          : next_state = ((HResp == 0) && (HReady))?  start : idle;
      start         : next_state = (HReady) ? transfer : waitReady;
      transfer      : next_state = (HReady) ? ((beat_count == (beatSize-1)) ? done : transfer ): waitReady;
      waitReady     : begin
                        if(HReady) begin
                              if(beat_count == 0)
                                    next_state = start;
                              else
                                    next_state = transfer;
                        end
                        else
                              next_state = waitReady;
                      end
      done          : next_state = idle;
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


// for HSize
always@(*)begin
      case(HSize_reg)
      BYTE                      : DataSize = 1;
      HALFWORD                  : DataSize = 2;
      WORD                      : DataSize = 4;
//      DOUBLEWORD                : DataSize = 8;
//      QUADWORD                  : DataSize = 16;
//      BYTE_256                  : DataSize = 32;
//      BYTE_512                  : DataSize = 64;
//      BYTE_1024                 : DataSize = 128;
      default                   : DataSize = 4;
      endcase
end
// for HBurst
always@(*)begin
      case(HBurst_reg)
      SINGLE                    : beatSize = 1;
      WRAP4                     : beatSize = 4;
      INCR4                     : beatSize = 4;
      WRAP8                     : beatSize = 8;
      INCR8                     : beatSize = 8;
      WRAP16                    : beatSize = 16;
      INCR16                    : beatSize = 16;
      default                   : beatSize = 1;
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
                  incr                      : begin
                                               /* if(HAddr_reg + DataSize >= Address_Bound)
                                                      Next_Address = HAddr_reg;
                                                else 
                                                    */  Next_Address = HAddr_reg + DataSize;
                                                end
                  default                   : Next_Address = HAddr_reg + DataSize;
            endcase 
end

// output assigning

always@(*)begin
      

    HTrans_next     = HTrans_reg;
    HBurst_next     = HBurst_reg;
    HSize_next      = HSize_reg;
    HWrite_next     = HWrite_reg;
    HWdata_next     = HWdata_reg;
    HMastlock_next  = HMastlock_reg;
    HProt_next      = HProt_reg;
    start_Address   = HAddr_reg;

            case(state)
            idle                          : HTrans_next = IDLE;
            start                         : begin
                                              HTrans_next = NONSEQ;
                                              HSize_next = BYTE;
                                              HBurst_next = SINGLE;
                                              HProt_next  = 4'b1100;
                                              HWrite_next = 1'b1;
                                              HWdata_next     = 32'h22;
                                              HMastlock_next  = 1'b0;
                                              start_Address      = 32'd4; 
            end
            transfer                      :  HTrans_next = SEQ;
            done                          :  HTrans_next = IDLE;
            waitReady                     :  begin
                                             HTrans_next     = HTrans_reg;
                                             HBurst_next     = HBurst_reg;
                                             HSize_next      = HSize_reg;
                                             HWrite_next     = HWrite_reg;
                                             HWdata_next     = HWdata_reg;
                                             HMastlock_next  = HMastlock_reg;
                                             HProt_next      = HProt_reg;                                            
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
            beat_count          <= 5'd0;
      end

      else begin
            state  <= next_state;
            case(state)
                  idle                : HTrans_reg <= HTrans_next ;
                  start               :     begin
                                              HTrans_reg <= HTrans_next;
                                              HSize_reg <= HSize_next;
                                              HBurst_reg <= HBurst_next; 
                                              HWrite_reg <= HWrite_next; 
                                              HWdata_reg <= HWdata_next;    
                                              HMastlock_reg <= HMastlock_next; 
                                              HAddr_reg     <= start_Address;
     //                                         Address_Bound <= HAddr_reg + beatSize*DataSize;
                                              beat_count <= 5'd0;
                                              wrapSize <= beatSize*DataSize;
                                              Wrap_Base <= start_Address & (~(beatSize*DataSize-1));
                                              Wrap_Addr <= (start_Address & (~(beatSize*DataSize-1))) + beatSize*DataSize;                                              
                  end
                  transfer            :     begin
                                              HTrans_reg <= HTrans_next;
                                              beat_count <= beat_count + 1;
                                              HAddr_reg  <= Next_Address;
                                              if(beat_count == beatSize)begin
                                                beat_count <= 0;
                                                HTrans_reg <= IDLE;
                                              end
                  end
                  done                :     HTrans_reg <= HTrans_next;
                  default             :    begin
                                            HTrans_reg <= HTrans_next;
                                            HSize_reg  <= HSize_next;
                                            HBurst_reg <= HBurst_next;
                                            HWrite_reg <= HWrite_next;
                                            HWdata_reg <= HWdata_next;
                                            HProt_reg <= HProt_next;
                                            HMastlock_reg <= HMastlock_next;
                  end
            endcase
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

endmodule






























































                        


            






































































