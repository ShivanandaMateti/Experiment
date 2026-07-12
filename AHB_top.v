module AHB_top  #(
                        parameter DataWidth = 32,
                        parameter AddressWidth = 32,
                        parameter Size = 8,
                        parameter Burst = 8,
                        parameter Transfer = 4,
                        parameter Prot = 4,
                        parameter Depth = 1024 ,
                        parameter BaseAddr0 = 32'h0000_0000 ,
                        parameter BaseAddr1 = 32'h0000_0400 ,
                        parameter BaseAddr2 = 32'h0000_0800 ,
                        parameter NumSlaves = 3

                )(
                        input HClk,
                        input HResetn,
                        input begins,
                        input [AddressWidth-1 :0]HAddr_req,
                        input [DataWidth-1 : 0] HWdata_req,
                        input HMastlock_req,
                        input HWrite_req,
                        input [$clog2(Size)-1 : 0]HSize_req,
                        input [$clog2(Burst)-1 : 0]HBurst_req,
                        input [7:0] beats_req,
                        input [Prot-1 : 0] HProt_req,
                        output done,
                        output busy,
                        output [DataWidth-1 : 0] HRdata_out
                );

wire HReadyOut;
wire HRespOut;
wire [DataWidth-1 : 0] HRdataOut;
wire [DataWidth-1 : 0] HWdata;
wire [AddressWidth-1 :0] HAddr;
wire HMastlock;
wire HWrite;
wire [$clog2(Size)-1 : 0] HSize;
wire [$clog2(Burst)-1 : 0] HBurst;
wire [$clog2(Transfer)-1 : 0] HTrans;
wire [Prot-1 : 0] HProt;
wire [NumSlaves-1 : 0] HSel;
wire HSel_default;
wire [DataWidth-1 : 0] HRdata0;
wire [DataWidth-1 : 0] HRdata1;
wire [DataWidth-1 : 0] HRdata2;
wire [DataWidth-1 : 0] HRdataD;
wire HResp0;
wire HResp1;
wire HResp2;
wire HRespD;
wire HReadyOut0;
wire HReadyOut1;
wire HReadyOut2;
wire HReadyOutD;

// master

master         #(
                .DataWidth(DataWidth),
                .AddressWidth(AddressWidth),
                .Size(Size),
                .Burst(Burst),
                .Transfer(Transfer),
                .Prot(Prot)

                )MASTER (
                .HReady(HReadyOut),
                .begins(begins),
                .HResp(HRespOut),
                .HRdata(HRdataOut),
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

// decoder

decoder         #(
                .AddressWidth(AddressWidth),
                .NumSlaves   (NumSlaves)
                ) decoder (
                            .HAddr       (HAddr),
                            .HSel        (HSel),
                            .HSel_default(HSel_default)
                          );

// mux

mux #(
    .DataWidth(DataWidth),
    .NumSlaves(NumSlaves)
 ) mux (
    .HClk        (HClk),
    .HResetn     (HResetn),
    .HSel        (HSel),
    .HSel_default(HSel_default),
    .HRdata0     (HRdata0),
    .HResp0      (HResp0),
    .HReadyOut0  (HReadyOut0),
    .HRdata1     (HRdata1),
    .HResp1      (HResp1),
    .HReadyOut1  (HReadyOut1),
    .HRdata2     (HRdata2),
    .HResp2      (HResp2),
    .HReadyOut2  (HReadyOut2),
    .HRdataD     (HRdataD),
    .HRespD      (HRespD),
    .HReadyOutD  (HReadyOutD),
    .HRdataOut   (HRdataOut),
    .HRespOut    (HRespOut),
    .HReadyOut   (HReadyOut)
);

// slave_0

slave_0 #(
    .BaseAddr(BaseAddr0),
    .Depth(Depth),
    .DataWidth(DataWidth),
    .AddressWidth(AddressWidth),
    .Size(Size),
    .Burst(Burst),
    .Transfer(Transfer),
    .Prot(Prot)
)slave_0 (
    .HSel(HSel[0]),
    .HAddr(HAddr),
    .HWdata(HWdata),
    .HSize(HSize),
    .HBurst(HBurst),
    .HTrans(HTrans),
    .HProt(HProt),
    .HReady(HReadyOut),
    .HMastlock(HMastlock),
    .HResetn(HResetn),
    .HClk(HClk),
    .HWrite(HWrite),
    .HReadyOut(HReadyOut0),
    .HResp(HResp0),
    .HRdata(HRdata0)
);

// slave_1

slave_1 #(
    .BaseAddr    (BaseAddr1),
    .Depth       (Depth),
    .DataWidth   (DataWidth),
    .AddressWidth(AddressWidth),
    .Size        (Size),
    .Burst       (Burst),
    .Transfer    (Transfer),
    .Prot        (Prot )
 ) slave_1 (
    .HSel     (HSel[1]),
    .HAddr    (HAddr),
    .HWdata   (HWdata),
    .HSize    (HSize),
    .HBurst   (HBurst),
    .HTrans   (HTrans),
    .HProt    (HProt),
    .HReady   (HReadyOut),
    .HMastlock(HMastlock),
    .HResetn  (HResetn),
    .HClk     (HClk),
    .HWrite   (HWrite),
    .HReadyOut(HReadyOut1),
    .HResp    (HResp1),
    .HRdata   (HRdata1)
);

// slave_2

slave_2 #(
    .BaseAddr    (BaseAddr2 ),
    .Depth       (Depth),
    .DataWidth   (DataWidth),
    .AddressWidth(AddressWidth),
    .Size        (Size),
    .Burst       (Burst),
    .Transfer    (Transfer),
    .Prot        (Prot)
 ) slave_2 (
    .HSel     (HSel[2]),
    .HAddr    (HAddr),
    .HWdata   (HWdata),
    .HSize    (HSize),
    .HBurst   (HBurst),
    .HTrans   (HTrans),
    .HProt    (HProt),
    .HReady   (HReadyOut),
    .HMastlock(HMastlock),
    .HResetn  (HResetn),
    .HClk     (HClk),
    .HWrite   (HWrite),
    .HReadyOut(HReadyOut2),
    .HResp    (HResp2),
    .HRdata   (HRdata2)
);

// default_slave

default_slave #(
    .Transfer (Transfer),
    .DataWidth(DataWidth)
 ) default_slave (
    .HSel     (HSel_default),
    .HTrans   (HTrans),
    .HReady   (HReadyOut),
    .HResetn  (HResetn),
    .HClk     (HClk),
    .HReadyOut(HReadyOutD),
    .HResp    (HRespD),
    .HRdata   (HRdataD)
);



endmodule