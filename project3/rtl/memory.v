// data memory
module memory(
    input wire i_clk,
    input wire [31:0] i_result,
    input wire i_eq,
    input wire i_slt,
    input wire [31:0] target_addr,
    input wire [31:0] i_PC,
    output wire [31:0] o_PC,
    output wire [31:0] read_data,
    output wire [31:0] read_alu,
    input wire i_Jump,
    input wire i_BranchEqual,
    input wire i_BranchLT,
    input wire i_MemRead,
    input wire i_MemtoReg,
    input wire i_MemWrite,
    input wire [4:0] i_rd_waddr,
    input wire i_RegWrite,
    input wire i_IsUInstruct,
    input wire [31:0] i_uimm,
    output wire o_MemtoReg,
    output wire [4:0] o_rd_waddr,
    output wire o_RegWrite,
    output wire o_IsUInstruct,
    output wire [31:0] o_uimm
);

    // determine PC
    assign o_PC = (i_BranchEqual & i_eq) | (i_BranchLT & i_slt) | (i_Jump) ? target_addr : i_PC;

    // read and write data TODO
    data_memory dmem (i_clk, i_MemRead, i_MemWrite, read_alu, reg2, i_MemtoR)

    // pass through stage
    assign read_alu = i_result;
    assign o_MemtoReg = i_MemtoReg;
    assign o_rd_waddr = i_rd_waddr;
    assign o_RegWrite = i_RegWrite;
    assign o_IsUInstruct = i_IsUInstruct;
    assign o_uimm = i_uimm;

endmodule

module data_memory(
    input wire i_clk,
    input wire [3:0] mask,
    //input wire i_rst,
    input wire i_MemRead,
    input wire i_MemWrite,
    input wire [31:0] i_addr,
    input wire [31:0] i_data,
    output wire [31:0] o_data
);

    reg [31:0] d_mem [31:0];

    always @(posedge i_clk) begin
        // handle active-high reset
        // if (i_rst == 1) begin
        //     for (i = 0; i < 32; i = i + 1)
        //         reg_file[i] <= 32'd0;
        // end

        // only write if write enabled
        if (i_MemWrite == 1)
            d_mem[i_addr] <= i_data;

        // only read if read enabled
        if (i_MemRead == 1)
            o_data <= d_mem[i_addr];

    end

endmodule

//`default_nettype wire
