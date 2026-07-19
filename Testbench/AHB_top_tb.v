`default_nettype none
`timescale 1ns/1ps

module AHB_top_tb;

// parameters

parameter DataWidth = 32;
parameter AddressWidth = 32;
parameter Size = 8;
parameter Burst = 8;
parameter Transfer = 4;
parameter Prot = 4;
parameter Depth = 1024 ;
parameter BaseAddr0 = 32'h0000_0000 ;
parameter BaseAddr1 = 32'h0000_0400 ;
parameter BaseAddr2 = 32'h0000_0800 ;
parameter NumSlaves = 3;

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



// inputs i.e reg that drive dut

reg HClk;
reg HResetn;
reg begins;
reg [AddressWidth-1 :0]HAddr_req;
reg [DataWidth-1 : 0] HWdata_req;
reg HMastlock_req;
reg HWrite_req;
reg [$clog2(Size)-1 : 0]HSize_req;
reg [$clog2(Burst)-1 : 0]HBurst_req;
reg [7:0] beats_req;
reg [Prot-1 : 0] HProt_req;

// outputs of the dut

wire done;
wire busy;
wire [DataWidth-1 : 0] HRdata_out;


// Instantiation

AHB_top      #(
    .DataWidth(DataWidth),
    .AddressWidth(AddressWidth),
    .Size(Size),
    .Burst(Burst),
    .Transfer(Transfer),
    .Prot(Prot),
    .Depth(Depth),
    .BaseAddr0(BaseAddr0),
    .BaseAddr1(BaseAddr1),
    .BaseAddr2(BaseAddr2),
    .NumSlaves(NumSlaves)

) AHB_dut (
    .HClk(HClk),
    .HResetn(HResetn),
    .begins(begins),
    .HAddr_req(HAddr_req),
    .HWdata_req(HWdata_req),
    .HMastlock_req(HMastlock_req),
    .HWrite_req(HWrite_req),
    .HSize_req(HSize_req),
    .HBurst_req(HBurst_req),
    .beats_req(beats_req),
    .HProt_req(HProt_req),
    .done(done),
    .busy(busy),
    .HRdata_out(HRdata_out)
);      


// CLk
initial HClk <= 1'b0;
always #5 HClk <= ~HClk;

// storage to store datawords
reg [DataWidth-1:0] dataStorage [0 : 127];

// for score board
integer pass_count = 0;
integer fail_count = 0;
integer i;

// helper tasks

// to start a transfer
task do_transfer;
begin
  @(negedge HClk);
  begins = 1'b1;
  @(posedge HClk);#1;
  begins = 1'b0;
  @(posedge done);   // wait for the transfer to actually complete
  @(posedge HClk);   // one more edge to land back in idle cleanly
end
endtask

// To write only once per beat
wire beat_done = AHB_dut.HReadyOut && ((AHB_dut.MASTER.state == 4'd2) || (AHB_dut.MASTER.state == 4'd3));

// to do multiple transfers
// for write
task multiple_write_transfer;
input [4:0] noOfTransfers;
integer i;
            begin
                HWdata_req = dataStorage[0];
                fork 
                    begin
                        @(posedge busy);
                        for(i=1 ; ((i < noOfTransfers) && busy ); i = i+1)begin
                           @(posedge beat_done);  
                            @(posedge HClk);#1;
                            HWdata_req = dataStorage[i];
                        end
                    end
                    begin
                        do_transfer();
                    end
                join
            end
endtask

// for read
task multiple_read_transfer_check;
input [4:0] noOfTransfers;
integer i;
begin
    fork
        begin
            @(posedge busy);
            for(i=0 ; ((i < noOfTransfers) && busy ); i = i+1)begin
                @(posedge beat_done);
                @(posedge HClk);
                @(posedge HClk);
                if(HRdata_out==dataStorage[i])begin
                    $display("%0dth transfer done successfully !  ",i+1);
                    $display("DataWritten : %0h , DataRead : %0h",dataStorage[i],HRdata_out);
                    pass_count = pass_count + 1;
                end
                else begin
                    $display("%0dth transfer failed !  ",i+1);
                    $display("DataWritten : %0h , DataRead : %0h",dataStorage[i],HRdata_out);
                    fail_count = fail_count + 1;
                end
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


