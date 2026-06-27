`default_nettype 
`timescale 1ns/1ps

module slave_tb;

// parameters
parameter DataWidth = 32,
parameter AddressWidth = 32,
parameter Size = 8,
parameter Burst = 8,
parameter Transfer = 4,
parameter Prot = 4

// local parameters

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


// inputs
reg HSel;
reg [AddressWidth-1 : 0] HAddr;
reg [DataWidth-1 : 0] HWdata;
reg [$clog2(Size)-1 : 0] HSize;
reg [$clog2(Burst)-1 : 0] HBurst;
reg [$clog2(Transfer)-1 : 0] HTrans;
reg [Prot-1 : 0] HProt;
reg HReady;
reg HMastlock;
reg HResetn;
reg HClk;
reg HWrite;

// outputs
wire HReadyOut;
wire HResp;
wire [DataWidth-1 : 0] HRdata;

// Instantiation

slave              #(
                            .DataWidth(DataWidth),
                            .AddressWidth(AddressWidth),
                            .Size(Size),
                            .Burst(Burst),
                            .Transfer(Transfer),
                            .Prot(Prot)
                    )S_DUT (
                                .HSel(HSel),
                                .HAddr(HAddr),
                                .HWdata(HWdata),
                                .HSize(HSize),
                                .HBurst(HBurst),
                                .HTrans(HTrans),
                                .HProt(HProt),
                                .HReady(HReady),
                                .HMastlock(HMastlock),
                                .HResetn(HResetn),
                                .HClk(HClk),
                                .HWrite(HWrite),
                                .HReadyOut(HReadyOut),
                                .HResp(HResp),
                                .HRdata(HRdata)
                          );

// assigning clk
initial   HClk <= 1'b0;
always #5 HClk <= ~HClk;


// Test sequence

integer i = 0;

initial begin
    
    Hsize = WORD;
    HBurst = SINGLE;
    HTrans = NONSEQ;
    Hsel = 1;
    HReady = 1;
    HResetn = 1;
    


    // reset test
    HResetn = 0;
    $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);

    #200;
    // single write
    @(negedge HClk);
    HResetn = 1; #20;
    HAddr = 32'd0;
    HWdata = 32'h12345678;
    HWrite = 1; 
    #15;
    $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);


    #200;
    // single read
    @(negedge HClk);
    HAddr = 32'd0;
    HWrite = 0;
    #15;
    $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);

    
    // Invalid address
    @(negedge HClk);
    HAddr = 32'd2124;
    HWrite = 1;
    HWdata = 32'h22334455;
    #15;
    $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);

    // Continuous writes 
        @(negedge HClk);
        HAddr = 32'd4;
        HWdata = 32'd01;
        HWrite = 1;
        #15;
        $display("\nHResp : %0b , HReady : %0b ",HResp,HReadyOut);
        @(negedge HClk);
        HAddr = 32'd8;
        HWdata = 32'd11;
        HWrite = 1;
        #15;
        $display("\nHResp : %0b , HReady : %0b ",HResp,HReadyOut);
        @(negedge HClk);
        HAddr = 32'd12;
        HWdata = 32'd2231;
        HWrite = 1;
        #15;
        $display("\nHResp : %0b , HReady : %0b ",HResp,HReadyOut);

    // Continuous Memory Access
        @(negedge HClk);
        HAddr  = 32'd4;
        HWrite = 0;
        #15;
        $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);
        @(negedge HClk);
        HAddr  = 32'd8;
        HWrite = 0;
        #15;
        $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);
        @(negedge HClk);
        HAddr  = 32'd12;
        HWrite = 0;
        #15;
        $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);

$finish;

end

endmodule


