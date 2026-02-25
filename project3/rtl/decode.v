
module decode (
    input [31:0] instruction,
    output reg jump,
    output reg branch_eq,
    output reg branch_lt,
    output reg branch,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg alu_src, //1 if reg 0 if imm
    output reg reg_write,
    output reg [31:0] reg_data1,
    output reg [31:0] reg_data2,
    output reg [31:0] immediate,
    output reg [2:0] i_opsel,
    output reg i_sub,
    output reg i_unsigned,
    output reg i_arith,
    input wire        i_clk,
    input wire        i_reg_write_en,
    input wire [4:0]  i_reg_write_addr,
    input wire [31:0] i_reg_write_data,
    output halt // asserted if EBREAK
);

assign halt = instruction[6:0] == 7'b1110011;

// register file
reg [31:0] registers [0:31]; // array of 32 registers 32 bits wide --> represents all CPU regs
                             // will get values from the writeback stage

always @(*) begin
    reg_data1 = (instruction[19:15] == 5'b0) ? 32'b0 : registers[instruction[19:15]]; //gives contents of reg at addr instruction[x:y]
    reg_data2 = (instruction[24:20] == 5'b0) ? 32'b0 : registers[instruction[24:20]];
end


//control file
always @(*) begin
    jump = (instruction[2] & !instruction[5]) ? 1 : 0;
    branch_eq = (!instruction[14] & !instruction[12]);
    branch_lt = (instruction[14] & !instruction[12]); //funct3[2:0] is instruction[14:12]
    branch = (instruction[6] & !instruction[2]);
    mem_read = !instruction[5] & !instruction[4]; //opcode[6:0] is instruction[6:0]
    mem_write = !instruction[6] & instruction[5] & !instruction[4];
    mem_to_reg = instruction[4];
    alu_src = (!instruction[5] & !instruction[2]) |
                        (instruction[6] & instruction[2] & !instruction[3]) |
                        (!instruction[6] & instruction[5] & !instruction[4]);
    reg_write = !(!instruction[6] & instruction[5] & !instruction[4]) &
                            !(instruction[6] & !instruction[2]);
    i_opsel = instruction[14:12];
    i_sub = instruction[30];
    i_arith = instruction[30];
    i_unsigned = (instruction[14] & instruction[13]) | (instruction[13] & instruction[12]);
end

// for write back
always @(posedge i_clk) begin
    if (i_reg_write_en && i_reg_write_addr != 5'b0)
        registers[i_reg_write_addr] <= i_reg_write_data;
end

// choose immediate

// Instruction format, determined by the instruction decoder based on the
    // opcode. This is one-hot encoded according to the following format:
    // [0] R-type
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
wire [5:0] format;

assign format = (instruction[6:0] == 7'b0110011) ? 6'b000001 : // R-Type
                ((instruction[6:0] == 7'bx0xx0xx) || (instruction[6:0] == 7'b1xx01xx)) ? 6'b000010 : // I-Type
                (instruction[6:0] == 7'b010xxx) ? 6'b000100 : // S-Type
                (instruction[6:0] == 7'b1xxx0xx) ? 6'b001000 : // B-Type
                (instruction[6:0] == 7'b0xxx1xx) ? 6'b010000 : // U-Type
                (instruction[6:0] == 7'bxxx1xxx) ? 6'b100000 : // J-Type
                6'b000000; // invalid instruction


imm i (instruction, format, immediate);
// always @(*) begin
//     if (instruction[3]) begin // j type
//             immediate[20]    = instruction[31];
//             immediate[19:12] = instruction[19:12];
//             immediate[11]    = instruction[20];
//             immediate[10:1]  = instruction[30:21];
//             immediate[0]     = 1'b0;

//     end else if (instruction[2] & !instruction[6]) begin // u type
//         immediate[31:12] = instruction[31:12];
//         immediate[11:0] = {12'b0};

//     end else if (!instruction[2] &  instruction[6]) begin //b type
//         immediate[12]   = instruction[31];
//         immediate[11]   = instruction[7];
//         immediate[10:5] = instruction[30:25];
//         immediate[4:1]  = instruction[11:8];
//         immediate[0]    = 1'b0;

//     end else if ((!instruction[5] & !instruction[2]) | (instruction [6] & instruction[2] & ! instruction[3])) begin // i-type
//         immediate[11:0]  = instruction[31:20];
//         immediate[31:12] = {20{instruction[31]}};

//     end else if (! instruction[6] & instruction[5] & ! instruction[4]) begin //S type
//         immediate[11:5] = instruction[31:25];
//         immediate[4:0] = instruction[11:7];
//         immediate[31:12] = {20{instruction[31]}}; //sign extend to fill the rest
//     end
// end

//


endmodule

