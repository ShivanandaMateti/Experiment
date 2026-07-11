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
parameter BaseAddr = 32'h0000_0000 ;
parameter Depth = 1024;

// local parameters

// local parameters for HSize
localparam BYTE          = 3'b000;
localparam HALFWORD      = 3'b001;
localparam WORD          = 3'b010;
/*
localparam DOUBLEWORD    = 3'b011;
localparam QUADWORD      = 3'b100;
localparam BYTE_256      = 3'b101;
localparam BYTE_512      = 3'b110;
localparam BYTE_1024     = 3'b111;
*/



// local parameters for HTrans
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

slave_0              #(
                            .BaseAddr(BaseAddr),
                            .Depth(Depth),
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


// Score board
reg [7:0] ref_mem [0:Depth-1];
integer mem_head = 0;
integer mem_tail = 0;
integer pass_count = 0;
integer fail_count = 0;


// helper tasks

// to check if data is written correctly in memory or not 
task checkWrite;
    input [7:0] DataInMem;
    begin
        if(DataInMem == ref_mem[mem_head])begin
            $display("PASS ! DataWritten = %0h , DataInMem = %0h ",ref_mem[mem_head],DataInMem);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL ! DataWritten = %0h , DataInMem = %0h ",ref_mem[mem_head],DataInMem);
            fail_count = fail_count + 1;
        end
        mem_head = mem_head + 1;
    end
endtask

// to check if data read correctly from memory or not
task checkRead;
    input [DataWidth-1 : 0] DataRead;
    input [DataWidth-1 : 0] DataToCompare;
    begin
        if(DataRead == DataToCompare)begin
            $display("PASS ! DataRead = %0h , DataWritten = %0h ",DataRead,DataToCompare);
            pass_count = pass_count + 1;
        end
        else begin
            $display("FAIL ! DataRead = %0h , DataWritten = %0h ",DataRead,DataToCompare);
            fail_count = fail_count + 1;
        end
    end
endtask

// to keep a copy of data written in memory and compare for tests
task push_ref;
    input [7:0] write_data;
    begin
        ref_mem[mem_tail] = write_data;
        mem_tail = mem_tail + 1;
    end
endtask

// to clear ref memory if used too much

task clear_mem;
integer i;
begin
    mem_head = 0;
    mem_tail = 0;
    for(i=0 ; i < Depth ; i = i+1)
        ref_mem[i] = 0;
end
endtask

// Test sequence




