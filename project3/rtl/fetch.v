// define PC register

module fetch_stage #(
    parameter RESET_ADDR = 32'h00000000
) (
    input i_rst, i_clk,
	input [31:0] curr_addr,
	input [31:0] branch_target,
	input branch_taken,
	input wire [31:0] i_imem_rdata, // data from mem
	output wire [31:0] o_imem_raddr,
	output reg [31:0] pc,
	output wire [31:0] instruction
);
	wire[31:0] next_pc;
	wire[31:0] pc_incr;

	assign pc_incr = pc + 4;
	assign next_pc = branch_taken ? branch_target : pc_incr;
	assign o_imem_raddr = pc; // read at the addr not the next one
	assign instruction = i_imem_rdata; // what the instruction says


    always @(posedge i_clk) begin
        if (i_rst) pc <= RESET_ADDR; // if we need to rset set to base addr
        else pc <= next_pc; //otherwise just take the next instruciton that we found
    end


endmodule

