module pipe_cpu (clock,resetn,if_ins,mem,pc,mem_wmem,mem_aluo,mem_data);
  input [31:0] if_ins,mem;                    //output pc and input instruction
  input clock,resetn;
  output [31:0] pc,mem_aluo,mem_data;
  output mem_wmem;


  wire [31:0]   bpc,npc,adr,ra,alua,alub,wb_res,alu_mem;
  //wire [3:0]    aluc;
  wire [4:0]    reg_dest,wn;
  wire [1:0]    pcsource;
  wire          zero,wmem,wreg,regrt,m2reg,shift,aluimm,jal,sext;//sext: 0(zero extentimme) 1(sign extentimme)
  wire          fd_able,dx_able,xm_able,mw_able,flush,alu_id_able,mem_id_able,mem_ex_able;

  wire ex_wmem,ex_wreg,ex_m2reg;
  wire    [4:0] ex_wn,ex_res;
  wire    [31:0] ex_aluo,ex_data,xm_data,ex_p4;

  wire [31:0]   if_ins,if_p4,id_ins,id_p4;

  wire        mem_jal,mem_wreg,mem_m2reg;
  wire        [31:0] mem_wn,mem_res,mem_p4,mem_aluo;
  wire         wb_wreg;
  wire        [31:0] wb_wn;
  wire        bubble;


  assign flush = pcsource[1] | pcsource[0];
  assign alu_id_able = ex_wreg & ~ex_m2reg;
  assign mem_id_able = mem_wreg;
  assign mem_ex_able = mem_wreg;
  bubblecontrol bc(id_ins[25:21],id_ins[20:16],ex_wn,ex_wreg,ex_m2reg,aluimm,bubble);

  assign fd_able = ~bubble;
  assign dx_able = ~bubble;
  assign xm_able = 1;
  assign mw_able = 1;


  dffe32 ip(npc,clock,resetn,~bubble,pc);  // define a D-register for PC


  assign if_p4 = pc + 32'h4; //pc+4

  latch_ifid lat_fd(resetn,clock,fd_able,flush,if_ins,if_p4,id_ins,id_p4);

  wire [31:0] jpc = {id_p4[31:28],id_ins[25:0],1'b0,1'b0};     // j address 
  wire [31:0]   sa = { 27'b0, id_ins[10:6] };      // extend to 32 bits from sa for shift id_insruction //shift amount
  wire e = sext & id_ins[15];             // positive or negative sign at sext signal
  wire [15:0]   imm = {16{e}};                     // high 16 sign bit
  wire [31:0]   immediate = {imm,id_ins[15:0]};    // sign extend to high 16 //!lui 是load upper immediate
  wire [31:0]   offset = {imm[13:0],id_ins[15:0],1'b0,1'b0};   //offset(include sign extend)
  assign adr = id_p4 + offset;     // modified
  mux4x32 nextpc(if_p4,adr,ra,jpc,pcsource,npc);   //jr 需要forwardinging特殊处理 ！注意！这里是ifp_p4
  wire id_wmem,id_wreg,id_regrt,id_m2reg,id_jal;
  wire [3:0]    id_aluc;
  wire [4:0]    id_wn;
  wire [31:0]   id_alua,id_alub,data,regs,regt,mem_fw;
  pipe_cu cu (id_ins[31:26],id_ins[5:0],zero,id_wmem,id_wreg,id_regrt,id_m2reg,
                      id_aluc,shift,aluimm,pcsource,id_jal,sext);//在ID段判断PC
  regfile rf (id_ins[25:21],id_ins[20:16],wb_res,wb_wn,wb_wreg,clock,resetn,regs,regt);

  forwarding_id     reg_id_s(regs,ex_aluo,mem_fw,ex_wn,mem_wn,id_ins[25:21],ra,alu_id_able,mem_id_able);
  forwarding_id     reg_id_t(regt,ex_aluo,mem_fw,ex_wn,mem_wn,id_ins[20:16],data,alu_id_able,mem_id_able);
  mux2x32 alu_b (data,immediate,aluimm,id_alub);  //在ID段
  mux2x32 alu_a (ra,sa,shift,id_alua);            //在ID段
  mux2x5 reg_wn (id_ins[15:11],id_ins[20:16],id_regrt,reg_dest);
  assign zero = ~|(id_alua-id_alub);
  assign id_wn = reg_dest | {5{id_jal}}; // jal: r31 <-- p4;      // 31 or reg_dest

  wire     [31:0]  ex_alua,ex_alub;
  wire     [3:0]   ex_aluc;
  latch_idex lat_dx(resetn,clock,dx_able,
                  id_wmem,id_wreg,id_regrt,id_m2reg,id_aluc,id_jal,
                  id_alua,id_alub,data,id_wn,id_ins[25:21],id_p4,
                  ex_wmem,ex_wreg,ex_regrt,ex_m2reg,ex_aluc,ex_jal,//regrt 大概没用上
                  ex_alua,ex_alub,ex_data,ex_wn,ex_res,ex_p4
                  );

  wire zr; //alu荒废的zero
  alu al_unit (ex_alua,ex_alub,ex_aluc,ex_aluo,zr);

  forwardingcontrol mem_ex (ex_data,mem,mem_wn,ex_res,xm_data,mem_ex_able);




  wire     mem_res_non; //暂时荒废的mem_res,ex_res是s寄存器的地址，后面mem_res是mem段写回的数据
  latch_exmem lat_xm(resetn,clock,xm_able,
              ex_wmem,ex_wreg,ex_m2reg,ex_jal,
              ex_wn,ex_aluo,ex_res,ex_p4,xm_data,           //ex_res:regester_s//暂时觉得保存ex_res没有用
              mem_wmem,mem_wreg,mem_m2reg,mem_jal,
              mem_wn,mem_aluo,mem_res_non,mem_p4,mem_data                  
              );


  mux2x32 result(mem_aluo,mem,mem_m2reg,alu_mem);
  mux2x32 link (alu_mem,mem_p4,mem_jal,mem_res);
  mux2x32 fw_mem (mem_aluo,mem,mem_m2reg,mem_fw);


  latch_memwb lat_mb(resetn,clock,xm_able,
              mem_wreg,mem_wn,mem_res,
              wb_wreg,wb_wn,wb_res
  );

endmodule

module forwardingcontrol (a0,a1,sorce,quire,y,enable);

   input [31:0] a0,a1;
   input [4:0] sorce,quire;
   input enable;
   output [31:0] y;
    wire s = enable & ~(|(sorce^quire));
   assign y = s ? a1 : a0;
   
endmodule

module forwarding_id (a0,a1,a2,sorce1,sorce2,quire,y,enable1,enable2);
    input [31:0] a0,a1,a2;
    input [4:0] sorce1,sorce2,quire;
    input enable1,enable2;
    output [31:0] y;
    reg    [31:0] y;
    always @(*)
    begin
        if(enable1&&sorce1==quire && quire!=0)
        begin
            y = a1;
        end
        else
        begin
            if(enable2&&sorce2==quire && quire!=0)
            begin
                y = a2;
            end
            else
            begin
                y = a0;
            end
        end 
    end
   
endmodule