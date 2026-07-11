module decoder #(
    parameter AddressWidth = 32,
    parameter NumSlaves = 3
)(
    input  [AddressWidth-1:0] HAddr,
    output [NumSlaves-1:0]    HSel,       // one per real slave
    output                    HSel_default
);

assign HSel[0] = (HAddr[31:10] == 22'h000);   // 0x000-0x3FF
assign HSel[1] = (HAddr[31:10] == 22'h001);   // 0x400-0x7FF
assign HSel[2] = (HAddr[31:10] == 22'h002);   // 0x800-0xBFF
assign HSel_default = ~(|HSel);

endmodule