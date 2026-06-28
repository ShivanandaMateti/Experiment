wire [AddressWidth-1 : 0] Address_Bound;
wire [AddressWidth-1 : 0] Next_Address;

assign Address_Bound = HAddrL + beatSize*DataSize;

reg [AddressWidth-1 : 0] Wrap_Base;
reg [AddressWidth-1 : 0] Wrap_Addr;
reg [5:0] beat_count;
reg [6:0] wrapSize;
case(HBurst)


INCR                : HAddrL        <= HAddrL + DataSize;

WRAP4               : begin
                        beatSize = 5'd4;
                        wrapSize = beatSize*DataSize;
                        Wrap_Base = (HAddrL & (~(wrapSize-1)));
                        Wrap_Addr = Wrap_Base + wrapSize;
                        if(beat_count < beatSize)begin
                              beat_count <= beat_count + 1;
                              if((Wrap_Addr - HAddrL)<= DataSize)
                                    HAddrL <= Wrap_Base;
                              else 
                                    HAddrL <= HAddrL + DataSize;
                        end
                        else
                              beat_count <= 0;
end



                        


            