// Main Test Sequence
initial begin
    // Initializing the Dut
    begins = 1'b0;
    HWrite_req = 1'b0;
    HMastlock_req = 1'b0;
    HProt_req = 4'b1100;
    beats_req = 0;
    HBurst_req = SINGLE;
    HSize_req = BYTE;
    HResetn = 1'b0;
    #300;
    HResetn = 1'b1;

    $dumpfile("AHB.vcd");
    $dumpvars(0,AHB_top_tb);

    

    // Test-1 Single write and read back a byte to slave_0
    $display("\nTest-1 Single write and read back a byte to slave_0 ");
    HAddr_req = 32'd0;
    HWrite_req = 1'b1;
    HWdata_req = 32'h11;
    do_transfer();
    #40;
    HWrite_req = 1'b0;
    do_transfer();
    #40;
    if(HRdata_out==32'h11)begin
        $display("PASS! DataWritten : %0h , DataRead : %0h",HWdata_req,HRdata_out);
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL! DataWritten : %0h , DataRead : %0h",HWdata_req,HRdata_out);
        fail_count = fail_count + 1;
        
    end

    // Test-2 Single write and read back a halfword to slave_1
    $display("\nTest-2 Single write and read back a halfword to slave_1 ");
    HAddr_req = 32'h0000_0404;
    HSize_req = HALFWORD;
    HWrite_req = 1'b1;
    HWdata_req = 32'h2222;
    do_transfer();
    #40;
    HWrite_req = 1'b0;
    do_transfer();
    #40;
    if(HRdata_out==32'h2222)begin
        $display("PASS! DataWritten : %0h , DataRead : %0h",HWdata_req,HRdata_out);
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL! DataWritten : %0h , DataRead : %0h",HWdata_req,HRdata_out);
        fail_count = fail_count + 1;
        
    end

    // Test-3 Single write and read back a byte to slave_2
    $display("\nTest-3 Single write and read back a word to slave_2 ");
    HAddr_req = 32'h0000_0808;
    HSize_req = WORD;
    HWrite_req = 1'b1;
    HWdata_req = 32'h33333333;
    do_transfer();
    #40;
    HWrite_req = 1'b0;
    do_transfer();
    #40;
    if(HRdata_out==32'h33333333)begin
        $display("PASS! DataWritten : %0h , DataRead : %0h",HWdata_req,HRdata_out);
        pass_count = pass_count + 1;
    end
    else begin
        $display("FAIL! DataWritten : %0h , DataRead : %0h",HWdata_req,HRdata_out);
        fail_count = fail_count + 1;
        
    end

#200;
// Test-4 Writing to an address out of range
    $display("\nTest-4 Writing to an address out of range ");
    HAddr_req = 32'h0001_0000;
    HWrite_req = 1'b1;
    HWdata_req = 32'h42424242;
    fork
        begin
            do_transfer();
        end
        begin
            #50;
             if(AHB_dut.mux.HSel_default)begin
                $display("PASS ! Detected out of range address. Default slave selected , HSel_default = %0b",AHB_dut.mux.HSel_default);
                pass_count = pass_count + 1;
             end
             else begin
                $display("Failed ! HResp = %0b HReady = %0b",AHB_dut.HRespOut,AHB_dut.HReadyOut );
                fail_count = fail_count + 1;
             end
        end
    join

    #400;

    // Test-5 back to back beats to 2 different slaves
    $display("\nTest-5 back to back beats to 2 different slaves" );
    // to slave 0 write
    $display("Writing a series of HALFWORDS to slave_0 using WRAP4 burst");
    HAddr_req = 32'h0000_0100;
    HSize_req = HALFWORD;
    HWrite_req = 1'b1;
    HBurst_req = WRAP4;
    dataStorage[0] = 32'h2432;
    dataStorage[1] = 32'h1234;
    dataStorage[2] = 32'h5678;
    dataStorage[3] = 32'h2134;
    multiple_write_transfer(4'd4);
    @(negedge HClk);
    while (busy) @(negedge HClk);
    

    // to slave 1 write
    $display("Writing a series of BYTES to slave_1 using INCR8 burst");
    HAddr_req = 32'h0000_0440;
    HSize_req = BYTE;
    HWrite_req = 1'b1;
    HBurst_req = INCR8;
    dataStorage[0] = 32'h45;
    dataStorage[1] = 32'h56;
    dataStorage[2] = 32'h12;
    dataStorage[3] = 32'h34;
    dataStorage[4] = 32'h56;
    dataStorage[5] = 32'h20;
    dataStorage[6] = 32'h67;
    dataStorage[7] = 32'h39;
    multiple_write_transfer(4'd8);
    @(negedge HClk);
    while (busy) @(negedge HClk);

    

    // to slave 0 read
    $display("Reading a series of HALFWORDS from slave_0 using WRAP4 burst");
    HAddr_req = 32'h0000_0100;
    HSize_req = HALFWORD;
    HWrite_req = 1'b0;
    HBurst_req = WRAP4;
    dataStorage[0] = 32'h2432;
    dataStorage[1] = 32'h12340000;
    dataStorage[2] = 32'h00005678;
    dataStorage[3] = 32'h21340000;
    multiple_read_transfer_check(4'd4);
    @(negedge HClk);
    while (busy) @(negedge HClk);



    // to slave 1 read
    $display("Reading a series of BYTES from slave_1 using INCR8 burst");
    HAddr_req = 32'h0000_0440;
    HSize_req = BYTE;
    HWrite_req = 1'b0;
    HBurst_req = INCR8;
    dataStorage[0] = 32'h45;
    dataStorage[1] = 32'h5600;
    dataStorage[2] = 32'h120000;
    dataStorage[3] = 32'h34000000;
    dataStorage[4] = 32'h56;
    dataStorage[5] = 32'h2000;
    dataStorage[6] = 32'h670000;
    dataStorage[7] = 32'h39000000;
    multiple_read_transfer_check(4'd8);
    @(negedge HClk);
    while (busy) @(negedge HClk);

   // Test-6 User required beats using incr burst
    $display("\nTest-6 User given beats using incr burst to slave_2" );
    $display("Writing a series of HALFWORDS to slave_2 using INCRN burst");
    HAddr_req = 32'h0000_0900;
    HSize_req = HALFWORD;
    HWrite_req = 1'b1;
    beats_req = 8'd6;
    dataStorage[0] = 32'haaaa;
    dataStorage[1] = 32'hbbbb;
    dataStorage[2] = 32'hcccc;
    dataStorage[3] = 32'hdddd;
    dataStorage[4] = 32'heeee;
    dataStorage[5] = 32'hffff;
    multiple_write_transfer(4'd6);
    @(negedge HClk);
    while (busy) @(negedge HClk);

    // to slave 2 read
    $display("Reading a series of HALFWORDS from slave_2 using INCRN burst");
    HAddr_req = 32'h0000_0900;
    HSize_req = HALFWORD;
    HWrite_req = 1'b0;
    beats_req = 8'd6;
    dataStorage[0] = 32'haaaa;
    dataStorage[1] = 32'hbbbb0000;
    dataStorage[2] = 32'hcccc;
    dataStorage[3] = 32'hdddd0000;
    dataStorage[4] = 32'heeee;
    dataStorage[5] = 32'hffff0000;
    multiple_read_transfer_check(4'd6);
    @(negedge HClk);
    while (busy) @(negedge HClk);
    
    // Test sequence 
    //--------------------------> RESULTS <-----------------------------
    $display("\nTESTING FINISHED !!!!");
    $display("\nTHE RESULTS ARE : \n PASSCOUNT = %0d \n FAILCOUNT = %0d ",pass_count,fail_count );

   

$finish;
    
end

// runtime error guard
initial begin
    #6000000;
    $display("Simulation time exceeded ! ");
    $finish;
end


endmodule
