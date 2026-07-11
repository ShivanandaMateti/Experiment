
module default_slave #(   
                    parameter Transfer = 4,
                    parameter DataWidth = 32
              )(
                    input HSel,
                    input [$clog2(Transfer)-1 : 0] HTrans,
                    input HReady,
                    input HResetn,
                    input HClk,
                    output HReadyOut,
                    output HResp,
                    output [DataWidth-1 : 0] HRdata
              );

// local parameters for HTrans
localparam IDLE         = 2'b00;
localparam BUSY         = 2'b01;
localparam NONSEQ       = 2'b10;
localparam SEQ          = 2'b11;

// To latch inputs 
reg HSelL;
reg [$clog2(Transfer)-1 : 0] HTransL;
reg HReadyL;

// internal signals
reg HResp_reg;
reg HReadyOut_reg;
reg [DataWidth-1 : 0] HRdata_reg;

// Latching address and control signals
always@(posedge HClk,negedge HResetn)begin
      if(!HResetn)begin
            HSelL      <= 1'b0;
            HTransL    <= IDLE;
            HReadyL    <= 1'b1;
      end
      else if(HReady)begin
            HSelL            <= HSel;
            HTransL          <= HTrans;
            HReadyL          <= HReady;    
      end
      
end

// for a valid transfer
wire valid_transfer = (HSelL && HReadyL && ((HTransL==NONSEQ) | (HTransL==SEQ)));

// local parameters for the response FSM
localparam RESP_IDLE = 1'd0;
localparam RESP_ERR2 = 1'd1;

// Slave FSM

reg state,next_state;
always@(*) begin
      next_state = state;
      case(state)
            RESP_IDLE: next_state = (valid_transfer)
                                          ?  RESP_ERR2 : RESP_IDLE;
            RESP_ERR2: next_state = RESP_IDLE;
            default:   next_state = RESP_IDLE;
      endcase
end

always@(posedge HClk, negedge HResetn) begin
      if(!HResetn)
            state <= RESP_IDLE;
      else
            state <= next_state;
end



// assigning outputs

always@(posedge HClk, negedge HResetn) begin
      if(!HResetn) begin
            HResp_reg     <= 1'b0;
            HReadyOut_reg <= 1'b1;
      end
      else begin
            case(state)
                  RESP_IDLE: begin
                        if(valid_transfer) begin
                              HResp_reg     <= 1'b1;
                              HReadyOut_reg <= 1'b0;
                        end
                        else begin
                              HResp_reg     <= 1'b0;
                              HReadyOut_reg <= 1'b1;
                        end
                  end
                  RESP_ERR2: begin
                        HResp_reg     <= 1'b1;
                        HReadyOut_reg <= 1'b1;
                  end
                  default: begin
                        HResp_reg     <= 1'b0;
                        HReadyOut_reg <= 1'b1;
                  end
            endcase
      end
      HRdata_reg <= 32'd0;
end

// output assigning

assign HResp = HResp_reg;
assign HReadyOut = HReadyOut_reg;
assign HRdata = HRdata_reg;


endmodule