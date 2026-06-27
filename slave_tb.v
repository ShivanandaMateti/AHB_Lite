`default_nettype none
`timescale 1ns/1ps

module slave_tb;

// parameters
parameter DataWidth = 32;
parameter AddressWidth = 32;
parameter Size = 8;
parameter Burst = 8;
parameter Transfer = 4;
parameter Prot = 4;

// local parameters

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
localparam SINGLE           = 3'b000;
localparam INCR             = 3'b001;
localparam WRAP_4           = 3'b010;
localparam INCR_4           = 3'b011;
localparam WRAP_8           = 3'b100;
localparam INCR_8           = 3'b101;
localparam WRAP_16          = 3'b110;
localparam INCR_16          = 3'b111;

// local parameters for HTrans
localparam IDLE         = 2'b00;
localparam BUSY         = 2'b01;
localparam NONSEQ       = 2'b10;
localparam SEQ          = 2'b11;


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
    
    HSize = WORD;
    HBurst = SINGLE;
    HTrans = NONSEQ;
    HSel = 1;
    HReady = 1;
    HResetn = 1;

    $dumpfile("slave.vcd");
    $dumpvars(0,slave_tb);
    


    // reset test
    HResetn = 0;
    #15;
    $display("\nHResp : %0b , HReady : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);

    #200;
    // single write
    @(negedge HClk);
    HResetn = 1; #20;
    HAddr = 32'd0;
    HWdata = 32'h12345678;
    HWrite = 1; 
    #15;
    $display("\nHResp : %0b , HReady : %0b ",HResp,HReadyOut);


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
    $display("\nHResp : %0b , HReady : %0b  ",HResp,HReadyOut);

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


