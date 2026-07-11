module mux #(
                    parameter DataWidth = 32,
                    parameter NumSlaves = 3
            
            )(
                input HClk,
                input HResetn,
                input [NumSlaves-1:0]    HSel,       // one per real slave
                input                    HSel_default,
                input [DataWidth-1 : 0]  HRdata0,    // slave0
                input HResp0,
                input HReadyOut0,
                input [DataWidth-1 : 0]  HRdata1,   // slave1
                input HResp1,
                input HReadyOut1,
                input [DataWidth-1 : 0]  HRdata2,   // slave2
                input HResp2,
                input HReadyOut2,
                input [DataWidth-1 : 0]  HRdataD,   // default slave
                input HRespD,
                input HReadyOutD,
                output [DataWidth-1 : 0]  HRdataOut,   // outputs
                output HRespOut,
                output HReadyOut
                
            );


// to latch incoming signals and store them for one cycle
reg [NumSlaves-1 : 0] HSel_reg;
reg HSel_default_reg;


// reg signals to be mapped to outputs
reg [DataWidth-1 : 0]  HRdataOut_reg;  // outputs
reg HRespOut_reg;
reg HReadyOut_reg;


// storing the input signals

always@(posedge HClk,negedge HResetn)begin
    if(!HResetn)begin
        HSel_reg          <= {NumSlaves{1'b0}};
        HSel_default_reg  <= 1'b0;
    end
    else if(HReadyOut)begin
        HSel_reg          <= HSel;
        HSel_default_reg  <= HSel_default;
    end 
end



// mapping outputs

always@(*)begin
    if(HSel_default_reg)begin
        HRdataOut_reg = HRdataD;
        HRespOut_reg  = HRespD;
        HReadyOut_reg = HReadyOutD;
    end
    else begin
        case(HSel_reg)
        3'b001          : begin
                        HRdataOut_reg <= HRdata0;
                        HRespOut_reg  <= HResp0;
                        HReadyOut_reg <= HReadyOut0;
        end
        3'b010          : begin
                        HRdataOut_reg <= HRdata1;
                        HRespOut_reg  <= HResp1;
                        HReadyOut_reg <= HReadyOut1;
        end
        3'b100          : begin
                        HRdataOut_reg <= HRdata2;
                        HRespOut_reg  <= HResp2;
                        HReadyOut_reg <= HReadyOut2;
        end
        default         : begin
                        HRdataOut_reg <= HRdataD;
                        HRespOut_reg  <= HRespD;
                        HReadyOut_reg <= HReadyOutD;
        end
        endcase
    end
end

// assigning outputs

assign HRdataOut = HRdataOut_reg;
assign HRespOut = HRespOut_reg;
assign HReadyOut = HReadyOut_reg;


endmodule
