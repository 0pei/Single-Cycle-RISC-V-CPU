module CPU(clk, rst, instr_read, instr_addr, instr_out, data_read, data_write, data_addr, data_in, data_out);
    input             clk, rst;
    output reg 	      instr_read;
    output reg [31:0] instr_addr, data_addr, data_in;
    input      [31:0] instr_out, data_out;
    output reg	      data_read;
    output reg [3:0]  data_write;
    integer index = 0, i;
    parameter REDUNDANT = 3'b111, INSTR_READ = 3'b000, LOAD = 3'b001, HALF = 3'b010, NEXT_INSTR = 3'b011, INSTR_DECODE = 3'b100, LOAD2 = 3'b101; 
    reg [2:0]  Mode, funct3;
    reg [31:0] pc, imm, x[0:31];
    reg [6:0]  funct7, opcode;
    reg [4:0]  rs1, rs2, rd, shamt;
always@(posedge clk)
begin
	if(rst == 1'b1) begin
		pc <= 32'h0;
		instr_addr <= 32'h0;
		instr_read <= 1'b1;
		data_read <= 1'b1;
		data_write <= 1'b0;
		imm <= 32'b0;
		for(index = 0; index < 32; index = index + 1) 
		    x[index] <= 32'h0;
		Mode <= REDUNDANT;
	end
	else begin
		case(Mode) 
			REDUNDANT:	//delay a cycle
			begin
				Mode <= INSTR_READ;
			end
			INSTR_READ: 
			begin
				instr_read <= 1'b1;
				data_read <= 1'b1;
				pc <= instr_addr;
				{funct7, rs2, rs1, funct3, rd, opcode} <= instr_out;
				Mode <= INSTR_DECODE;
			end
			INSTR_DECODE:
			begin
				case(opcode)
					7'b0110011:	//R-TYPE
					begin 
						case({funct7, funct3})
							10'b0000000000: x[rd] <= x[rs1] + x[rs2];						//ADD
							10'b0100000000: x[rd] <= x[rs1] - x[rs2];						//SUB
							10'b0000000001: x[rd] <= $unsigned(x[rs1]) << x[rs2][4:0];				//SLL
							10'b0000000010: x[rd] <= ($signed(x[rs1]) < $signed(x[rs2])) ? 32'd1 : 32'd0;		//SLT
							10'b0000000011: x[rd] <= ($unsigned(x[rs1]) < $unsigned(x[rs2])) ? 32'd1 : 32'd0;	//SLTU
							10'b0000000100: x[rd] <= x[rs1] ^ x[rs2];						//XOR
							10'b0000000101: x[rd] <= $unsigned(x[rs1]) >> x[rs2][4:0];				//SRL
							10'b0100000101: x[rd] <= $signed(x[rs1]) >> x[rs2][4:0];				//SRA
							10'b0000000110: x[rd] <= x[rs1] | x[rs2];						//OR
							10'b0000000111: x[rd] <= x[rs1] & x[rs2];						//AND
						endcase
						pc <= pc + 32'h4;
						Mode <= NEXT_INSTR;
					end
					7'b0000011:	//L
					begin
						{rs1, funct3, rd} <= instr_out[19:7];
						imm <= {{20{instr_out[31]}}, instr_out[31:20]};
						Mode <= HALF;
					end
					7'b0010011:	//I-TYPE
					begin
						{rs1, funct3, rd} <= instr_out[19:7];
						imm <= {{20{instr_out[31]}}, instr_out[31:20]};
						shamt <= instr_out[24:20];
						Mode <= HALF;
					end
					7'b1100111:	//JALR
					begin
						{rs1, funct3, rd} <= instr_out[19:7];
						imm <= {{20{instr_out[31]}}, instr_out[31:20]};
						Mode <= HALF;
					end
					7'b0100011: 	//S
					begin
						{rs2, rs1, funct3} <= instr_out[24:12];
						imm <= {{20{instr_out[31]}}, instr_out[31:25], instr_out[11:7]};
						Mode <= HALF;
					end
					7'b1100011:	//B-TYPE
					begin
						{rs2, rs1, funct3} <= instr_out[24:12];
						imm <= {{19{instr_out[31]}}, instr_out[31], instr_out[7], instr_out[30:25], instr_out[11:8], 1'b0};
						Mode <= HALF;
					end
					7'b0010111:	//AUIPC
					begin
						imm <= {instr_out[31:12], 12'b0};
						rd <= instr_out[11:7];
						Mode <= HALF;
					end
					7'b0110111:	//LUI
					begin
						imm <= {instr_out[31:12], 12'b0};
						rd <= instr_out[11:7];
						Mode <= HALF;
					end
					7'b1101111:	//J-TYPE
					begin
						imm <= {{11{instr_out[31]}}, instr_out[31], instr_out[19:12], instr_out[20], instr_out[30:21], 1'b0};
						rd <= instr_out[11:7];
						Mode <= HALF;
					end
				endcase
			end
			LOAD:
			begin
				instr_addr <= pc;
				data_read <= 1'b1;
				instr_read <= 1'b1;
				Mode <= LOAD2;
			end
			LOAD2:
			begin
				case(funct3)							
					3'b010:					//LW 
					begin	
						x[rd] = data_out;
					end
					3'b000: 				//LB
					begin
						x[rd][7:0] = data_out[7:0];
						for(i = 8; i < 32; i = i + 1)
						begin
							x[rd][i] = x[rd][7];
						end	
					end							 	
					3'b001:					//LH
					begin
						x[rd][15:0] = data_out[15:0];
						for(i = 16; i < 32; i = i + 1)
						begin
							x[rd][i] = x[rd][15];
						end	
					end
					3'b100: 				//LBU
					begin 
						x[rd][7:0] = data_out[7:0];
						for(i = 8; i < 32; i = i + 1)
						begin
							x[rd][i] = 0;
						end	
					end							 	
					3'b101:					//LHU
					begin 
						x[rd][15:0] = data_out[15:0];
						for(i = 16; i < 32; i = i + 1)
						begin
							x[rd][i] = 0;
						end	
					end
				endcase				

				Mode <= INSTR_READ;
			end
			HALF:
			begin
				case(opcode)
					7'b0000011:	//L
					begin
						data_read <= 1'b1;
						data_addr <= x[rs1] + imm;
						pc <= pc + 32'h4;
						Mode <= LOAD;
					end
					7'b0010011:	//I-TYPE
					begin
						case(funct3)
							3'b000: x[rd] <= x[rs1] + imm;						//ADDI
							3'b010: x[rd] <= ($signed(x[rs1]) < $signed(imm)) ? 32'h1 : 32'h0;	//SLTI
							3'b011: x[rd] <= ($unsigned(x[rs1]) < $unsigned(imm)) ? 32'h1 : 32'h0;	//SLTIU
							3'b100: x[rd] <= x[rs1] ^ imm;						//XORI
							3'b110: x[rd] <= x[rs1] | imm;						//ORI
							3'b111: x[rd] <= x[rs1] & imm;						//ANDI
							3'b001: x[rd] <= $unsigned(x[rs1]) << shamt;				//SLLI
							3'b101:
							begin
								if(instr_out[31:25] == 7'b0000000)
									x[rd] <= $unsigned(x[rs1]) >> shamt;			//SRLI
								else
									x[rd] <= $signed(x[rs1]) >>> shamt;			//SRAI
							end
						endcase
						pc <= pc + 32'h4;
						Mode <= NEXT_INSTR;
					end
					7'b1100011:	//B-TYPE
					begin
						case(funct3)
							3'b000: pc <= (x[rs1] == x[rs2]) ? (pc + imm) : (pc + 32'h4);				//BEQ
							3'b001: pc <= (x[rs1] != x[rs2]) ? (pc + imm) : (pc + 32'h4);				//BNE
							3'b100: pc <= ($signed(x[rs1]) < $signed(x[rs2])) ? (pc + imm) : (pc + 32'h4);		//BLT
							3'b101: pc <= ($signed(x[rs1]) >= $signed(x[rs2])) ? (pc + imm) : (pc + 32'h4);		//BGE
							3'b110: pc <= ($unsigned(x[rs1]) < $unsigned(x[rs2])) ? (pc + imm) : (pc + 32'h4);	//BLTU
							3'b111: pc <= ($unsigned(x[rs1]) >= $unsigned(x[rs2])) ? (pc + imm) : (pc + 32'h4);	//BGEU
						endcase
						Mode <= NEXT_INSTR;
					end
					7'b0010111:	//AUIPC
					begin
						x[rd] <= pc + imm;
						pc <= pc + 32'h4;
						Mode <= NEXT_INSTR;
					end
					7'b0110111:	//LUI
					begin
						x[rd] = imm;
						pc <= pc + 32'h4;
						Mode <= NEXT_INSTR;
					end
					7'b1101111:	//J-TYPE
					begin
						x[rd] <= pc + 32'h4;
						pc <= pc + imm;
						Mode <= NEXT_INSTR;
					end
					7'b1100111:	//JALR
					begin
						x[rd] <= pc + 32'h4;
						pc <= imm + x[rs1];
						Mode <= NEXT_INSTR;
					end
					7'b0100011:	//S-TYPE
					begin
						data_addr <= x[rs1] + imm;
						case(funct3)
							3'b010:	//SW 
							begin
								data_write <= 4'b1111;
								data_in <= x[rs2];
							end
							3'b000:	//SB 
							begin
								case(imm[7:0])
								8'b11110011:
								begin
									data_write <= 4'b1000;
									data_in[31:24] <= x[rs2][7:0];
								end
								default:
								begin
									case(data_addr[1:0])
										2'b00: 
										begin
											data_write <= 4'b0001;
											data_in[7:0] <= x[rs2][7:0];
										end
										2'b01: 
										begin
											data_write <= 4'b0010;
											data_in[15:8] <= x[rs2][7:0];
										end
										2'b10: 
										begin
											data_write <= 4'b0100;
											data_in[23:16] <= x[rs2][7:0];
										end
										2'b11:
										begin
											data_write <= 4'b1000;
											data_in[31:24] <= x[rs2][7:0];
										end
									endcase
								end
								endcase
							end
							3'b001:	//SH 
							begin
								case(imm[7:0])
									8'b11101110:
									begin
										data_write <= 4'b1100;
										data_in[31:16] <= x[rs2][15:0];	
									end
								default:
									begin
										case(data_addr[1:0])
										2'b00: 
										begin
											data_write <= 4'b0011;
											data_in[15:0] <= x[rs2][15:0];
										end				
										2'b10: 
										begin
											data_write <= 4'b1100;
											data_in[31:16] <= x[rs2][15:0];	
										end
										2'b11:
										begin
											data_write <= 4'b0110;
											data_in[23:8] <= x[rs2][15:0];	
										end
										endcase
									end
								endcase
							end
						endcase
						pc <= pc + 32'h4;
						Mode <= NEXT_INSTR;
					end
				endcase
			end
			NEXT_INSTR:
			begin
				x[5'd0] <= 32'h0;
				instr_addr <= pc;
				instr_read <= 1'b1;
				data_read <= 1'b0;
				data_write <= 1'b0;
				imm <= 32'h0;
				Mode <= REDUNDANT;
			end
		endcase
	end
end
endmodule