initial begin
    
    // initializing the dut
    HSize = BYTE;
    HBurst = 3'b000;
    HTrans = NONSEQ;
    HProt = 4'b1100;
    HMastlock = 1'b0;
    HSel = 1;
    HReady = 1;
    HResetn = 1;

    $dumpfile("slave.vcd");
    $dumpvars(0,slave_tb);
    


    // Test-1 reset test 
    $display("Test-1 Reset test");
    HResetn = 0;
    #15;
    $display("HResp : %0b , HReadyOut : %0b , HRdata : %0h ",HResp,HReadyOut,HRdata);
    if((HReadyOut==1) & (HResp==0))begin
        $display("PASS !" );
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL!");
        fail_count = fail_count + 1;
    end

    #200;
    // test - 2 single write
    $display("\nTest-2 Single write a byte");
    @(negedge HClk);
    HResetn = 1; 
    #20;
    @(negedge HClk);
    HAddr = 32'd0;
    HWdata = 32'h78;
    push_ref(8'h78);
    HWrite = 1;
    #40;  // give some time to write
    checkWrite(S_DUT.mem[0]);
    #15;


    #200;
    // test - 3 single read
    $display("\nTest-3 Single read a byte");
    @(negedge HClk);
    HWrite = 0;
    #40;   // give some time to read
    checkRead(HRdata,32'h78);
    #15;

    
    // test-4 Invalid address
    $display("\nTest-4 Invalid Address");
    HSize = WORD;
    HWrite = 1;
    @(negedge HClk);
    HAddr = 32'd111111111;
    HWdata = 32'h12341234;

    @(posedge HClk);   // for address to be latched
    @(posedge HClk);   // for error cycle 1
    #1;
    $display("HResp : %0b , HReady : %0b  ",HResp,HReadyOut);
    if((HResp==1) && (HReadyOut == 0))begin
        $display("Pass ! Error Cycle 1 for invalid address ");
        pass_count = pass_count + 1;
    end
    else begin
        $display("TEST FAIlED !");
        fail_count = fail_count + 1;        
    end
    @(posedge HClk);   // for error cycle 2
    #1;
    $display("HResp : %0b , HReady : %0b  ",HResp,HReadyOut);
    if((HResp==1) && (HReadyOut == 1))begin
        $display("Pass ! Error Cycle 2 for invalid address ");
        pass_count = pass_count + 1;
    end
    else begin
        $display("TEST FAIlED !");
        fail_count = fail_count + 1;        
    end   

    if(~S_DUT.addr_in_range)begin
        $display("PASS ! Detected out of range address , addr_in_range = %0b ",S_DUT.addr_in_range );
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL ! didn't detect Detected out of range address , addr_in_range = %0b ",S_DUT.addr_in_range );
        fail_count = fail_count + 1;        
    end
    

    #100;

    // Test-5 Continuous writes of Halfwords
    $display("\nTest-5 Continuous writes of Halfwords");
    HSize = HALFWORD;
    clear_mem();
    // Continuous writes 
        @(negedge HClk);
        HAddr = 32'd2;
        HWrite = 1;
        @(negedge HClk);
        HWdata = 32'h12340000;
        push_ref(8'h34);push_ref(8'h12);
        #100;
        @(negedge HClk);
        HAddr = 32'd4;
        @(negedge HClk);
        HWdata = 32'h00005678;
        push_ref(8'h78);push_ref(8'h56);
        #100;
        @(negedge HClk);
        HAddr = 32'd6;
        @(negedge HClk);
        HWdata = 32'h22310000;
        push_ref(8'h31);push_ref(8'h22);
        #100;
        #120;
        checkWrite(S_DUT.mem[2]);checkWrite(S_DUT.mem[3]);checkWrite(S_DUT.mem[4]);checkWrite(S_DUT.mem[5]);checkWrite(S_DUT.mem[6]);checkWrite(S_DUT.mem[7]);
        #15;
        $display("HResp : %0b , HReady : %0b ",HResp,HReadyOut);



    // Test-6 Continuous reads of HalfWords
    $display("\nTest-6 Continuous reads of Halfwords");
    // Continuous Memory Access
        @(negedge HClk);
        HAddr  = 32'd2;
        HTrans = NONSEQ;
        HWrite = 0;
        #100;
        checkRead(HRdata, 32'h12340078);
        @(negedge HClk);
        HAddr  = 32'd4;
        #100;
        checkRead(HRdata, 32'h12345678);
        @(negedge HClk);
        HAddr = 32'd6;
        #100;
        checkRead(HRdata, 32'h22315678);
        #15;
        $display("HResp : %0b , HReady : %0b ",HResp,HReadyOut);
       

    #100;

    // Test-10 HSel deasserted 
    $display("\nTest-7 HSel deasserted ");
    @(negedge HClk);
    HSel = 0;
    HAddr = 32'h550;
    HSize = BYTE;
    HWrite = 1'b0;
    @(negedge HClk);
    HWdata = 32'h00ca0000;
    @(posedge HClk);
    $display("HResp : %0b , HReady : %0b ",HResp,HReadyOut);
    if((HResp==0) && (HReadyOut==1))begin
        $display("PASS ! Idle response when slave isn't selected ");
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL ! ");
        fail_count = fail_count + 1;
    end
    HSel = 1;
    #100;

    // Test-7 Address boundary case write
    $display("\nTest-8 Address boundary case write a word");
    @(negedge HClk);
    HAddr = 32'd1020;
    HTrans = NONSEQ;
    HSize = WORD;
    HWrite = 1;
    @(negedge HClk);
    HWdata = 32'h00abcdef;
    push_ref(8'hef);push_ref(8'hcd);push_ref(8'hab);push_ref(8'h00);
    #100;
    checkWrite(S_DUT.mem[1020]);checkWrite(S_DUT.mem[1021]);checkWrite(S_DUT.mem[1022]);checkWrite(S_DUT.mem[1023]);

    // Test-8 Address boundary case read
    $display("\nTest-9 Address boundary case read a word");
    @(negedge HClk);
    HWrite = 0;
    #100;
    checkRead(HRdata, 32'h00abcdef );

    #100;

    // Test-9 Misaligned Address for a Halfword
    $display("\nTest-10 Misaligned Address for a Halfword");
    @(negedge HClk);
    HAddr = 32'd5;
    HSize = HALFWORD;
    HWrite = 1'b1;
    HWdata = 32'hab12;
    @(posedge HClk); // wait one cycle for latched address to read
    @(posedge HClk);   // for error cycle 1
    #1;
    $display("HResp : %0b , HReady : %0b  ",HResp,HReadyOut);
    if((HResp==1) && (HReadyOut == 0))begin
        $display("Pass ! Error Cycle 1 for Misaligned Address ");
        pass_count = pass_count + 1;
    end
    else begin
        $display("TEST FAIlED !");
        fail_count = fail_count + 1;        
    end
    @(posedge HClk);   // for error cycle 2
    #1;
    $display("HResp : %0b , HReady : %0b  ",HResp,HReadyOut);
    if((HResp==1) && (HReadyOut == 1))begin
        $display("Pass ! Error Cycle 2 for Misaligned address ");
        pass_count = pass_count + 1;
    end
    else begin
        $display("TEST FAIlED !");
        fail_count = fail_count + 1;        
    end


    if(S_DUT.misaligned)begin
        $display("PASS ! Detected misaligned address , misaligned = %0b ",S_DUT.misaligned );
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL ! didn't detect misaligned address , misaligned = %0b ",S_DUT.misaligned );
        fail_count = fail_count + 1;        
    end

    #100;

    // Test-11 Waitstate test 
    $display("\nTest-11 WaitState test");
    fork
        begin
                @(negedge HClk);
                HAddr = 32'd1000;
                HTrans = NONSEQ;
                HSize = BYTE;
                HWrite = 1;
                @(negedge HClk);
                HWdata = 32'hde;
                push_ref(8'hde);
                #100;
                checkWrite(S_DUT.mem[1000]);
        end
        begin
            #4;
            @(negedge HClk);
            HReady = 0;
            repeat(3) @(posedge HClk);
            HReady = 1;
        end
    join

    if((S_DUT.HAddrL==32'd1000) && (S_DUT.HTransL==NONSEQ))begin
        $display("PASS ! Address and control signals are unchanged during wait states");
        $display("HAddL = %0h , HTrans = %0h ",S_DUT.HAddrL,S_DUT.HTransL);
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL ! ");
        fail_count = fail_count + 1;
    end


    // -------------------------> RESULTS <-------------------------------
    $display("Finished test Sequence !! \n The Results are !! \npasscount = %0d , failcount = %0d",pass_count,fail_count);



$finish;

end

// Runtime error guard

initial begin
    #1000000000;
    $display("Simulation time exceecded ! ");
    $finish;
end

endmodule