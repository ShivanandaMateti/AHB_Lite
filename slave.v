
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
local parameter BYTE          = 3'b000;
local parameter HALFWORD      = 3'b001;
local parameter WORD          = 3'b010;
local parameter DOUBLEWORD    = 3'b011;
local parameter QUADWORD      = 3'b100;
local parameter BYTE_256      = 3'b101;
local parameter BYTE_512      = 3'b110;
local parameter BYTE_1024     = 3'b111;

// Local parameters for HBurst
local parameter SINGLE          = 3'b000;
local parameter INCR            = 3'b001;
local parameter WRAP4           = 3'b010;
local parameter INCR4           = 3'b011;
local parameter WRAP8           = 3'b100;
local parameter INCR8           = 3'b101;
local parameter WRAP16          = 3'b110;
local parameter INCR16          = 3'b111;

// local parameters for HTrans
local parameter IDLE         = 2'b00;
local parameter BUSY         = 2'b01;
local parameter NONSEQ       = 2'b10;
local parameter SEQ          = 2'b11;

// local parameters
localparam Depth = 1024;
localparam  Byte_width = 8 ;
// Internal Memory 
reg [Byte-1 : 0] mem[0 : Depth-1];

// internal signals
reg HResp_reg;
reg HReadyOut_reg;
reg [DataWidth-1 : 0] HRdata_reg;
wire valid_transfer;

always@(posedge HClk,negedge HResetn)begin
      if(~HResetn)begin
            HResp_reg     <= 1'b0;
            HReadyOut_reg <= 1'b1;
            HRdata_reg    <= {DataWidth{1'b0}};
      end
      else begin
            if(HAddr < Depth-4)begin
                  if(valid_transfer)begin
                        if(HWrite) begin
                              {mem[HAddr + 3],mem[HAddr + 2],mem[HAddr + 1],mem[HAddr]} <= HWdata;
                              HResp_reg <= 0;
                              HReadyOut_reg <= 1;
                        end
                        else begin
                              HRdata_reg  <= {mem[HAddr + 3],mem[HAddr + 2],mem[HAddr + 1],mem[HAddr]};
                              HResp_reg <= 0;
                              HReadyOut_reg <= 1;
                        end
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
assign valid_transfer = (HSel && HReady && (HTrans == NONSEQ) && (HBurst == SINGLE) && (HSize == WORD));

endmodule

            