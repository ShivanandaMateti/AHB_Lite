`default_nettype none
`timescale 1ns/1ps

module master_tb;

// parameters to drive tb

parameter DataWidth = 32;
parameter AddressWidth = 32;
parameter Size = 8;
parameter Burst = 8;
parameter Transfer = 4;
parameter Prot = 4;

// inputs to dut
reg HReady;
reg begins; // to start a transfer in the fsm  
reg HResp;
reg [DataWidth-1 : 0] HRdata;
reg HResetn;
reg HClk;
reg [AddressWidth-1 : 0] HAddr_req;
reg [DataWidth-1 : 0] HWdata_req;
reg HMastlock_req;
reg HWrite_req;
reg [$clog2(Size)-1 : 0] HSize_req;
reg [$clog2(Burst)-1 : 0] HBurst_req;
reg [7:0] beats_req; // incase of HBurst = incr
reg [Prot-1 : 0] HProt_req; 

// outputs of dut
wire [AddressWidth-1 : 0] HAddr;
wire [DataWidth-1 : 0] HWdata;
wire HMastlock;
wire HWrite;
wire [$clog2(Size)-1 : 0] HSize;
wire [$clog2(Burst)-1 : 0] HBurst;
wire [$clog2(Transfer)-1 : 0] HTrans;
wire [Prot-1 : 0] HProt;
wire done; // to know if the transfer is finished 
wire busy;


// instantiation

master    #(
                .DataWidth(DataWidth),
                .AddressWidth(AddressWidth),
                .Size(Size),
                .Burst(Burst),
                .Transfer(Transfer),
                .Prot(Prot)
            ) M_DUT (
                .HReady(HReady),
                .begins(begins),
                .HResp(HResp),
                .HRdata(HRdata),
                .HResetn(HResetn),
                .HClk(HClk),
                .HAddr_req(HAddr_req),
                .HWdata_req(HWdata_req),
                .HMastlock_req(HMastlock_req),
                .HWrite_req(HWrite_req),
                .HSize_req(HSize_req),
                .HBurst_req(HBurst_req),
                .beats_req(beats_req),
                .HProt_req(HProt_req),
                .HAddr(HAddr),
                .HWdata(HWdata),
                .HMastlock(HMastlock),
                .HWrite(HWrite),
                .HSize(HSize),
                .HBurst(HBurst),
                .HTrans(HTrans),
                .HProt(HProt),
                .done(done),
                .busy(busy)
            );


// clock
initial HClk <= 1'b0;
always  #5  HClk <= ~HClk ;

// helper tasks

// to start a transfer
task do_transfer;
begin
  @(negedge HClk);
  begins = 1'b1;
  @(posedge HClk);
  begins = 1'b0;
  @(posedge done);   // wait for the transfer to actually complete
  @(posedge HClk);   // one more edge to land back in idle cleanly
end
endtask

initial begin
    // initializing the dut 
    HReady = 1'b1;
    begins = 1'b0;
    HResp  = 1'b0;
    beats_req = 0;
    HResetn = 1'b0; #20 HResetn = 1'b1;
    

    $dumpfile("master.vcd");
    $dumpvars(0,master_tb);
    
    $display("HAddr  HWdata  HMastlock  HWrite  Hsize    HBurst    HTrans    HProt    done   busy ");
    $monitor(" %0h    %h       %0b       %0b     %0b       %0b       %0b      %0b     %0b    %0b ",HAddr,HWdata,HMastlock,HWrite,HSize,HBurst,HTrans,HProt,done,busy);

    // test - 1 single write
    $display("Test-1 Single write");
    HAddr_req = 32'h0000_0000;
    HWrite_req = 1'b1;
    HWdata_req = 32'h78;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd0;
    HProt_req = 4'b1100;
    do_transfer();

    //  test - 2 wrap4 write

    $display("Test-2 wrap 4 write word per beat");
    HAddr_req = 32'h0000_0004;
    HWrite_req = 1'b1;
    HWdata_req = 32'haaaaaaaa;
    HMastlock_req = 1'b0;
    HSize_req = 3'd2;
    HBurst_req = 3'd2;
    HProt_req = 4'b1100;
    do_transfer();

    //  test - 3 wrap8 write

    $display("Test-3 wrap 8 write halfword per beat ");
    HAddr_req = 32'h0000_0008;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd1;
    HBurst_req = 3'd4;
    HProt_req = 4'b1100;
    fork begin
            @(negedge HClk);
            HWdata_req = 32'hcadecade;
            @(negedge HClk);
            HWdata_req = 32'habcdabcd;
            @(negedge HClk);
            HWdata_req = 32'hefefefef;
            @(negedge HClk);
            HWdata_req = 32'h34353637;
        end
        begin
        @(negedge HClk);
        do_transfer();
        end
    join

    //  test - 4 wrap16 write

    $display("Test-4 wrap 16 write byte per beat");
    HAddr_req = 32'h0000_0040;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd6;
    HProt_req = 4'b1100;
    fork begin
            @(negedge HClk);
            HWdata_req = 32'hde;
            @(negedge HClk);
            HWdata_req = 32'hcd;
            @(negedge HClk);
            HWdata_req = 32'hef;
            @(negedge HClk);
            HWdata_req = 32'h37;
            @(negedge HClk);
            HWdata_req = 32'h33;
            @(negedge HClk);
            HWdata_req = 32'h23;
            @(negedge HClk);
            HWdata_req = 32'h32;
            @(negedge HClk);
            HWdata_req = 32'h47;
            @(negedge HClk);
            HWdata_req = 32'h67;
            @(negedge HClk);
            HWdata_req = 32'hde;
            @(negedge HClk);
            HWdata_req = 32'hbc;
            @(negedge HClk);
            HWdata_req = 32'h9a;
            @(negedge HClk);
            HWdata_req = 32'h78;
            @(negedge HClk);
            HWdata_req = 32'h56;
            @(negedge HClk);
            HWdata_req = 32'h34;
            @(negedge HClk);
            HWdata_req = 32'h12;
        end
        begin
        @(negedge HClk);
        do_transfer();
        end
    join





    
    
    #2000000;
    $finish;
end

endmodule


