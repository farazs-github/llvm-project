//=- NanoMipsInstrInfo.td - NanoMips Instruction Information -*- tablegen -*-=//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file describes NanoMips instructions.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Mips profiles and nodes
//===----------------------------------------------------------------------===//

def MipsFullAddr : SDNode<"MipsISD::FullAddr", SDTIntUnaryOp>;
def NMUnalignedLW : SDNode<"MipsISD::UALW", SDTMipsLoadLR, [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;
def NMUnalignedLH : SDNode<"MipsISD::UALH", SDTMipsLoadLR, [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;
def NMUnalignedSW : SDNode<"MipsISD::UASW", SDTStore, [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;
def NMUnalignedSH : SDNode<"MipsISD::UASH", SDTStore, [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;

//===----------------------------------------------------------------------===//
// nanoMIPS Operand, Complex Patterns and Transformations Definitions.
//===----------------------------------------------------------------------===//

def imm32_NM : IntImmLeaf<i32, [{
    return (uint32_t)Imm.getZExtValue() == (uint64_t)Imm.getZExtValue();
}]>;
def immFitsAddiu32 : IntImmLeaf<i32, [{
  int64_t N = Imm.getSExtValue();
  return (N < -256 && N >= -4095) || (N > 4095 && N <= 65535);
}]>;
def imm32ZExt12 : IntImmLeaf<i32, [{ return isUInt<12>(Imm.getZExtValue()); }]>;
def imm32ZExt12ANDI :
  IntImmLeaf<i32, [{ return isUInt<12>(Imm.getZExtValue()) ||
                            Imm.getZExtValue() == 65535; }]>;
def imm32ZExt5  : IntImmLeaf<i32, [{ return isUInt<5>(Imm.getZExtValue()); }]>;
def imm32SExt12  : IntImmLeaf<i32, [{ return isInt<12>(Imm.getSExtValue()); }]>;
// True if (N + 1) fits in 12-bit field.
def immZExt12Plus1 : PatLeaf<(imm), [{
  return isUInt<13>(N->getZExtValue()) && isUInt<12>(N->getZExtValue() + 1);
}]>;
def immZExt7Plus1 : PatLeaf<(imm), [{
  return isUInt<7>(N->getZExtValue()) && isUInt<12>(N->getZExtValue() + 1);
}]>;
// Immediate range covering both signed 12-bit and unsigned 16-bit immediates.
def imm32SExt12OrZExt16 : IntImmLeaf<i32, [{ return isInt<12>(Imm.getSExtValue())
                                           || isUInt<16>(Imm.getZExtValue()); }]>;

def UImm12AsmOperandClass : UImmAsmOperandClass<12, []>;
def UImm5AsmOperandClass : UImmAsmOperandClass<5, [UImm12AsmOperandClass]>;
def UImm3Plus1AsmOperandClass :
  ConstantUImmAsmOperandClass<3, [UImm5AsmOperandClass], 1>;

def uimm12_nm : Operand<i32> {
  let PrintMethod = "printUImm<12>";
  let ParserMatchClass = !cast<AsmOperandClass>("UImm12AsmOperandClass");
}
def uimm5_nm : Operand<i32> {
  let PrintMethod = "printUImm<5>";
  let ParserMatchClass = !cast<AsmOperandClass>("UImm5AsmOperandClass");
}
def uimm3plus1_nm : Operand<i32> {
  let PrintMethod = "printUImm<3, 1>";
  let ParserMatchClass = !cast<AsmOperandClass>("UImm3Plus1AsmOperandClass");
}

def simm32power2 : IntImmLeaf<i32, [{ return isPowerOf2_32(Imm.getSExtValue()); }]>;

def uimm16_simm12 : Operand<i32>;

def addrsimm9 : ComplexPattern<iPTR, 2, "selectIntAddrSImm9", [frameindex]>;
def addruimm12 : ComplexPattern<iPTR, 2, "selectIntAddrUImm12", [frameindex]>;
def addrindexed : ComplexPattern<iPTR, 2, "selectIntAddrIndexed", [frameindex]>;
def addrindexedlsl1 : ComplexPattern<iPTR, 2, "selectIntAddrIndexedLsl1", [frameindex]>;
def addrindexedlsl2 : ComplexPattern<iPTR, 2, "selectIntAddrIndexedLsl2", []>;

def Log2XForm : SDNodeXForm<imm, [{ return CurDAG->getTargetConstant(Log2_32(N->getZExtValue()),
                                                                   SDLoc(N), MVT::i32);
                                  }]>;

//===----------------------------------------------------------------------===//
//
// Instruction Descriptions
//
//===----------------------------------------------------------------------===//


class _Pool_P32<bits<5> psel> : InstSize32 {
  let Inst{31-26} = {psel{4...2}, 0b0, psel{1...0}};
}

class _Pool_P_ADDIU<bits<5> psel> : _Pool_P32<0b00000> {
  let Inst{25...21} = psel;
}

class _Pool_P32A<bits<3> psel> : _Pool_P32<0b00100> {
  let Inst{2...0} = psel;
}

class _Pool_P_GP_W<bits<2> psel> : _Pool_P32<0b01000> {
  let Inst{1...0} = psel;
}

class _Pool_P_U12<bits<4> psel> : _Pool_P32<0b10000> {
  let Inst{15-12} = psel;
}

class _Pool_P_LUI<bits<1> psel> : _Pool_P32<0b11100> {
  let Inst{1} = psel;
}

class _Pool_P48I<bits<5> psel> : InstSize48 {
  let Inst{47...42} = 0b011000;
  let Inst{36...32} = psel;
}

class _Pool_P_GP_BH<bits<3> psel> : _Pool_P32<0b01001> {
  let Inst{20...18} = psel;
}

class _Pool_P_LS_U12<bits<4> psel> : _Pool_P32<0b10001> {
  let Inst{15...12} = psel;
}

class _Pool_P_LS_S9<bits<3> psel> : _Pool_P32<0b10101> {
  let Inst{10...8} = psel;
}

// TODO MOVE.BALC

class _Pool_P_BAL<bits<1> psel> : _Pool_P32<0b00110> {
  let Inst{25} = psel;
}

class _Pool_P_J<bits<4> psel> : _Pool_P32<0b01010> {
  let Inst{15...12} = psel;
}

class _Pool_P_BR1<bits<2> psel> : _Pool_P32<0b10010> {
  let Inst{15...14} = psel;
}

class _Pool_P_BR2<bits<2> psel> : _Pool_P32<0b10110> {
  let Inst{15...14} = psel;
}

class _Pool_P_BRI<bits<3> psel> : _Pool_P32<0b11010> {
  let Inst{20...18} = psel;
}

class _Pool_P_BALRSC<bits<5> psel> : _Pool_P_J<0b1000> {
  let Inst{25...21} = psel;
}

// TODO BRSC : _Pool_P_BALRSC<0b00000>
// TODO BALRSC : _Pool_P_BALRSC<!0b00000>

class _Pool_P_SHIFT<bits<4> psel> : _Pool_P_U12<0b1100> {
  let Inst{8...5} = psel;
  bits<5> shift;
  bits<5> rs;
  bits<5> rt;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{4...0} = shift;
}

class _Pool_P_SLL<bits<5> rt, bits<5> shift> : _Pool_P_SHIFT<0b0000> {
  let Inst{25...21} = rt;
  let Inst{4...0} = shift;
}

class _Pool_P_ROTX<bits<2> psel> : _Pool_P_U12<0b1101> {
  let Inst{11} = psel{1};
  let Inst{5} = psel{0};
}

class _Pool_P_EXT_INS<bits<4> psel> : _Pool_P_U12<psel> {
  let Inst{11} = 0;
  let Inst{5} = 0;
}

class _Pool_P_PREF_U12<bits<5> psel> : _Pool_P_LS_U12<0b0011> {
  let Inst{25...21} = psel;
}

class _Pool_P_LS_S0<bits<4> psel>: _Pool_P_LS_S9<0b000> {
  let Inst{14...11} = psel;
}

class _Pool_P_PREF_S9<bits<5> psel>: _Pool_P_LS_S0<0b0011> {
  let Inst{25...21} = psel;
}

class _Pool_P_LS_S1<bits<4> psel>: _Pool_P_LS_S9<0b001> {
  let Inst{14...11} = psel;
}

class _Pool_P_LL<bits<2> psel>: _Pool_P_LS_S1<0b1010> {
  let Inst{1...0} = psel;
}

class _Pool_P_SC<bits<2> psel>: _Pool_P_LS_S1<0b1011> {
  let Inst{1...0} = psel;
}

class _Pool_P_LS_E0<bits<4> psel>: _Pool_P_LS_S9<0b010> {
  let Inst{14...11} = psel;
}

class _Pool_P_LLE<bits<2> psel>: _Pool_P_LS_E0<0b1010> {
  let Inst{1...0} = psel;
}

class _Pool_P_PREFE<bits<5> psel>: _Pool_P_LS_E0<0b0011> {
  let Inst{25...21} = psel;
}

class _Pool_P_SCE<bits<2> psel>: _Pool_P_LS_E0<0b1011> {
  let Inst{1...0} = psel;
}

class _Pool_P_LS_WM<bits<1> psel>: _Pool_P_LS_S9<0b100> {
  let Inst{11} = psel;
}

class _Pool_P_LS_UAWM<bits<1> psel>: _Pool_P_LS_S9<0b101> {
  let Inst{11} = psel;
}

class _Pool_P16<bits<5> psel> : InstSize16 {
  let Inst{15-10} = {psel{4...2}, 0b1, psel{1...0}};
}

class _Pool_P16_MV<bits<5> psel> : _Pool_P16<0b00000> {
  let Inst{9...5} = psel;
}

// TODO LW16<bits<> psel> : _Pool_P16<0b00001>

// TODO BC16 : _Pool_P16<0b00010>

class _Pool_P16_SR<bits<1> psel> : _Pool_P16<0b00011> {
  let Inst{8} = psel;
}

class _Pool_P16_SHIFT<bits<1> psel> : _Pool_P16<0b00100> {
  let Inst{3} = psel;
}

// TODO LW_SP : _Pool_P16<0b00101>

// TODO BALC16 : _Pool_P16<0b00110>

class _Pool_P16_4X4<bits<2> psel> : _Pool_P16<0b00111> {
  let Inst{8} = psel{1};
  let Inst{3} = psel{0};
}

class _Pool_P16C<bits<1> psel> : _Pool_P16<0b01000> {
  let Inst{0} = psel;
}

class _Pool_POOL16C_00<bits<2> psel> : _Pool_P16<0b01000> {
  let Inst{3...2} = psel;
  let Inst{1...0} = 0b00;
}

// TODO LW_GP16 : _Pool_P16<0b01001>

class _Pool_P16_LB<bits<2> psel> : _Pool_P16<0b01011> {
  let Inst{3...2} = psel;
}

class _Pool_P16_A1<bits<1> psel> : _Pool_P16<0b01100> {
  let Inst{6} = psel;
}

// TODO LW_4X4 : _Pool_P16<0b01101> {

class _Pool_P16_LH<bits<2> psel> : _Pool_P16<0b01111> {
  let Inst{3} = psel{1};
  let Inst{0} = psel{0};
}

class _Pool_P16_A2<bits<1> psel> : _Pool_P16<0b10000> {
  let Inst{3} = psel;
}

//TODO SW_16 : _Pool_P16<0b10001>

//TODO BEQZC_16 : _Pool_P16<0b10010>


class _Pool_P16_ADDU<bits<1> psel> : _Pool_P16<0b10100> {
  let Inst{0} = psel;
}

//TODO SW_SP : _Pool_P16<0b10101>

// TODO BNEZC_16 : _Pool_P16<0b10110>

// TODO MOVEP : _Pool_P16<0b10111>

// TODO LI16 : _Pool_P16<0b11000>

// TODO SW_GP16 : _Pool_P16<0b10001>

class _Pool_P16_BR<bits<4> psel> : _Pool_P16<0b11010> {
  let Inst{3...0} = psel;
}

class _Pool_P16_RI<bits<2> psel> : _Pool_P16_MV<0b00000> {
  let Inst{4...3} = psel;
}

class _Pool_P16_SYSCALL<bits<1> psel> : _Pool_P16_RI<0b01> {
  let Inst{2} = psel;
}

// TODO MOVE_16 : _Pool_P16_RI<!0b0>

// TODO ANDI_16 : _Pool_P16<0b11100>

// TODO SW_4X4 : _Pool_P16<0b11101>

// TODO MOVEP_REV : _Pool_P16<0b11111>



class _Pool_P_RI<bits<2> psel> : _Pool_P_ADDIU<0b00000> {
  let Inst{20...19} = psel;
}

class _Pool_POOL32A0<bits<1> psel> : _Pool_P32A<0b000> {
  let Inst{5} = psel;
}

class _Pool_POOL32A0_0<bits<6> psel> : _Pool_POOL32A0<0b0> {
  let Inst{9...6} = psel{5...2};
  let Inst{4...3} = psel{1...0};
}

class _Pool_P_TRAP<bits<1> isel> : _Pool_POOL32A0_0<0b000000>
{
  let Inst{10} = isel;
}

class _Pool_POOL32A7<bits<3> psel> : _Pool_P32A<0b111> {
  let Inst{5...3} = psel;
}

// TODO  BC_32 : _Pool_P_BAL<0b0>

// 32-bit arithmetic and logical instructions with 3 register operands.

class ArithLogicR32<string opstr, RegisterOperand RO,
		    bits<6> psel,
                    SDPatternOperator OpNode = null_frag>:
  InstNM<(outs RO:$rd), (ins RO:$rs, RO:$rt),
         !strconcat(opstr, "\t$rd, $rs, $rt"),
         [(set RO:$rd, (OpNode RO:$rs, RO:$rt))]>, _Pool_POOL32A0_0<psel> {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{15...11} = rd;
}

// 16-bit arithmetic and logical instructions with 2 register operands, POOL16C_0
class ArithLogicR16<string opstr, RegisterOperand RO,
		    bits<2> isel,
                    SDPatternOperator OpNode = null_frag>:
    InstNM<(outs RO:$rt), (ins RO:$rs), !strconcat(opstr, "\t$rt, $rs"),
           [(set RO:$rt, (OpNode RO:$rs))]>, _Pool_POOL16C_00<isel> {
  bits<3> rs;
  bits<3> rt;
  let Inst{9...7} = rt;
  let Inst{6...4} = rs;
}

// Arithmetic and logical instructions with 2 register operands and immediate.
class ArithLogicINM<string opstr, Operand Od, RegisterOperand RO,
                    SDPatternOperator imm_type = null_frag,
                    SDPatternOperator OpNode = null_frag> :
  InstNM<(outs RO:$rt), (ins RO:$rs, Od:$imm),
         !strconcat(opstr, "\t$rt, $rs, $imm"),
         [(set RO:$rt, (OpNode RO:$rs, imm_type:$imm))]> {
  let isReMaterializable = 1;
}

class ArithLogicI32<string opstr, Operand Od, RegisterOperand RO,
                    SDPatternOperator imm_type = null_frag,
                    SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>;

class AddiU32<string opstr, Operand Od, RegisterOperand RO,
                    SDPatternOperator imm_type = null_frag,
                    SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>, _Pool_P32<0b00000> {
  bits<5> rt;
  bits<5> rs;
  bits<12> imm12;
  bits<16> imm16;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{11...0} = imm12;
}

class DivMod<string opstr, bits<6> psel, SDPatternOperator OpNode = null_frag> :
    ArithLogicR32<opstr, GPR32NMOpnd, psel, OpNode> {
  // Need to insert TEQ, because DIV(U)/MOD(U) don't trap on division by zero.
  bit usesCustomInserter = 1;
}

class CondLogicI32<string opstr, Operand Od, RegisterOperand RO,
                    SDPatternOperator imm_type = null_frag,
		    bits<4> psel,
                    SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>, _Pool_P_U12<psel> {
  bits<5> rt;
  bits<5> rs;
  bits<12> u12;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{11...0} = u12;
}

class ShiftI32<string opstr, Operand Od, RegisterOperand RO,
                    SDPatternOperator imm_type = null_frag,
		    bits<4> psel,
                    SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>, _Pool_P_SHIFT<psel> {
  bits<5> rt;
  bits<5> rs;
  bits<5> u5;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{4...0} = u5;
}

class ExtBaseNM<RegisterOperand RO = GPR32NMOpnd> :
  InstNM<(outs RO:$rt), (ins RO:$rs, uimm5:$pos, uimm5_plus1:$size),
         "ext\t$rt, $rs, $pos, $size",
         [(set RO:$rt, (MipsExt RO:$rs, immZExt5:$pos, immZExt5Plus1:$size))],
         II_EXT>, _Pool_P_EXT_INS<0b1111>;

class InsBaseNM<RegisterOperand RO = GPR32NMOpnd> :
  InstNM<(outs RO:$rt),
         (ins RO:$rs, uimm5:$pos, uimm5_inssize_plus1:$size, RO:$src),
         "ins \t$rt, $rs, $pos, $size",
         [(set RO:$rt,
               (MipsIns RO:$rs, immZExt5:$pos, immZExt5Plus1:$size, RO:$src))],
         II_INS>, _Pool_P_EXT_INS<0b1110> {
  let Constraints = "$src = $rt";
}

class Trap<string opstr, RegisterOperand RO, Operand ImmOp, bits<1> isel> :
  InstNM<(outs), (ins RO:$rs, RO:$rt, ImmOp:$imm),
         !strconcat(opstr, "\t$rt, $rs, $imm"), []>,
  _Pool_P_TRAP<isel> {
  let hasSideEffects = 1;
  let isCTI = 1;
  bits<5> rt;
  bits<5> rs;
  bits<5> cd;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{15...11} = cd;
}

// Instructions with 1 register (dest) and 1 immediate operand.
class RegImmNM<string opstr, Operand Od, RegisterOperand RO,
               SDPatternOperator imm_type = null_frag,
               SDPatternOperator OpNode = null_frag> :
  InstNM<(outs RO:$rt), (ins Od:$imm), !strconcat(opstr, "\t$rt, $imm"),
         [(set RO:$rt, (OpNode imm_type:$imm))]>;

class RegImm48<string opstr, Operand Od, RegisterOperand RO,
	       bits<5> isel,
               SDPatternOperator imm_type = null_frag,
               SDPatternOperator OpNode = null_frag> :
  InstNM<(outs RO:$rt), (ins Od:$imm), !strconcat(opstr, "\t$rt, $imm"),
         [(set RO:$rt, (OpNode imm_type:$imm))]>, _Pool_P48I<isel> {
  bits<5> rt;
  bits<32> imm;
  let Inst{41...37} = rt;
  let Inst{31...16} = imm{15...0};
  let Inst{15...0} = imm{31...16};
}

class LoadMemoryNM<string opstr, DAGOperand RO, DAGOperand MO,
                   SDPatternOperator OpNode = null_frag,
                   ComplexPattern Addr = addr,
                   InstrItinClass itin = NoItinerary> :
    InstNM<(outs RO:$rt), (ins MO:$addr), !strconcat(opstr, "\t$rt, $addr"),
           [(set RO:$rt, (OpNode Addr:$addr))],
           itin> {
  let DecoderMethod = "DecodeMem";
  let canFoldAsLoad = 1;
  let mayLoad = 1;
  string BaseOpcode = opstr;
}

class StoreMemoryNM<string opstr, DAGOperand RO, DAGOperand MO,
                    SDPatternOperator OpNode = null_frag,
                    ComplexPattern Addr = addr,
                    InstrItinClass itin> :
    InstNM<(outs), (ins RO:$rt, MO:$addr), !strconcat(opstr, "\t$rt, $addr"),
           [(OpNode RO:$rt, Addr:$addr)],
           itin> {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
  string BaseOpcode = opstr;
}

class LoadPCBase<DAGOperand RO, DAGOperand MO> :
    InstNM<(outs RO:$rt), (ins MO:$addr), "lwpc\t$rt, $addr", [], II_LW>,
    InstSize48 {
  let mayLoad = 1;
}

class StorePCBase<DAGOperand RO, DAGOperand MO> :
    InstNM<(outs), (ins RO:$rt, MO:$addr), "swpc\t$rt, $addr", [], II_SW>,
    InstSize48 {
  let mayStore = 1;
}

class CallNM<string opstr,
             SDPatternOperator OpNode = null_frag,
             SDPatternOperator imm_type = null_frag> :
  InstNM<(outs), (ins calltarget:$addr), !strconcat(opstr, "\t$addr"),
         [(OpNode imm_type:$addr)]> {
  let DecoderMethod = "DecodeJumpTarget";
  let isCall = 1;
  let isCTI = 1;
  let Defs = [RA_NM];
}

class MoveBalcBase : InstNM<(outs GPR32NMOpnd:$rd),
                            (ins GPR32NMOpnd:$rt, calltarget:$addr),
                            "move.balc\t$rd, $rt, $addr", []>, InstSize32 {
  let isCall = 1;
  let isCTI = 1;
  let Defs = [RA_NM];
}

// Indirect branch instruction.
class IndirectBranchNM<string opstr, RegisterOperand RO,
                       SDPatternOperator operator = null_frag>:
    InstNM<(outs), (ins RO:$rs), !strconcat(opstr, "\t$rs"),
           [(operator RO:$rs)]>, _Pool_P16_BR<0b0000> {
  let isTerminator = 1;
  let isBarrier = 1;
  let isCTI = 1;
  let isBranch = 1;
  let isIndirectBranch = 1;
}

class AdjustStack<SDPatternOperator operator> :
    PseudoInstNM<(outs), (ins i32imm:$amt1, i32imm:$amt2),
                 [(operator timm:$amt1, timm:$amt2)]> {
  let Defs = [SP_NM];
  let Uses = [SP_NM];
  let hasSideEffects = 1;
  let hasNoSchedulingInfo = 1;
}

def nmreglist : Operand<i32> {
  let PrintMethod = "printNanoMipsRegisterList";
}

class SaveRestore<string opstr> :
  InstNM<(outs),
         (ins uimm12_nm:$adj, nmreglist:$regs, variable_ops),
         !strconcat(opstr, "\t$adj$regs"), []> {
  let Defs = [SP_NM];
  let Uses = [SP_NM];
  let hasSideEffects = 1;
  let isCodeGenOnly = 1;
}
def SAVE_NM : SaveRestore<"save">, InstSize32;
def RESTORE_NM : SaveRestore<"restore">, InstSize32;
def RESTOREJRC_NM : SaveRestore<"restore.jrc">, InstSize32;

class LoadMultipleNM<string opstr> :
    InstNM<(outs GPR32NMOpnd:$rt), (ins mem:$addr, uimm3plus1_nm:$count),
           !strconcat(opstr, "\t$rt, $addr, $count"), []>, InstSize32 {
  let DecoderMethod = "DecodeMem";
  let mayLoad = 1;
}
class StoreMultipleNM<string opstr> :
    InstNM<(outs), (ins GPR32NMOpnd:$rt, mem:$addr, uimm3plus1_nm:$count),
           !strconcat(opstr, "\t$rt, $addr, $count"), []>, InstSize32 {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
}

class EffectiveAddressNM<string opstr, RegisterOperand RO> :
  InstNM<(outs RO:$rt), (ins mem_ea:$addr), !strconcat(opstr, "\t$rt, $addr"),
         [(set RO:$rt, addr:$addr)]> {
  let isCodeGenOnly = 1;
  let hasNoSchedulingInfo = 1;
  let DecoderMethod = "DecodeMem";
  string BaseOpcode = !strconcat(opstr, "_lea");
}

class UnalignedLoad<string opstr, SDNode OpNode,
                    RegisterOperand RO = GPR32NMOpnd> :
    InstNM<(outs RO:$rt), (ins mem_simm9:$addr, RO:$src),
           !strconcat(opstr, "\t$rt, $addr"),
           [(set RO:$rt, (OpNode addrsimm9:$addr, RO:$src))]>, InstSize32 {
  let DecoderMethod = "DecodeMem";
  string Constraints = "$src = $rt";
  let mayLoad = 1;
  let canFoldAsLoad = 1;
}

class UnalignedStore<string opstr, SDNode OpNode,
                     RegisterOperand RO = GPR32NMOpnd> :
    InstNM<(outs), (ins RO:$rt, mem_simm9:$addr),
           !strconcat(opstr, "\t$rt, $addr"),
           [(OpNode RO:$rt, addrsimm9:$addr)]>, InstSize32 {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
}

class ReadHardwareNM<RegisterOperand CPURegOperand, RegisterOperand RO> :
  InstNM<(outs CPURegOperand:$rt), (ins RO:$hs, uimm5:$sel),
  "rdhwr\t$rt, $hs, $sel", []>, InstSize32 {
  let isCodeGenOnly = 1;
}

class SignExtInRegNM<string opstr, ValueType vt, RegisterOperand RO> :
  InstNM<(outs RO:$rd), (ins RO:$rt), !strconcat(opstr, "\t$rd, $rt"),
         [(set RO:$rd, (sext_inreg RO:$rt, vt))]>, InstSize32;

class LoadScaledAddressNM<string opstr, RegisterOperand RO> :
  InstNM<(outs RO:$rd), (ins RO:$rs, RO:$rt, uimm2:$shift),
         !strconcat(opstr, "\t$rd, $rs, $rt, $shift"),
         [(set RO:$rd, (add (shl RO:$rs, immZExt2:$shift), RO:$rt))]>,
  InstSize32;

class CountLeading0NM<string opstr, RegisterOperand RO>:
  InstNM<(outs RO:$rd), (ins RO:$rs), !strconcat(opstr, "\t$rd, $rs"),
         [(set RO:$rd, (ctlz RO:$rs))]>, InstSize32;

class CountLeading1NM<string opstr, RegisterOperand RO>:
  InstNM<(outs RO:$rd), (ins RO:$rs), !strconcat(opstr, "\t$rd, $rs"),
         [(set RO:$rd, (ctlz (not RO:$rs)))]>, InstSize32;

class ReverseNM<string opstr, RegisterOperand RO, SDNode OpNode>:
  InstNM<(outs RO:$rd), (ins RO:$rs), !strconcat(opstr, "\t$rd, $rs"),
         [(set RO:$rd, (OpNode RO:$rs))]>, InstSize32;

//===----------------------------------------------------------------------===//
//
// Instruction Definitions
//
//===----------------------------------------------------------------------===//

// _POOL32A0_0 pool of instructions.
def SLLV_NM  : ArithLogicR32<"sllv", GPR32NMOpnd, 0b000010, shl>;
def SRLV_NM  : ArithLogicR32<"srlv", GPR32NMOpnd, 0b000110, srl>;
def SRAV_NM  : ArithLogicR32<"srav", GPR32NMOpnd, 0b001010, sra>;
def ROTRV_NM : ArithLogicR32<"rotrv", GPR32NMOpnd, 0b001110, rotr>;
def ADD_NM   : ArithLogicR32<"add", GPR32NMOpnd, 0b010010>;
def ADDu_NM  : ArithLogicR32<"addu", GPR32NMOpnd, 0b010110, add>;
def SUB_NM   : ArithLogicR32<"sub", GPR32NMOpnd, 0b011010>;
def SUBu_NM  : ArithLogicR32<"subu", GPR32NMOpnd, 0b011110, sub>;
def AND_NM   : ArithLogicR32<"and", GPR32NMOpnd, 0b100110, and>;
def OR_NM    : ArithLogicR32<"or", GPR32NMOpnd, 0b101010, or>;
def NOR_NM   : ArithLogicR32<"nor", GPR32NMOpnd, 0b101110>;
def XOR_NM   : ArithLogicR32<"xor", GPR32NMOpnd, 0b110010, xor>;
def SLT_NM   : ArithLogicR32<"slt", GPR32NMOpnd, 0b110110, setlt>;
def SLTU_NM  : ArithLogicR32<"sltu", GPR32NMOpnd, 0b111010, setult>;
def MUL_NM   : ArithLogicR32<"mul", GPR32NMOpnd, 0b000011, mul>;
def MUH_NM   : ArithLogicR32<"muh", GPR32NMOpnd, 0b000111, mulhs>;
def MULU_NM  : ArithLogicR32<"mulu", GPR32NMOpnd, 0b001011>;
def MUHU_NM  : ArithLogicR32<"muhu", GPR32NMOpnd, 0b001111, mulhu>;
def DIV_NM   : DivMod<"div", 0b010011, sdiv>;
def MOD_NM   : DivMod<"mod", 0b010111, srem>;
def DIVU_NM  : DivMod<"divu", 0b011011, udiv>;
def MODU_NM  : DivMod<"modu", 0b011111, urem>;

// P.U12 pool of instructions
def ORI_NM   : CondLogicI32<"ori", uimm12_nm, GPR32NMOpnd, imm32ZExt12, 0b0000, or>;
def XORI_NM  : CondLogicI32<"xori", uimm12_nm, GPR32NMOpnd, imm32ZExt12, 0b0001, xor>;
def ANDI_NM  : CondLogicI32<"andi", uimm16, GPR32NMOpnd, imm32ZExt12ANDI, 0b0010, and>;
def SLTI_NM  : CondLogicI32<"slti", uimm12_nm, GPR32NMOpnd, imm32ZExt12, 0b0100, setlt>;
def SLTIU_NM : CondLogicI32<"sltiu", uimm12_nm, GPR32NMOpnd, imm32ZExt12, 0b0101, setult>;
def SEQI_NM  : CondLogicI32<"seqi", uimm12_nm, GPR32NMOpnd, imm32ZExt12, 0b0110, seteq>;
 
// P.SHIFT pool of instructions
def SLL_NM  : ShiftI32<"sll", uimm5_nm, GPR32NMOpnd, imm32ZExt5, 0b0000, shl>;
def SRL_NM  : ShiftI32<"srl", uimm5_nm, GPR32NMOpnd, imm32ZExt5, 0b0010, srl>;
def SRA_NM  : ShiftI32<"sra", uimm5_nm, GPR32NMOpnd, imm32ZExt5, 0b0100, sra>;
def ROTR_NM : ShiftI32<"rotr", uimm5_nm, GPR32NMOpnd, imm32ZExt5, 0b0110, rotr>;

def EXT_NM : ExtBaseNM;
def INS_NM : InsBaseNM;

def ADDiu_NM : AddiU32<"addiu", uimm16_simm12, GPR32NMOpnd,
                             imm32SExt12OrZExt16, add>;
let Constraints = "$rt = $rs" in
def ADDIU48_NM : ArithLogicINM<"addiu[48]", simm32_relaxed, GPR32NMOpnd,
                               imm32_NM, add>, _Pool_P48I<0b00001>;

def LSA_NM : LoadScaledAddressNM<"lsa", GPR32NMOpnd>;

def SEB_NM : SignExtInRegNM<"seb", i8, GPR32NMOpnd>;
def SEH_NM : SignExtInRegNM<"seh", i16, GPR32NMOpnd>;

def CLZ_NM : CountLeading0NM<"clz", GPR32NMOpnd>;
def CLO_NM : CountLeading1NM<"clo", GPR32NMOpnd>;

def BITREVW_NM : ReverseNM<"bitrevw", GPR32NMOpnd, bitreverse>;
def BYTEREVW_NM : ReverseNM<"byterevw", GPR32NMOpnd, bswap>;

// P.TRAP pool of instructions.
def TEQ_NM : Trap<"teq", GPR32NMOpnd, uimm5_nm, 0b0>;
def TNE_NM : Trap<"tne", GPR32NMOpnd, uimm5_nm, 0b1>;

def NOT_NM   : ArithLogicR16<"not", GPR3Opnd, 0b00, not>;
def XOR16_NM : ArithLogicR16<"xor16", GPR3Opnd, 0b01>;
def AND16_NM : ArithLogicR16<"and16", GPR3Opnd, 0b10>;
def OR16_NM  : ArithLogicR16<"or16", GPR3Opnd, 0b11>;

def JRC_NM : IndirectBranchNM<"jrc", GPR32NMOpnd>;

def BALC_NM : CallNM<"balc", MipsJmpLink, tglobaladdr>, InstSize32;
def MOVEBALC_NM : MoveBalcBase;

let isReMaterializable = 1 in {
def Li_NM : RegImm48<"li", simm32_relaxed, GPR32NMOpnd, 0b00000>;
def LA_NM : RegImm48<"la", simm32_relaxed, GPR32NMOpnd, 0b00011>;

def LAGPB_NM : RegImm48<"addiu.b", simm32_relaxed, GPR32NMOpnd, 0b00010> {
    let AsmString = "addiu.b $rt, $$gp, %gprel( $imm )";
    let isReMaterializable = 1;
}

} // isReMaterializable = 1

def ALUIPC_NM : RegImmNM<"aluipc", simm32_relaxed, GPR32NMOpnd>, InstSize32;

def LEA_ADDiu_NM : EffectiveAddressNM<"addiu", GPR32NMOpnd>, InstSize32;

def RDHWR_NM : ReadHardwareNM<GPR32NMOpnd, HWRegsOpnd>;

def ADJCALLSTACKDOWN_NM : AdjustStack<callseq_start>;
def ADJCALLSTACKUP_NM   : AdjustStack<callseq_end>;

// Return instruction is matched as RetRA, then expanded into PseudoReturnNM
// after register allocation. Finally, MipsAsmPrinter expands this into JRC_NM.
def PseudoReturnNM : PseudoInstNM<(outs), (ins GPR32NMOpnd:$rs), []> {
  let isTerminator = 1;
  let isBarrier = 1;
  let isReturn = 1;
  let isCodeGenOnly = 1;
  let hasCtrlDep = 1;
  let hasExtraSrcRegAllocReq = 1;
  bit isCTI = 1;
}

// Indirect branch is matched as PseudoIndirectBranchNM and expanded to JRC_NM.
def PseudoIndirectBranchNM :
    PseudoInstNM<(outs), (ins GPR32NMOpnd:$rs), [(brind GPR32NMOpnd:$rs)]>,
    PseudoInstExpansion<(JRC_NM GPR32NMOpnd:$rs)> {
  let isTerminator = 1;
  let isBarrier = 1;
  let isBranch = 1;
  let isIndirectBranch = 1;
  bit isCTI = 1;
}

let hasPostISelHook = 1, isCall = 1, isCTI = 1, Defs = [RA_NM] in {
  def JALRC_NM : InstNM<(outs GPR32NMOpnd:$rd), (ins GPR32NMOpnd:$rs),
                        "jalrc\t$rd, $rs", []>, InstSize32;

  def JALRCPseudo : PseudoInstNM<(outs), (ins GPR32NMOpnd:$rs),
                                 [(MipsJmpLink GPR32NMOpnd:$rs)]>,
    PseudoInstExpansion<(JALRC_NM RA_NM, GPR32NMOpnd:$rs)>;
}

def : NMPat<(i32 imm32_NM:$imm), (Li_NM imm:$imm)>;

def : NMPat<(MipsJmpLink (i32 texternalsym:$dst)), (BALC_NM texternalsym:$dst)>;

def : NMPat<(MipsFullAddr tglobaltlsaddr:$in), (LA_NM tglobaltlsaddr:$in)>;
def : NMPat<(MipsFullAddr tblockaddress:$in), (LA_NM tblockaddress:$in)>;
def : NMPat<(MipsFullAddr tjumptable:$in), (LA_NM tjumptable:$in)>;

def : NMPat<(not (or GPR32NM:$rs, GPR32NM:$rt)),
            (NOR_NM GPR32NM:$rs, GPR32NM:$rt)>;

def : NMPat<(trap), (TEQ_NM ZERO_NM, ZERO_NM, 0)>;

// SetCC patterns.
def : NMPat<(setne GPR32NM:$lhs, 0), (SLTU_NM ZERO_NM, GPR32NM:$lhs)>;
def : NMPat<(seteq GPR32NM:$lhs, GPR32NM:$rhs),
            (SLTIU_NM (XOR_NM GPR32NM:$lhs, GPR32NM:$rhs), 1)>;
def : NMPat<(setne GPR32NM:$lhs, GPR32NM:$rhs),
            (SLTU_NM ZERO_NM, (XOR_NM GPR32NM:$lhs, GPR32NM:$rhs))>;
def : NMPat<(setle GPR32NM:$lhs, GPR32NM:$rhs),
            (XORI_NM (SLT_NM GPR32NM:$rhs, GPR32NM:$lhs), 1)>;
def : NMPat<(setule GPR32NM:$lhs, GPR32NM:$rhs),
            (XORI_NM (SLTU_NM GPR32NM:$rhs, GPR32NM:$lhs), 1)>;
def : NMPat<(setgt GPR32NM:$lhs, GPR32NM:$rhs),
            (SLT_NM GPR32NM:$rhs, GPR32NM:$lhs)>;
def : NMPat<(setugt GPR32NM:$lhs, GPR32NM:$rhs),
            (SLTU_NM GPR32NM:$rhs, GPR32NM:$lhs)>;
def : NMPat<(setge GPR32NM:$lhs, GPR32NM:$rhs),
            (XORI_NM (SLT_NM GPR32NM:$lhs, GPR32NM:$rhs), 1)>;
def : NMPat<(setuge GPR32NM:$lhs, GPR32NM:$rhs),
            (XORI_NM (SLTU_NM GPR32NM:$lhs, GPR32NM:$rhs), 1)>;

//===----------------------------------------------------------------------===//
//
// Jump and Branch Instructions.
//
//===----------------------------------------------------------------------===//

// NanoMips has only 'compact' jumps and branches, with no delay slots.
// Described using IsntSE class for the moment, should use specific
// NanoMips instruction formats later to get correct sizes.  Some
// branch instructions exist in multiple different sizes, and should
// likely be distinct instructions later.

// This class is missing instruction size, because these instructions can be
// encoded in formats of different size (eg. BEQC16 and BEQC32).
class CBranchNM<string opstr, DAGOperand opnd, PatFrag cond_op,
                RegisterOperand RO>
    : InstNM<(outs), (ins RO:$rs, RO:$rt, opnd:$offset),
             !strconcat(opstr, "\t$rs, $rt, $offset"),
             [(brcond (i32 (cond_op RO:$rs, RO:$rt)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 0;
  bit isCTI = 1;
}

class CBranchImmNM<string opstr, DAGOperand opnd, PatFrag cond_op,
                   RegisterOperand RO,
                   Operand imm_type, SDPatternOperator ImmOp>
    : InstSize32,
      InstNM<(outs), (ins RO:$rt, imm_type:$u, opnd:$offset),
             !strconcat(opstr, "\t$rt, $u, $offset"),
             [(brcond (i32 (cond_op RO:$rt, ImmOp:$u)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 0;
  bit isCTI = 1;
}

class CBranchZeroNM<string opstr, DAGOperand opnd, PatFrag cond_op,
                    RegisterOperand RO>
    : InstSize16,
      InstNM<(outs), (ins RO:$rs, opnd:$offset),
             !strconcat(opstr, "\t$rs, $offset"),
             [(brcond (i32 (cond_op RO:$rs, 0)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  bit isCTI = 1;
}

class CBranchBitNM<string opstr, DAGOperand opnd, PatFrag cond_op,
                   RegisterOperand RO,
                   Operand imm_type, SDPatternOperator ImmOp>
    : InstSize32,
      InstNM<(outs), (ins RO:$rt, imm_type:$u, opnd:$offset),
             !strconcat(opstr, "\t$rt, $u, $offset"),
        [(brcond (i32 (cond_op (and RO:$rt, (shl 1, ImmOp:$u)), 0)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 0;
  bit isCTI = 1;
}


let isCodeGenOnly = 1, hasNoSchedulingInfo = 1,
    hasDelaySlot = 0 in {

// TODO: BBEQZ/BBNEZ bit-test conditional branch instructions
def BEQC_NM  : CBranchNM<"beqc", brtarget, seteq, GPR32NMOpnd>, InstSize32;
def BEQIC_NM : CBranchImmNM<"beqic", brtarget, seteq, GPR32NMOpnd, uimm7, immZExt7>;
def BEQZC_NM : CBranchZeroNM<"beqzc", brtarget, seteq, GPR32NMOpnd>;

def BGEC_NM   : CBranchNM<"bgec", brtarget, setge, GPR32NMOpnd>, InstSize32;
def BGEIC_NM  : CBranchImmNM<"bgeic", brtarget, setge, GPR32NMOpnd, uimm7, immZExt7>;
def BGEIUC_NM : CBranchImmNM<"bgeiuc", brtarget, setuge, GPR32NMOpnd, uimm7, immZExt7>;
def BGEUC_NM  : CBranchNM<"bgeuc", brtarget, setuge, GPR32NMOpnd>, InstSize32;

def BLTC_NM   : CBranchNM<"bltc", brtarget, setlt, GPR32NMOpnd>, InstSize32;
def BLTIC_NM  : CBranchImmNM<"bltic", brtarget, setlt, GPR32NMOpnd, uimm7, immZExt7>;
def BLTIUC_NM : CBranchImmNM<"bltiuc", brtarget, setult, GPR32NMOpnd, uimm7, immZExt7>;
def BLTUC_NM  : CBranchNM<"bltuc", brtarget, setult, GPR32NMOpnd>, InstSize32;

def BNEC_NM  : CBranchNM<"bnec", brtarget, setne, GPR32NMOpnd>, InstSize32;
def BNEIC_NM : CBranchImmNM<"bneic", brtarget, setne, GPR32NMOpnd, uimm7, immZExt7>;
def BNEZC_NM : CBranchZeroNM<"bnezc", brtarget, setne, GPR32NMOpnd>;

// Bit-test branches
def BBNEZC_NM : CBranchBitNM<"bbnezc", brtarget, setne, GPR32NMOpnd, simm32, simm32power2>;
def BBEQZC_NM : CBranchBitNM<"bbeqzc", brtarget, seteq, GPR32NMOpnd, simm32, simm32power2>;

}

class BCBase : InstNM<(outs), (ins jmptarget:$target), "bc\t$target",
                      [(br bb:$target)], II_J>, InstSize32 {
  let isTerminator = 1;
  let isBarrier = 1;
  let isBranch = 1;
  let isCTI = 1;
}
def BC_NM : BCBase;

class TailCallBase : PseudoInstNM<(outs), (ins calltarget:$target), []>,
                     PseudoInstExpansion<(BC_NM jmptarget:$target)> {
  let isCall = 1;
  let isTerminator = 1;
  let isReturn = 1;
  let isBarrier = 1;
  let isCTI = 1;
}
def TAILCALL_NM : TailCallBase;

class TailCallRegBase : PseudoInstNM<(outs), (ins GPR32NMOpnd:$rs),
                                     [(MipsTailCall GPR32NMOpnd:$rs)]>,
                        PseudoInstExpansion<(JRC_NM GPR32NMOpnd:$rs)> {
  let isCall = 1;
  let isTerminator = 1;
  let isReturn = 1;
  let isBarrier = 1;
  let isCTI = 1;
  let hasPostISelHook = 1;
}
def TAILCALLREG_NM : TailCallRegBase;

def : NMPat<(MipsTailCall (i32 tglobaladdr:$dst)),
            (TAILCALL_NM tglobaladdr:$dst)>;
def : NMPat<(MipsTailCall (i32 texternalsym:$dst)),
            (TAILCALL_NM texternalsym:$dst)>;

// '>-1' can be represented as '>=0'.
def : NMPat<(brcond (i32 (setgt GPR32NM:$lhs, -1)), bb:$dst),
            (BGEC_NM GPR32NM:$lhs, ZERO_NM, bb:$dst)>;

// Reversed branch conditions:
def : NMPat<(brcond (i32 (setugt GPR32NM:$lhs, GPR32NM:$rhs)), bb:$dst),
            (BLTUC_NM GPR32NM:$rhs, GPR32NM:$lhs, bb:$dst)>;
def : NMPat<(brcond (i32 (setgt GPR32NM:$lhs, GPR32NM:$rhs)), bb:$dst),
            (BLTC_NM GPR32NM:$rhs, GPR32NM:$lhs, bb:$dst)>;
def : NMPat<(brcond (i32 (setule GPR32NM:$lhs, GPR32NM:$rhs)), bb:$dst),
            (BGEUC_NM GPR32NM:$rhs, GPR32NM:$lhs, bb:$dst)>;
def : NMPat<(brcond (i32 (setle GPR32NM:$lhs, GPR32NM:$rhs)), bb:$dst),
            (BGEC_NM GPR32NM:$rhs, GPR32NM:$lhs, bb:$dst)>;

// Immediate comparison branches with offset
def : NMPat<(brcond (i32 (setgt GPR32NM:$lhs, immZExt7Plus1:$imm)), bb:$dst),
            (BGEIC_NM GPR32NM:$lhs, (Plus1 $imm), bb:$dst)>;
def : NMPat<(brcond (i32 (setugt GPR32NM:$lhs, immZExt7Plus1:$imm)), bb:$dst),
            (BGEIUC_NM GPR32NM:$lhs, (Plus1 $imm), bb:$dst)>;

// Branch on integer value
def : NMPat<(brcond (i32 GPR32NM:$lhs), bb:$dst),
            (BNEC_NM GPR32NM:$lhs, ZERO_NM, bb:$dst)>;

// Bit-test branch
def : NMPat<(brcond (i32 (setne (and GPR32NM:$rt, simm32power2:$imm), 0)), bb:$offset),
          (BBNEZC_NM GPR32NM:$rt, (Log2XForm $imm), bb:$offset)>;
def : NMPat<(brcond (i32 (seteq (and GPR32NM:$rt, simm32power2:$imm), 0)), bb:$offset),
          (BBEQZC_NM GPR32NM:$rt, (Log2XForm $imm), bb:$offset)>;


//===----------------------------------------------------------------------===//
//
// Load / store instructions
//
//===----------------------------------------------------------------------===//

let isCodeGenOnly = 1 in {

// TODO: addruimm12 and addrsimm9 need to be looked into again. Currently
//       addruimm12 needs to come before addrsimm9, because addrsimm9 handles
//       loads/store that do not fit the offset. If we put the same handling in
//       addruimm12, this will cause addrsimm9 to never get selected.
def LWs9_NM : LoadMemoryNM<"lw", GPR32NMOpnd, mem, load, addrsimm9, II_LW>, InstSize32;
def LW_NM : LoadMemoryNM<"lw", GPR32NMOpnd, mem, load, addruimm12, II_LW>, InstSize32;
def LWXS_NM : LoadMemoryNM<"lwxs", GPR32NMOpnd, mem, load, addrindexedlsl2, II_LW>, InstSize32;
def LWX_NM : LoadMemoryNM<"lwx", GPR32NMOpnd, mem, load, addrindexed, II_LW>, InstSize32;
def SW_NM : StoreMemoryNM<"sw", GPR32NMOpnd, mem, store, addruimm12, II_SW>, InstSize32;
def SWs9_NM : StoreMemoryNM<"sw", GPR32NMOpnd, mem, store, addrsimm9, II_SW>, InstSize32;
def SWXS_NM : StoreMemoryNM<"swxs", GPR32NMOpnd, mem, store, addrindexedlsl2, II_SW>, InstSize32;
def SWX_NM : StoreMemoryNM<"swx", GPR32NMOpnd, mem, store, addrindexed, II_SW>, InstSize32;

def LHU_NM : LoadMemoryNM<"lhu", GPR32NMOpnd, mem, zextloadi16, addruimm12, II_LHU>, InstSize32;
def LHUs9_NM : LoadMemoryNM<"lhu", GPR32NMOpnd, mem, zextloadi16, addrsimm9, II_LHU>, InstSize32;
def LHUXS_NM : LoadMemoryNM<"lhuxs", GPR32NMOpnd, mem, zextloadi16, addrindexedlsl1, II_LHU>, InstSize32;
def LHUX_NM : LoadMemoryNM<"lhux", GPR32NMOpnd, mem, zextloadi16, addrindexed, II_LHU>, InstSize32;
def LH_NM : LoadMemoryNM<"lh", GPR32NMOpnd, mem, sextloadi16, addruimm12, II_LH>, InstSize32;
def LHs9_NM : LoadMemoryNM<"lh", GPR32NMOpnd, mem, sextloadi16, addrsimm9, II_LH>, InstSize32;
def LHXS_NM : LoadMemoryNM<"lhxs", GPR32NMOpnd, mem, sextloadi16, addrindexedlsl1, II_LH>, InstSize32;
def LHX_NM : LoadMemoryNM<"lhx", GPR32NMOpnd, mem, sextloadi16, addrindexed, II_LH>, InstSize32;
def SH_NM : StoreMemoryNM<"sh", GPR32NMOpnd, mem, truncstorei16, addruimm12, II_SH>, InstSize32;
def SHs9_NM : StoreMemoryNM<"sh", GPR32NMOpnd, mem, truncstorei16, addrsimm9, II_SH>, InstSize32;
def SHXS_NM : StoreMemoryNM<"shxs", GPR32NMOpnd, mem, truncstorei16, addrindexedlsl1, II_SH>, InstSize32;
def SHX_NM : StoreMemoryNM<"shx", GPR32NMOpnd, mem, truncstorei16, addrindexed, II_SH>, InstSize32;

def LBU_NM : LoadMemoryNM<"lbu", GPR32NMOpnd, mem, zextloadi8, addruimm12, II_LBU>, InstSize32;
def LBUs9_NM : LoadMemoryNM<"lbu", GPR32NMOpnd, mem, zextloadi8, addrsimm9, II_LBU>, InstSize32;
def LBUX_NM : LoadMemoryNM<"lbux", GPR32NMOpnd, mem, zextloadi8, addrindexed, II_LBU>, InstSize32;
def LB_NM : LoadMemoryNM<"lb", GPR32NMOpnd, mem, sextloadi8, addruimm12, II_LB>, InstSize32;
def LBs9_NM : LoadMemoryNM<"lb", GPR32NMOpnd, mem, sextloadi8, addrsimm9, II_LB>, InstSize32;
def LBX_NM : LoadMemoryNM<"lbx", GPR32NMOpnd, mem, sextloadi8, addrindexed, II_LB>, InstSize32;
def SB_NM : StoreMemoryNM<"sb", GPR32NMOpnd, mem, truncstorei8, addruimm12, II_SB>, InstSize32;
def SBs9_NM : StoreMemoryNM<"sb", GPR32NMOpnd, mem, truncstorei8, addrsimm9, II_SB>, InstSize32;
def SBX_NM : StoreMemoryNM<"sbx", GPR32NMOpnd, mem, truncstorei8, addrindexed, II_SB>, InstSize32;

// TODO: Halfword load/store is never selected, this needs to be looked into.
def UALH_NM : UnalignedLoad<"ualh", NMUnalignedLH>;
def UALW_NM : UnalignedLoad<"ualw", NMUnalignedLW>;
def UASH_NM : UnalignedStore<"uash", NMUnalignedSH>;
def UASW_NM : UnalignedStore<"uasw", NMUnalignedSW>;

def LWGP_NM : LoadMemoryNM<"lw", GPR32NMOpnd, mem>, InstSize32;

def SWPC_NM : StorePCBase<GPR32NMOpnd, simm32>;
def LWPC_NM : LoadPCBase<GPR32NMOpnd, simm32>;

def LWM_NM : LoadMultipleNM<"lwm">;
def UALWM_NM : LoadMultipleNM<"ualwm">;
def SWM_NM : StoreMultipleNM<"swm">;
def UASWM_NM : StoreMultipleNM<"uaswm">;

def MOVE_NM : InstNM<(outs GPR32NMOpnd:$rt), (ins GPR32NMOpnd:$rs),
                      "move\t$rt, $rs", []>, InstSize16;
def MOVEP_NM : InstNM<(outs GPR32NMOpnd:$dst1, GPR32NMOpnd:$dst2),
                      (ins GPR32NMOpnd:$src1, GPR32NMOpnd:$src2),
                      "movep\t$dst1, $dst2, $src1, $src2", []>, InstSize16;

}

// These patterns help generate better loads/stores when the immediate doesn't
// fit and ends up being and indexed load/store. For example:
//
//  li $a0, -300        ->  addiu $a0, $a2, -300
//  lbux $a1, $a0($a2)  ->  lbu $a1, 0($a0)
//
// On the left is what would be generated without these patterns. This results
// in two 32-bit instructions. While on the right, we have one 32-bit and one
// 16-bit instruction. It does require the right register, in order for second
// instruction to be 16-bit, but it's still better than always having two 32-bit
// instructions.
//
let AddedComplexity = 3 in {
def : NMPat<(i32 (extloadi8 (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LBU_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(i32 (zextloadi8 (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LBU_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(i32 (sextloadi8 (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LB_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(i32 (extloadi16 (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LHU_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(i32 (zextloadi16 (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LHU_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(i32 (sextloadi16 (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LH_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(i32 (load (add GPR32NM:$rs, immFitsAddiu32:$imm))),
            (LW_NM (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(truncstorei8 GPR32NM:$rt, (add GPR32NM:$rs, immFitsAddiu32:$imm)),
            (SB_NM GPR32NM:$rt, (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(truncstorei16 GPR32NM:$rt, (add GPR32NM:$rs, immFitsAddiu32:$imm)),
            (SH_NM GPR32NM:$rt, (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
def : NMPat<(store GPR32NM:$rt, (add GPR32NM:$rs, immFitsAddiu32:$imm)),
            (SW_NM GPR32NM:$rt, (ADDiu_NM GPR32NM:$rs, imm:$imm), 0)>;
} // AddedComplexity = 3

// Catching out-of-range immediate loads/stores.
def : NMPat<(i32 (extloadi8 GPR32NM:$rs)), (LBU_NM GPR32NM:$rs, 0)>;
def : NMPat<(i32 (zextloadi8 GPR32NM:$rs)), (LBU_NM GPR32NM:$rs, 0)>;
def : NMPat<(i32 (sextloadi8 GPR32NM:$rs)), (LB_NM GPR32NM:$rs, 0)>;
def : NMPat<(i32 (extloadi16 GPR32NM:$rs)), (LHU_NM GPR32NM:$rs, 0)>;
def : NMPat<(i32 (zextloadi16 GPR32NM:$rs)), (LHU_NM GPR32NM:$rs, 0)>;
def : NMPat<(i32 (sextloadi16 GPR32NM:$rs)), (LH_NM GPR32NM:$rs, 0)>;
def : NMPat<(i32 (load GPR32NM:$rs)), (LW_NM GPR32NM:$rs, 0)>;
def : NMPat<(truncstorei8 GPR32NM:$rt, GPR32NM:$rs),
            (SB_NM GPR32NM:$rt, GPR32NM:$rs, 0)>;
def : NMPat<(truncstorei16 GPR32NM:$rt, GPR32NM:$rs),
            (SH_NM GPR32NM:$rt, GPR32NM:$rs, 0)>;
def : NMPat<(store GPR32NM:$rt, GPR32NM:$rs),
            (SW_NM GPR32NM:$rt, GPR32NM:$rs, 0)>;

// Any-extending loads
def : NMPat<(i32 (extloadi8 addruimm12:$addr)), (LBU_NM addruimm12:$addr)>;
def : NMPat<(i32 (extloadi8 addrsimm9:$addr)), (LBUs9_NM addrsimm9:$addr)>;
def : NMPat<(i32 (extloadi8 addrindexed:$addr)), (LBUX_NM addrindexed:$addr)>;
def : NMPat<(i32 (extloadi16 addruimm12:$addr)), (LHU_NM addruimm12:$addr)>;
def : NMPat<(i32 (extloadi16 addrsimm9:$addr)), (LHUs9_NM addrsimm9:$addr)>;
def : NMPat<(i32 (extloadi16 addrindexedlsl1:$addr)),
            (LHUXS_NM addrindexedlsl1:$addr)>;
def : NMPat<(i32 (extloadi16 addrindexed:$addr)), (LHUX_NM addrindexed:$addr)>;

// Catching out-of-range immediate unaligned loads/stores.
def : NMPat<(i32 (NMUnalignedLW GPR32NM:$rs, GPR32NM:$src)),
            (UALW_NM GPR32NM:$rs, 0, GPR32NM:$src)>;
def : NMPat<(NMUnalignedSW GPR32NM:$rt, GPR32NM:$rs),
            (UASW_NM GPR32NM:$rt, GPR32NM:$rs, 0)>;
def : NMPat<(i32 (NMUnalignedLH GPR32NM:$rs, GPR32NM:$src)),
            (UALH_NM GPR32NM:$rs, 0, GPR32NM:$src)>;
def : NMPat<(NMUnalignedSH GPR32NM:$rt, GPR32NM:$rs),
            (UASH_NM GPR32NM:$rt, GPR32NM:$rs, 0)>;

// GP-relative load.
def : NMPat<(i32 (load (add GP_NM, (MipsGPRel tglobaladdr:$in)))),
            (LWGP_NM GP_NM, tglobaladdr:$in)>;
def : NMPat<(add GP_NM, (MipsGPRel tglobaladdr:$in)),
            (ADDiu_NM GP_NM, tglobaladdr:$in)>;

// GP-relative address

def alignedglobaladdr : PatFrag<(ops),
                                (tglobaladdr),
  [{ // Only match if aligned to at least word size
      Align A = N->getGlobal()->getPointerAlignment(MF->getDataLayout());
      return commonAlignment(A, 4).value() == 4;
    }]>;

def : NMPat<(MipsFullAddr alignedglobaladdr:$in),
            (LA_NM  alignedglobaladdr:$in)>;

def : NMPat<(MipsFullAddr tglobaladdr:$in),
            (LAGPB_NM tglobaladdr:$in)>;


// Atomic load patterns.
def : NMPat<(atomic_load_8 addr:$a), (LB_NM addr:$a)>;
def : NMPat<(atomic_load_16 addr:$a), (LH_NM addr:$a)>;
def : NMPat<(atomic_load_32 addr:$a), (LW_NM addr:$a)>;

// Atomic store patterns.
def : NMPat<(atomic_store_8 addr:$a, GPR32:$v), (SB_NM GPR32:$v, addr:$a)>;
def : NMPat<(atomic_store_16 addr:$a, GPR32:$v), (SH_NM GPR32:$v, addr:$a)>;
def : NMPat<(atomic_store_32 addr:$a, GPR32:$v), (SW_NM GPR32:$v, addr:$a)>;

// Conditional Moves
def MOVZ_NM : InstNM<(outs GPR32NMOpnd:$rd),
                     (ins GPR32NMOpnd:$rs, GPR32NMOpnd:$rt, GPR32NMOpnd:$F),
                     "movz\t$rd, $rs, $rt",
                     []>, InstSize32 {
  let Constraints = "$F = $rd";
}

def MOVN_NM : InstNM<(outs GPR32NMOpnd:$rd),
                     (ins GPR32NMOpnd:$rs, GPR32NMOpnd:$rt, GPR32NMOpnd:$F),
                     "movn\t$rd, $rs, $rt",
                     []>, InstSize32 {
    let Constraints = "$F = $rd";
}

multiclass MovzPats2NM<RegisterClass CRC, RegisterClass DRC,
                     Instruction MOVZInst, Instruction XORiOp> {
  def : NMPat<(select (i32 (seteq CRC:$lhs, imm32ZExt12:$uimm12_nm)), DRC:$T,
                      DRC:$F),
              (MOVZInst DRC:$T, (XORiOp CRC:$lhs, imm32ZExt12:$uimm12_nm),
                        DRC:$F)>;
}

multiclass MovzPats0NM<RegisterClass CRC, RegisterClass DRC,
                       Instruction MOVZInst, Instruction SLTOp,
                       Instruction SLTuOp, Instruction SLTiOp,
                       Instruction SLTiuOp> {
  def : NMPat<(select (i32 (setge CRC:$lhs, CRC:$rhs)), DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTOp CRC:$lhs, CRC:$rhs), DRC:$F)>;
  def : NMPat<(select (i32 (setuge CRC:$lhs, CRC:$rhs)), DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTuOp CRC:$lhs, CRC:$rhs), DRC:$F)>;
  def : NMPat<(select (i32 (setge CRC:$lhs, imm32ZExt12:$rhs)), DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTiOp CRC:$lhs, imm32ZExt12:$rhs), DRC:$F)>;
  def : NMPat<(select (i32 (setuge CRC:$lh, imm32ZExt12:$rh)), DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTiuOp CRC:$lh, imm32ZExt12:$rh), DRC:$F)>;
  def : NMPat<(select (i32 (setle CRC:$lhs, CRC:$rhs)), DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTOp CRC:$rhs, CRC:$lhs), DRC:$F)>;
  def : NMPat<(select (i32 (setule CRC:$lhs, CRC:$rhs)), DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTuOp CRC:$rhs, CRC:$lhs), DRC:$F)>;
  def : NMPat<(select (i32 (setgt CRC:$lhs, immZExt12Plus1:$rhs)),
                      DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTiOp CRC:$lhs, (Plus1 imm:$rhs)), DRC:$F)>;
  def : NMPat<(select (i32 (setugt CRC:$lhs, immZExt12Plus1:$rhs)),
                      DRC:$T, DRC:$F),
              (MOVZInst DRC:$T, (SLTiuOp CRC:$lhs, (Plus1 imm:$rhs)), DRC:$F)>;
}

// Use MIPS conditional instruction definitions
defm : MovzPats0NM<GPR32NM, GPR32NM, MOVZ_NM, SLT_NM, SLTU_NM, SLTI_NM,
                   SLTIU_NM>;
defm : MovzPats1<GPR32NM, GPR32NM, MOVZ_NM, XOR_NM>, ISA_NANOMIPS;
defm : MovzPats2NM<GPR32NM, GPR32NM, MOVZ_NM, XORI_NM>;
defm : MovnPats<GPR32NM, GPR32NM, MOVN_NM, XOR_NM>, ISA_NANOMIPS;
