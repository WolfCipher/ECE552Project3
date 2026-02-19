module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

    // PC signals
    wire [31:0] PC_F_D, PC_D_X; // before adding 4
    wire [31:0] PC4_D_X, PC4_X_M, PC4_M_W, PC4_W_F; // after adding 4
    wire[31:0] target_addr_X_M; // PC + target_addr

    // Mux Signals
    wire Jump_D_X, Jump_X_M;
    wire BranchEqual_D_X, BranchEqual_X_M;
    wire BranchLT_D_X, BranchLT_X_M;
    wire MemRead_D_X, MemRead_X_M;
    wire MemtoReg_D_X, MemtoReg_X_M, MemtoReg_M_W;
    wire MemWrite_D_X, MemWrite_X_M;
    wire RegWrite_D_X, RegWrite_X_M, RegWrite_M_W;
    wire ALUSrc_D_X;

    // Destination Address
    wire rd_waddr_D_X, rd_waddr_X_M, rd_waddr_M_W;

    // ALU result
    wire [31:0] ALU_X_M, ALU_M_W;

    // Signals just between decode and execute stages
    wire [31:0] reg1, reg2, imm;
    wire [2:0] i_opsel;
    wire i_sub, i_unsigned, i_arith;

    // Signals just between execute and memory
    wire eq, slt;

endmodule

// PC, instruction memory
module fetch(
);

endmodule

// control unit, register file, immediate decoder
// does NOT choose between immediate and register 2
module decode(
);

endmodule

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
    input wire i_ALUSrc,
    input wire i_Jump,
    input wire i_BranchEqual,
    input wire i_BranchLT,
    input wire i_MemRead,
    input wire i_MemtoReg,
    input wire i_MemWrite,
    input wire [4:0] i_rd_waddr,
    input wire i_RegWrite,
    output wire o_Jump,
    output wire o_BranchEqual,
    output wire o_BranchLT,
    output wire o_MemRead,
    output wire o_MemtoReg,
    output wire o_MemWrite,
    output wire [4:0] o_rd_waddr,
    output wire o_RegWrite
);

    // ALU
    wire i_op1, i_op2;
    assign i_op1 = reg1;
    assign i_op2 = i_ALUSrc ? imm : reg2;
    alu op (i_opsel, i_sub, i_unsigned, i_arith, i_op1, i_op2, o_result, o_eq, o_slt);

    // branch or jump target address
    assign target_addr = i_PC + imm;

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



endmodule

// data memory
module memory(
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
    input wire i_RegWrite
    output wire o_MemtoReg,
    output wire [4:0] o_rd_waddr,
    output wire o_RegWrite
);

    // determine PC
    assign o_PC = (i_BranchEqual & i_eq) | (i_BranchLT & i_slt) | (i_Jump) ? target_addr : i_PC;

    // read and write data TODO

    // pass through stage
    assign read_alu = i_result;
    assign o_MemtoReg = i_MemtoReg;
    assign o_rd_waddr = i_rd_waddr;
    assign o_RegWrite = i_RegWrite;

endmodule


module writeback(
    input wire [31:0] i_PC,
    input wire [31:0] read_data,
    input wire [31:0] read_alu,
    output wire [31:0] dest_result,
    output wire [31:0] o_PC,
    input wire i_MemtoReg,
    input wire [4:0] i_rd_waddr,
    input wire i_RegWrite
);
    // determine value to write back
    assign dest_result = i_MemtoReg ? read_data : read_alu;

    // write back

    // pass through stage
    assign o_PC = i_PC;

endmodule

module data_memory(
    input wire i_clk,
    input wire i_rst,
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

`default_nettype wire
