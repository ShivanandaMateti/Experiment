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
wire [DataWidth-1 : 0] HRdata_out;


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
                .busy(busy),
                .HRdata_out(HRdata_out)
            );


// clock
initial HClk <= 1'b0;
always  #5  HClk <= ~HClk ;

// storage to store datawords
reg [DataWidth-1:0] dataStorage [0 : 127];

// for score board
integer pass_count = 0;
integer fail_count = 0;

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

// to do multiple transfers
// for write
task multiple_write_transfer;
input [4:0] noOfTransfers;
integer i;
            begin
                fork 
                    HWdata_req = dataStorage[0];
                    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
                    begin
                        for(i=1 ; ((i < noOfTransfers) && busy ); i = i+1)begin
                        @(HAddr);
                        HWdata_req = dataStorage[i];
                        $display(" %0h    %0h     %0b     %0b       %0b       %0b     %0b    %0b       %0h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
                        end
                    end
                    begin
                        do_transfer();
                    end
                join
            end
endtask

// for read
task multiple_read_transfer;
input [4:0] noOfTransfers;
integer i;
            begin
                fork 
                    begin
                        HRdata = dataStorage[0];
                        $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
                        for(i=1 ; ((i < noOfTransfers) && busy ); i = i+1)begin
                        @(HAddr);
                        HRdata = dataStorage[i];
                        $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
                        end
                    end
                    begin
                        do_transfer();
                    end
                join
            end
endtask

// to clear the storage
task clear_storage;
integer i;
begin
     for(i=0 ; i < 128 ; i = i+1)
        dataStorage [i] = 32'd0; 
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
    

    // test - 1 single write and read
    $display("Test-1 Single write and read a byte at even address");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0000;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd0;
    HProt_req = 4'b1100;
    HWdata_req = 32'h78;
    do_transfer();
    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
    HWrite_req = 1'b0;
    HRdata = 32'h78;
    do_transfer();
    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
    if(HRdata_out == 32'h78)begin
        $display("T-1 PASS !");
        pass_count = pass_count + 1;
    end 
    else begin
        $display("T-1 FAIL" );
        fail_count = fail_count + 1;
    end

    // test - 2 single write and read
    $display("Test-2 Single write and read a byte at odd address");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0001;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd0;
    HProt_req = 4'b1100;
    HWdata_req = 32'h87;
    do_transfer();
    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
    HWrite_req = 1'b0;
    HRdata = 32'h8700;
    do_transfer();
    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
    if(HRdata_out == 32'h8700)begin
        $display("T-2 PASS !");
        pass_count = pass_count + 1;
    end 
    else begin
        $display("T-2 FAIL !" );
        fail_count = fail_count + 1;
    end

    //  test - 3 wrap4 write and read

    $display("Test-3 wrap 4 write and read a word per beat");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0004;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd2;
    HBurst_req = 3'd2;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'haaaaaaaa;
    dataStorage[1] = 32'haaaaaaab;
    dataStorage[2] = 32'haaaaabcd;
    dataStorage[3] = 32'habcdabcd;
    multiple_write_transfer(4'd4);
    HWrite_req = 1'b0;
    multiple_read_transfer(4'd4);
    if(HRdata_out == dataStorage[3])begin
        $display("T-3 PASS !" );
        pass_count = pass_count + 1;
    end 
    else begin
        $display("T-3 FAIL !");
        fail_count = fail_count + 1;
    end

    //  test - 4 wrap8 write and read

    $display("Test-4 wrap 8 write and read halfword per beat ");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");
    HAddr_req = 32'h0000_0008;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd1;
    HBurst_req = 3'd4;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'hcade;
    dataStorage[1] = 32'hcade;
    dataStorage[2] = 32'habcd;
    dataStorage[3] = 32'habcd;
    dataStorage[4] = 32'hefef;
    dataStorage[5] = 32'hfefe;
    dataStorage[6] = 32'h3637;
    dataStorage[7] = 32'h3435;
    multiple_write_transfer(4'd8);
    dataStorage[0] = 32'hcade;
    dataStorage[1] = 32'hcade0000;
    dataStorage[2] = 32'habcd;
    dataStorage[3] = 32'habcd0000;
    dataStorage[4] = 32'hefef;
    dataStorage[5] = 32'hfefe0000;
    dataStorage[6] = 32'h3637;
    dataStorage[7] = 32'h34350000;
    HWrite_req = 1'b0;
    multiple_read_transfer(4'd8);
    if(HRdata_out == 32'h34350000)begin
        $display("T-4 PASS !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-4 FAIL !" );
        fail_count = fail_count + 1;
    end

    //  test - 5 wrap16 write and read
    $display("Test-4 wrap 16 write and read a byte per beat");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");
    HAddr_req = 32'h0000_0040;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd6;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'hcd;
    dataStorage[1] = 32'hef;
    dataStorage[2] = 32'h37;
    dataStorage[3] = 32'h33;
    dataStorage[4] = 32'h23;
    dataStorage[5] = 32'h32;
    dataStorage[6] = 32'h47;
    dataStorage[7] = 32'h67;
    dataStorage[8] = 32'hde;
    dataStorage[9] = 32'hbc;
    dataStorage[10] = 32'h9a;
    dataStorage[11] = 32'h78;
    dataStorage[12] = 32'h56;
    dataStorage[13] = 32'h34;
    dataStorage[14] = 32'h12;
    dataStorage[15] = 32'hde;
    multiple_write_transfer(5'd16);
    dataStorage[0] = 32'hcd;
    dataStorage[1] = 32'hef00;
    dataStorage[2] = 32'h370000;
    dataStorage[3] = 32'hde000000;
    dataStorage[4] = 32'h33;
    dataStorage[5] = 32'h2300;
    dataStorage[6] = 32'h320000;
    dataStorage[7] = 32'h47000000;
    dataStorage[8] = 32'h67;
    dataStorage[9] = 32'hde00;
    dataStorage[10] = 32'hbc0000;
    dataStorage[11] = 32'h9a000000;
    dataStorage[12] = 32'h78;
    dataStorage[13] = 32'h5600;
    dataStorage[14] = 32'h340000;
    dataStorage[15] = 32'h12000000;
    HWrite_req = 1'b0;
    multiple_read_transfer(5'd16);
    if(HRdata_out == dataStorage[15])begin
        $display("T-5 PASS !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-5 FAIL !" );
        fail_count = fail_count + 1;
    end

    // test - 6 incr4 write and read
    $display("Test-6 Incr 4 write and read a byte per beat");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0008;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd3;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'haa;
    dataStorage[1] = 32'hab;
    dataStorage[2] = 32'hcd;
    dataStorage[3] = 32'hde;
    multiple_write_transfer(4'd4);
    dataStorage[3] = 32'hde000000;
    HWrite_req = 1'b0;
    multiple_read_transfer(4'd4);
    if(HRdata_out == dataStorage[3])begin
        $display("T-6 PASS !" );
        pass_count = pass_count + 1;
    end 
    else begin
        $display("T-6 FAIL !");
        fail_count = fail_count + 1;
    end

    //  test - 7 incr8 write and read

    $display("Test-7 Incr 8 write and read a word per beat ");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");
    HAddr_req = 32'h0000_0008;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd2;
    HBurst_req = 3'd5;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'hcadecade;
    dataStorage[1] = 32'hefefcade;
    dataStorage[2] = 32'hcadeabcd;
    dataStorage[3] = 32'h1234abcd;
    dataStorage[4] = 32'hefef3456;
    dataStorage[5] = 32'hfefe7899;
    dataStorage[6] = 32'h36374657;
    dataStorage[7] = 32'h34353489;
    multiple_write_transfer(4'd8);
    HWrite_req = 1'b0;
    multiple_read_transfer(4'd8);
    if(HRdata_out == dataStorage[7])begin
        $display("T-7 PASS !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-7 FAIL !" );
        fail_count = fail_count + 1;
    end

    // test - 8 incr 16 write and read
    $display("Test-8 incr 16 write and read a halfword per beat");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");
    HAddr_req = 32'h0000_0040;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd1;
    HBurst_req = 3'd6;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'hcdef;
    dataStorage[1] = 32'hef23;
    dataStorage[2] = 32'h3747;
    dataStorage[3] = 32'h3356;
    dataStorage[4] = 32'h2378;
    dataStorage[5] = 32'h3299;
    dataStorage[6] = 32'h4700;
    dataStorage[7] = 32'h6745;
    dataStorage[8] = 32'hdeef;
    dataStorage[9] = 32'hbcca;
    dataStorage[10] = 32'h9ada;
    dataStorage[11] = 32'h78ac;
    dataStorage[12] = 32'h56ef;
    dataStorage[13] = 32'h3445;
    dataStorage[14] = 32'h1201;
    dataStorage[15] = 32'hde07;
    multiple_write_transfer(5'd16);
    dataStorage[0] = 32'hcdef;
    dataStorage[1] = 32'hef230000;
    dataStorage[2] = 32'h3747;
    dataStorage[3] = 32'h33560000;
    dataStorage[4] = 32'h2378;
    dataStorage[5] = 32'h32990000;
    dataStorage[6] = 32'h4700;
    dataStorage[7] = 32'h67450000;
    dataStorage[8] = 32'hdeef;
    dataStorage[9] = 32'hbcca0000;
    dataStorage[10] = 32'h9ada;
    dataStorage[11] = 32'h78ac0000;
    dataStorage[12] = 32'h56ef;
    dataStorage[13] = 32'h34450000;
    dataStorage[14] = 32'h1201;
    dataStorage[15] = 32'hde070000;
    HWrite_req = 1'b0;
    multiple_read_transfer(5'd16);
    if(HRdata_out == dataStorage[15])begin
        $display("T-8 PASS !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-8 FAIL !" );
        fail_count = fail_count + 1;
    end

    // test - 9 Undefined length incr
    $display("Test-9 Incr write and read a word per beat");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0012;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd2;
    HBurst_req = 3'd1;
    beats_req = 8'd5;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'hcadecade;
    dataStorage[1] = 32'hefefcade;
    dataStorage[2] = 32'hcadeabcd;
    dataStorage[3] = 32'h1234abcd;
    dataStorage[4] = 32'hefef3456;
    multiple_write_transfer(4'd5);
    HWrite_req = 1'b0;
    multiple_read_transfer(4'd5);
    if(HRdata_out == dataStorage[4])begin
        $display("T-9 PASS !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-9 FAIL !" );
        fail_count = fail_count + 1;
    end

    // test - 10 Midburst reset
    $display("Test-10 Midburst reset");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");
    fork
        begin
                    HAddr_req = 32'h0000_0004;
                    HWrite_req = 1'b1;
                    HMastlock_req = 1'b0;
                    HSize_req = 3'd2;
                    HBurst_req = 3'd2;
                    HProt_req = 4'b1100;
                    dataStorage[0] = 32'haaaaaaaa;
                    dataStorage[1] = 32'haaaaaaab;
                    dataStorage[2] = 32'haaaaabcd;
                    dataStorage[3] = 32'habcdabcd;
                    @(negedge HClk);
                    begins = 1;
                    @(posedge HClk);
                    begins = 0;
                    #70; 
        end
        begin
            #23; HResetn = 0; #42; HResetn = 1;
        end
    join
    if(~done)begin
        $display("T-10 PASS !");
        $display("done siganal is not asserted during reset !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-10 FAIL !" );
        fail_count = fail_count + 1;
    end

    // Test - 11 Reset recovery
    $display("Test-11 Reset recovery test !");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0003;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b0;
    HSize_req = 3'd0;
    HBurst_req = 3'd0;
    HProt_req = 4'b1100;
    HWdata_req = 32'h07;
    do_transfer();
    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
    HWrite_req = 1'b0;
    HRdata = 32'h070000;
    do_transfer();
    $display(" %0h    %h     %0b     %0b       %0b       %0b     %0b    %0b       %h ",HAddr,HWdata,HWrite,HSize,HBurst,HTrans,done,busy,HRdata_out);
    if(HRdata_out == 32'h070000)begin
        $display("T-11 PASS !");
        pass_count = pass_count + 1;
    end 
    else begin
        $display("T-11 FAIL !" );
        fail_count = fail_count + 1;
    end   

    

    // Test - 12 HMastlock Test
    $display("Test-12 HMastlock and undefined incr test");

    $display("HAddr  HWdata  HWrite  Hsize    HBurst    HTrans    done   busy  HRdata_out");

    HAddr_req = 32'h0000_0012;
    HWrite_req = 1'b1;
    HMastlock_req = 1'b1;
    HSize_req = 3'd2;
    HBurst_req = 3'd1;
    beats_req = 8'd5;
    HProt_req = 4'b1100;
    dataStorage[0] = 32'hcadecade;
    dataStorage[1] = 32'hefefcade;
    dataStorage[2] = 32'hcadeabcd;
    dataStorage[3] = 32'h1234abcd;
    dataStorage[4] = 32'hefef3456;
    multiple_write_transfer(4'd5);
    HWrite_req = 1'b0;
    multiple_read_transfer(4'd5);
    if((HRdata_out == dataStorage[4]) && (HTrans == 2'd0))begin
        $display("T-12 PASS !");
        pass_count = pass_count + 1;
    end
    else begin
        $display("T-12 FAIL !" );
        fail_count = fail_count + 1;
    end

    //-----------------------> RESULTS <---------------------------
    $display("The Test results are as follows : \n passcount = %0d \n failcount = %0d ",pass_count,fail_count);


    #2000000;
    $finish;
end


 
 // runtime error guard

initial begin
    #999999999;
    $display("Runtime error ! Simulation time exceeded");
    $finish;
end

endmodule


