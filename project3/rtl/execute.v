// alu, branch/jump update
// DOES choose between immediate and register 2
module execute(
    input wire [31:0] reg1,
    input wire [31:0] reg2,
    input wire [31:0] imm,
    input wire [2:0] i_opsel,
    input wire i_sub,
    input wire i_unsigned,
    input wire i_arith,
    input wire [31:0] i_PC,
    input wire [31:0] i_PC4,
    output wire [31:0] o_result,
    output wire o_eq,
    output wire o_slt,
    output wire [31:0] target_addr,
    output wire [31:0] o_PC4,
    output wire o_unsigned, // for memory
    output wire o_mask, // for memory
    output wire [31:0] mem_addr, // for memory; different from o_result if not working with a word
    input wire i_ALUSrc,
    input wire i_Jump,
    input wire i_BranchEqual,
    input wire i_BranchLT,
    input wire i_MemRead,
    input wire i_MemtoReg,
    input wire i_MemWrite,
    input wire [4:0] i_rd_waddr,
    input wire i_RegWrite,
    input wire i_UpperType,
    input wire i_IsUInstruct,
    output wire o_Jump,
    output wire o_BranchEqual,
    output wire o_BranchLT,
    output wire o_MemRead,
    output wire o_MemtoReg,
    output wire o_MemWrite,
    output wire [4:0] o_rd_waddr,
    output wire o_RegWrite,
    output wire o_IsUInstruct,
    output wire [31:0] o_uimm
);

    // ALU
    wire i_op1, i_op2;
    assign i_op1 = reg1;
    assign i_op2 = i_ALUSrc ? imm : reg2;
    alu op (i_opsel, i_sub, i_unsigned, i_arith, i_op1, i_op2, o_result, o_eq, o_slt);

    // branch or jump target address
    assign target_addr = i_PC + imm;

    // U-type immediate
    assign o_uimm = i_UpperType ? imm + i_PC : imm;

    // mask decoder
    assign o_unsigned = i_opsel[2];
    assign o_mask = (i_opsel[1:0] == 2'b00) ? (
                        (o_result[1:0] == 2'b00) ? 4'b0001 :
                        (o_result[1:0] == 2'b01) ? 4'b0010 :
                        (o_result[1:0] == 2'b10) ? 4'b0100 :
                        4'b1000
                    ) : // byte
                    (i_opsel[1:0] == 2'b01) ? (
                        (o_result[1:0] == 2'b00) ? 4'b0011 :
                        //(o_result[1:0] == 2'b01) ? 4'b0110 :
                        (o_result[1:0] == 2'b10) ? 4'b1100 :
                        //(o_result[1:0] == 2'b11) ? 4'b1001 :
                        4'bxxxx
                    ) : // halfword
                    4'b1111 // word
    assign mem_addr = {o_result[31:2], 2'b00};

    // pass through stage
    assign o_PC4 = i_PC4;
    assign o_Jump = i_Jump;
    assign o_BranchEqual = i_BranchEqual;
    assign o_BranchLT = i_BranchLT;
    assign o_MemRead = i_MemRead;
    assign o_MemtoReg = i_MemtoReg;
    assign o_MemWrite = i_MemWrite;
    assign o_rd_waddr = i_rd_waddr;
    assign o_RegWrite = i_RegWrite;
    assign o_IsUInstruct = i_IsUInstruct;

endmodule

//`default_nettype wire
