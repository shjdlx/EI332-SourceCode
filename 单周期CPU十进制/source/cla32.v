module cla32 (pc,x1,x2,p4); //sc_computer中并未有使用
   input [31:0] pc;
   input [31:0] x1;
   input [31:0] x2;
   output [31:0] p4;
   
   assign p4 = pc + 32'b100;   
   //assign adr = p4 + offset;
   
endmodule 

//cla32 pcplus4 (pc,32¡¯h4, 1¡¯b0,p4);
//cla32 br_adr (p4,offset,1¡¯b0,adr);