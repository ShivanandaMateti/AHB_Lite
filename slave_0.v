
module slave_0 #(   
                    parameter BaseAddr = 32'h0000_0000 ,
                    parameter Depth = 1024 ,
                    parameter DataWidth = 32,
                    parameter AddressWidth = 32,
                    parameter Size = 8,
                    parameter Burst = 8,
                    parameter Transfer = 4,
                    parameter Prot = 4
              )(
                    input HSel,
                    input [AddressWidth-1 : 0] HAddr,
                    input [DataWidth-1 : 0] HWdata,
                    input [$clog2(Size)-1 : 0] HSize,
                    input [$clog2(Burst)-1 : 0] HBurst,
                    input [$clog2(Transfer)-1 : 0] HTrans,
                    input [Prot-1 : 0] HProt,
                    input HReady,
                    input HMastlock,
                    input HResetn,
                    input HClk,
                    input HWrite,
                    output HReadyOut,
                    output HResp,
                    output [DataWidth-1 : 0] HRdata
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



// local parameters for HTrans
localparam IDLE         = 2'b00;
//      localparam BUSY         = 2'b01;
localparam NONSEQ       = 2'b10;
localparam SEQ          = 2'b11;

reg [7:0] DataSize;  // for HSize to show size of data in bytes



// To latch inputs 

reg HSelL;
reg [AddressWidth-1 : 0] HAddrL;
reg [$clog2(Size)-1 : 0] HSizeL;
reg [$clog2(Burst)-1 : 0] HBurstL;
reg [$clog2(Transfer)-1 : 0] HTransL;
reg [Prot-1 : 0] HProtL;
reg HReadyL;
reg HMastlockL;
reg HWriteL;

// local parameters
localparam  Byte_width = 8 ;
// Internal Memory 
reg [Byte_width - 1 : 0] mem[0 : Depth-1];

// Offset address
wire [DataWidth-1 : 0] offset = HAddrL - BaseAddr;



// internal signals
reg HResp_reg;
reg HReadyOut_reg;
reg [DataWidth-1 : 0] HRdata_reg;




// Latching address and control signals
always@(posedge HClk,negedge HResetn)begin
      if(!HResetn)begin
            HSelL      <= 1'b0;
            HAddrL     <= 32'd0;
            HSizeL     <= BYTE;
            HBurstL    <= 3'b000;
            HTransL    <= IDLE;
            HProtL     <= 4'b1100;
            HReadyL    <= 1'b1;
            HMastlockL <= 1'b0;
            HWriteL    <= 1'b0;
      end
      else if(HReady)begin
            HSelL            <= HSel;
            HAddrL           <= HAddr;
            HSizeL           <= HSize;
            HBurstL          <= HBurst;
            HTransL          <= HTrans;
            HProtL           <= HProt;
            HReadyL          <= HReady;
            HMastlockL       <= HMastlock;
            HWriteL          <= HWrite;     
      end
      
end

// for HSize
always@(*)begin
      case(HSizeL)
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

// to check whether the data is in given address range or not
wire addr_in_range = (offset < Depth) && ((offset + DataSize) <= Depth);

// to check if the address is misaigned or correct
wire misaligned = (DataSize > 1) && ((offset % DataSize) != 0);

// for a valid transfer
wire valid_transfer = (HSelL && HReadyL && ((HTransL==SEQ) | (HTransL==NONSEQ)));

// local parameters for the response FSM
localparam RESP_IDLE = 2'd0;
localparam RESP_READWAIT = 2'd1;
localparam RESP_ERR2 = 2'd2;

// Slave FSM

reg [1:0] state,next_state;
always@(*) begin
      next_state = state;
      case(state)
            RESP_IDLE: begin 
                  if(valid_transfer && (misaligned || !addr_in_range))
                        next_state = RESP_ERR2;
                  else if(valid_transfer && !HWriteL)
                        next_state = RESP_READWAIT;
                  else
                        next_state = RESP_IDLE;
            end

            RESP_READWAIT : next_state = RESP_IDLE;
            RESP_ERR2: next_state = RESP_IDLE;
            default:   next_state = RESP_IDLE;
      endcase
end

always@(posedge HClk, negedge HResetn) begin
      if(!HResetn)
            state <= RESP_IDLE;
      else
            state <= next_state;
end



// assigning outputs

always@(posedge HClk, negedge HResetn) begin
      if(!HResetn) begin
            HResp_reg     <= 1'b0;
            HReadyOut_reg <= 1'b1;
            HRdata_reg    <= {DataWidth{1'b0}};
      end
      else begin
            case(state)
                  RESP_IDLE: begin
                        if(valid_transfer && (misaligned || !addr_in_range)) begin
                              HResp_reg     <= 1'b1;
                              HReadyOut_reg <= 1'b0;
                        end
                        else if(valid_transfer && !HWriteL) begin
                              HResp_reg <= 1'b0;
                              HReadyOut_reg <= 1'b0;
                        end
                        else begin
                              HResp_reg     <= 1'b0;
                              HReadyOut_reg <= 1'b1;
                              if(HResetn && (state==RESP_IDLE))begin
                              case(HSizeL)
                              BYTE       :begin
                                          case(HAddrL[1:0])
                                          2'b00          :if(HWriteL) mem[HAddrL] <= HWdata[7:0] ; 
                                          2'b01          :if(HWriteL) mem[HAddrL] <= HWdata[15:8] ; 
                                          2'b10          :if(HWriteL) mem[HAddrL] <= HWdata[23:16] ; 
                                          2'b11          :if(HWriteL) mem[HAddrL] <= HWdata[31:24] ; 
                                          default        :if(HWriteL) mem[HAddrL] <= HWdata[7:0] ; 
                                          endcase
                              end
                              HALFWORD   :begin
                                          case(HAddrL[1])
                                          1'b0          : if(HWriteL) {mem[HAddrL+1],mem[HAddrL]} <= HWdata[15:0]; 
                                          1'b1          : if(HWriteL) {mem[HAddrL+1],mem[HAddrL]} <= HWdata[31:16];
                                          default       : if(HWriteL) {mem[HAddrL+1],mem[HAddrL]} <= HWdata[15:0]; 
                                          endcase    
                              end
                              default       :begin
                                                if(HWriteL)
                                                      {mem[HAddrL+3],mem[HAddrL+2],mem[HAddrL+1],mem[HAddrL]} <= HWdata;     
                              end
                              endcase
                              end

                        end
                  end
                  RESP_READWAIT : begin
                        HResp_reg <= 1'b0;
                        HReadyOut_reg <= 1'b1;
                        if(HResetn && (state == RESP_READWAIT))begin
                              case(HSizeL)
                              BYTE       :begin
                                          case(HAddrL[1:0])
                                          2'b00          : HRdata_reg  <= {24'd0,mem[HAddrL]};
                                          2'b01          : HRdata_reg  <= {16'd0,mem[HAddrL],8'd0};
                                          2'b10          : HRdata_reg  <= {8'd0,mem[HAddrL],16'd0};
                                          2'b11          : HRdata_reg  <= {mem[HAddrL],24'd0};
                                          default        : HRdata_reg  <= {24'd0,mem[HAddrL]};
                                          endcase
                              end
                              HALFWORD   :begin
                                          case(HAddrL[1])
                                          1'b0          : HRdata_reg <= {16'd0,mem[HAddrL+1],mem[HAddrL]};
                                          1'b1          : HRdata_reg <= {mem[HAddrL+1],mem[HAddrL],16'd0};
                                          default       : HRdata_reg <= {16'd0,mem[HAddrL+1],mem[HAddrL]};
                                          endcase    
                              end
                              default       :begin
                                          HRdata_reg <= {mem[HAddrL+3],mem[HAddrL+2],mem[HAddrL+1],mem[HAddrL]};
                              end
                              endcase
      end
                  end
                  RESP_ERR2: begin
                        HResp_reg     <= 1'b1;
                        HReadyOut_reg <= 1'b1;
                  end
                  default: begin
                        HResp_reg     <= 1'b0;
                        HReadyOut_reg <= 1'b1;
                  end
            endcase
      end
end






assign HResp = HResp_reg;
assign HReadyOut = HReadyOut_reg;
assign HRdata = HRdata_reg;


endmodule