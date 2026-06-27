
module slave #(
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

// Variables

reg [4:0] beatSize;
reg [2:0] DataSize;

// To latch inputs 

reg HSelL;
reg [AddressWidth-1 : 0] HAddrL;
reg [DataWidth-1 : 0] HWdataL;
reg [$clog2(Size)-1 : 0] HSizeL;
reg [$clog2(Burst)-1 : 0] HBurstL;
reg [$clog2(Transfer)-1 : 0] HTransL;
reg [Prot-1 : 0] HProtL;
reg HReadyL;
reg HMastlockL;
reg HWriteL;

// local parameters
localparam Depth = 1024;
localparam  Byte_width = 8 ;
// Internal Memory 
reg [Byte_width - 1 : 0] mem[0 : Depth-1];

// internal signals
reg HResp_reg;
reg HReadyOut_reg;
reg [DataWidth-1 : 0] HRdata_reg;
wire valid_transfer;

// Latching address and control signals
always@(posedge HClk,negedge HResetn)begin
      if(!HResetn)begin
            HSelL            <= 0;
            HAddrL           <= HAddr;
            HSizeL           <= BYTE;
            HBurstL          <= SINGLE;
            HTransL          <= IDLE;
            HProtL           <= 4'b1100;
            HReadyL          <= 1;
            HMastlockL       <= 0;
            HWriteL          <= 1;
      end
      else begin
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

// integer cycles for counting the no of clk cycles
integer cycle = 1;

// using the latched inputs 

always@(posedge HClk,negedge HResetn)begin
      if(!HResetn)begin
            HResp_reg     <= 1'b0;
            HReadyOut_reg <= 1'b1;
            HRdata_reg    <= {DataWidth{1'b0}};
            beat_count    <= 5'd0;
      end
      else begin
            if(HAddrL < Depth)begin
                  if(valid_transfer)begin
                              case(HSizeL)
                              BYTE       :begin
                                          DataSize = 3'b1;
                                          (HWriteL) ? mem[HAddrL] <= HWdata[7:0] : HRdata <= mem[HAddrL]; 
                                          HResp_reg <= 0;
                              end
                              HALFWORD   :begin
                                          DataSize = 3'd2;
                                                if(HAddrL[0] == 0)begin
                                                      if(HWriteL)
                                                            {mem[HAddrL+1],mem[HAddrL]} <= HWdata[15:0];
                                                      else
                                                            HRdata[15:0]                <= {mem[HAddrL]+1,mem[HAddrL]};
                                                      HResp_reg <= 0;
                                                end
                                                else
                                                      HResp_reg <= 1;
                              end
                              WORD       :begin
                                          DataSize = 3'd4;
                                                if(HAddrL[1:0] == 2'b00)begin
                                                      if(HWriteL)
                                                            {mem[HAddrL+3],mem[HAddrL+2],mem[HAddrL+1],mem[HAddrL]} <= HWdata;     
                                                      else
                                                            HRdata   <= {mem[HAddrL+3],mem[HAddrL+2],mem[HAddrL+1],mem[HAddrL]};
                                                      HResp_reg <= 0;
                                                end
                                                else
                                                      HResp_reg <= 1;
                              end
                              endcase
                              HReadyOut_reg <= 1;
                  end
            end
            else begin
                  HResp_reg <= 1;
                  HReadyOut_reg <= 1;
            end
      end
end



assign HResp = HResp_reg;
assign HReadyOut = HReadyOut_reg;
assign HRdata = HRdata_reg;
assign valid_transfer = (HSelL && HReadyL && (HTransL == NONSEQ) && (HBurstL == SINGLE));

endmodule


