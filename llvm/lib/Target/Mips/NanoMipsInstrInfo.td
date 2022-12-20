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
def imm32Neg12  : IntImmLeaf<i32, [{ return isInt<12>(Imm.getSExtValue()) && Imm.getSExtValue() < 0; }]>;
// True if (N + 1) fits in 12-bit field.
def immZExt12Plus1 : PatLeaf<(imm), [{
  return isUInt<13>(N->getZExtValue()) && isUInt<12>(N->getZExtValue() + 1);
}]>;
def immZExt7Plus1 : PatLeaf<(imm), [{
  return isUInt<8>(N->getZExtValue()) && isUInt<7>(N->getZExtValue() + 1);
}]>;
// Immediate range for signed 12-bit
def imm32SExt12OrZExt16 : IntImmLeaf<i32, [{ return isInt<12>(Imm.getSExtValue())
                                           || isUInt<16>(Imm.getZExtValue()); }]>;
// Immediate range for signed 20-bit upper part
def imm32SExt20s12 : IntImmLeaf<i32, [{ return isInt<32>(Imm.getSExtValue())
                                       && (Imm.getZExtValue() % 4096 == 0); }]>;


class ConstantSImmRangeAsmOperandClass<int Bottom, int Top,
                                       list<AsmOperandClass> Supers = []>
    : AsmOperandClass {
  let Name = "ConstantNegImmRange" # Bottom # "_" # Top;
  let RenderMethod = "addSImmOperands<" # 12 # ">";
  let PredicateMethod = "isConstantNegImmRange<" # Bottom # ", " # Top # ">";
  let SuperClasses = Supers;
  let DiagnosticType = "SImmRange" # Bottom # "_" # Top;
}

class NegImmAsmOperandClass<int Bits, list<AsmOperandClass> Supers = []>
    : AsmOperandClass {
  let Name = "NegImm" # Bits;
  let RenderMethod = "addSImmOperands<" # Bits # ">";
  let PredicateMethod = "isNegImm<" # Bits # ">";
  let SuperClasses = Supers;
  let DiagnosticType = "SImm" # Bits;
}

def UImm12AsmOperandClass : UImmAsmOperandClass<12, []>;
def UImm5AsmOperandClass : UImmAsmOperandClass<5, [UImm12AsmOperandClass]>;
def SImm12AsmOperandClass : SImmAsmOperandClass<12, []>;
def NImm12AsmOperandClass : NegImmAsmOperandClass<12, []>;
def NaImm12AsmOperandClass : ConstantSImmRangeAsmOperandClass<4095, 1, []>;
def UImm3Plus1AsmOperandClass :
  ConstantUImmAsmOperandClass<3, [UImm5AsmOperandClass], 1>;

class SImmScaledAsmOperandClass<int Bits, int Align, list<AsmOperandClass> Supers = []>
    : AsmOperandClass{
  let Name = "SImm" # Bits # "s" # Align;
  let RenderMethod = "addSImmOperands<32>";
  let PredicateMethod = "isSImm<" # Bits # ">";
  let SuperClasses = Supers;
  let DiagnosticType = "SImm" # Bits # "s" # Align;
}

class SymAsmOperandClass<string Type = "">
    : AsmOperandClass{
  let Name = "Sym32" # Type ;
  let DiagnosticType = "Sym32" # Type;
  let PredicateMethod = "isSym32" # Type;
}

def SymAsmOperandAbs : SymAsmOperandClass;
def SymAsmOperandPCRel : SymAsmOperandClass<"PCRel">;
def SymAsmOperandGPRel : SymAsmOperandClass<"GPRel">;

def SImm32S12AsmOperandClass : SImmScaledAsmOperandClass<20, 12, []>;

class NMMemGPAsmOperand<int Bits, int Align = 0, list<AsmOperandClass> Supers = [MipsMemAsmOperand]>
    : MipsMemSimmAsmOperand<Bits> {
  let Name = "NMMemGP" # Bits # "s" # Align;
  let RenderMethod = "addMemOperands";
  let ParserMethod = "parseMemOperand";
  let SuperClasses = Supers;  
  let PredicateMethod = "isMemWithUimmOffsetGP<" # Bits # "," # Align # ">";
}

class NMMemSPAsmOperand<int Bits, int Align>
    : AsmOperandClass {
  let Name = "NMMemSP" # Bits # "s" # Align;
  let RenderMethod = "addMemOperands";
  let PredicateMethod = "isMemWithUimmOffsetSP<" # Bits # "," # Align # ">";
}

def NMJumpTargetAsmOperand : AsmOperandClass {
  let Name = "JumpTargetNM";
  let ParserMethod = "parseJumpTarget";
  let PredicateMethod = "isImm";
  let RenderMethod = "addImmOperands";
}

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
def nimm12_nm : Operand<i32> {
  let PrintMethod = "printUImm<12>";
  let ParserMatchClass = !cast<AsmOperandClass>("NaImm12AsmOperandClass");
}
def uimm16_nm : Operand<i32> {
  let PrintMethod = "printUImm<16>";
  let ParserMatchClass = !cast<AsmOperandClass>("SImm16AsmOperandClass");
}

def mem_nms9 : mem_generic {
  let EncoderMethod = "getMemEncodingNMImm9";
  let ParserMatchClass = MipsMemSimmAsmOperand<9>;
}

def mem_nmu12 : mem_generic {
  let EncoderMethod = "getMemEncodingNMImm12";
  let ParserMatchClass = MipsMemUimmAsmOperand<12>;
}

def mem_nmpcrel : mem_generic {
  let EncoderMethod = "getMemEncodingNMImm9";
  let ParserMatchClass = MipsMemSimmAsmOperand<9>;
}

def mem_nmrx : mem_generic {
  let EncoderMethod = "getMemEncodingNMRX";
  let ParserMatchClass = MipsMemRxAsmOperand;
}

def mem_nm6s2 : mem_generic {
  let EncoderMethod = "getMemEncodingNMImm6S2";
  let ParserMatchClass = MipsMemUimmAsmOperand<4,2>;
}

def mem_nm3s1 : mem_generic {
  let EncoderMethod = "getMemEncodingNMImm3S1";
  let ParserMatchClass = MipsMemUimmAsmOperand<2,1>;
}

def mem_nm2 : mem_generic {
  let EncoderMethod = "getMemEncodingNMImm2";
  let ParserMatchClass = MipsMemUimmAsmOperand<2>;
}

def mem_nm_gp19s2 : mem_generic {
  let EncoderMethod = "getMemEncodingNMGP";
  let ParserMatchClass = NMMemGPAsmOperand<21,4>;
  let OperandNamespace = "NanoMips";
  let OperandType = "OPERAND_NM_GPREL21";
}

def mem_nm_gp18 : mem_generic {
  let EncoderMethod = "getMemEncodingNMGP";
  let ParserMatchClass = NMMemGPAsmOperand<18,1>;
  let OperandNamespace = "NanoMips";
  let OperandType = "OPERAND_NM_GPREL18";
}

def mem_nm_gp17s1 : mem_generic {
  let EncoderMethod = "getMemEncodingNMGP";
  let ParserMatchClass = NMMemGPAsmOperand<18,2>;
  let OperandNamespace = "NanoMips";
  let OperandType = "OPERAND_NM_GPREL18";
}

def mem_nm_gp7s2 : mem_generic {
  let EncoderMethod = "getMemEncodingNMGP";
  let ParserMatchClass = NMMemGPAsmOperand<9,4>;
  let OperandNamespace = "NanoMips";
  let OperandType = "OPERAND_NM_GPREL9";
}

def mem_nm_sp5s2 : mem_generic {
  let EncoderMethod = "getMemEncodingNMSP";
  let ParserMatchClass = NMMemSPAsmOperand<7,4>;
  let OperandNamespace = "NanoMips";
  let OperandType = "OPERAND_NM_SPREL7";
}

foreach I = {4, 7, 10, 11, 14, 25} in
  def brtarget # I # _nm : Operand<OtherVT> {
     let EncoderMethod = "getBranchTarget" # I # "OpValueNM";
     let OperandType   = "OPERAND_PCREL";
     let DecoderMethod = "DecodeBranchTargetNM";
     let ParserMatchClass = NMJumpTargetAsmOperand;
  }

foreach I = {10, 25} in
  def calltarget # I # _nm : Operand<iPTR> {
    let EncoderMethod = "getBranchTarget" # I # "OpValueNM";
    let ParserMatchClass = NMJumpTargetAsmOperand;
  }

def jmptarget_nm   : Operand<OtherVT> {
  let EncoderMethod = "getBranchTarget25OpValueNM";
  let ParserMatchClass = NMJumpTargetAsmOperand;
}

def simm32s12_nm : Operand<i32> {
//  let EncoderMethod = "getSImm20Lsl12Encoding";
  let PrintMethod = "printUImm<20>";
  let ParserMatchClass = SImmAsmOperandClass<20, []>;
}

def sym32_pc_nm : Operand<iPTRAny> {
  let EncoderMethod = "getSymPCRel";
  let ParserMatchClass = SymAsmOperandPCRel;
}

def sym32_gp_nm : Operand<iPTRAny> {
  let EncoderMethod = "getSymGPRel";
  let ParserMatchClass = SymAsmOperandGPRel;
}

def sym32_abs_nm : Operand<iPTRAny> {
  let EncoderMethod = "getSymAbs";
  let ParserMatchClass = SymAsmOperandAbs;
}

def simm32power2 : IntImmLeaf<i32, [{ return isPowerOf2_32(Imm.getSExtValue()); }]>;

def uimm16_simm12 : Operand<i32>;

def addrsimm9 : ComplexPattern<iPTR, 2, "selectIntAddrSImm9", [frameindex]>;
def addruimm12 : ComplexPattern<iPTR, 2, "selectIntAddrUImm12", [frameindex]>;
def addrindexed : ComplexPattern<iPTR, 2, "selectIntAddrIndexed", [frameindex]>;
def addrindexedlsl1 : ComplexPattern<iPTR, 2, "selectIntAddrIndexedLsl1", [frameindex]>;
def addrindexedlsl2 : ComplexPattern<iPTR, 2, "selectIntAddrIndexedLsl2", []>;
def addruimm6s2 : ComplexPattern<iPTR, 2, "selectIntAddrUImm6s2", [frameindex]>;
def addruimm3s1 : ComplexPattern<iPTR, 2, "selectIntAddrUImm3s1", [frameindex]>;
def addruimm2 : ComplexPattern<iPTR, 2, "selectIntAddrUImm2", [frameindex]>;
def addrgp19s2 : ComplexPattern<iPTR, 2, "selectIntAddrUImm19s2", [frameindex]>;
def addrgp18 : ComplexPattern<iPTR, 2, "selectIntAddrUImm18", [frameindex]>;
def addrgp17s1 : ComplexPattern<iPTR, 2, "selectIntAddrUImm17s1", [frameindex]>;
def addrgp7s2 : ComplexPattern<iPTR, 2, "selectIntAddrUImm7s2", [frameindex]>;
def addrsp5s2 : ComplexPattern<iPTR, 2, "selectIntAddrUImm5s2", [frameindex]>;
def addrpcrel : ComplexPattern<iPTR, 2, "selectAddrSym", [frameindex]>;
def addrgprel : ComplexPattern<iPTR, 2, "selectAddrSym", [frameindex]>;

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

class _Pool_P_BR12<bits<3> psel> : _Pool_P32<0b10010> {
  let Inst{29} = psel{2};
  let Inst{15...14} = psel{1...0};
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

class _Pool_PP_LSX<bit scaled, bits<4> isel> : _Pool_POOL32A7<0b000> {
  let Inst{6} = scaled;
  let Inst{10...7} = isel;
}

// TODO  BC_32 : _Pool_P_BAL<0b0>

// 16-bit arithmetic and logical instructions with 4x4 register operands, P16_4X4
class Arith4x4_Desc<string opstr, RegisterOperand RO,
			SDPatternOperator OpNode = null_frag>:
    InstNM<(outs RO:$dst), (ins RO:$rs, RO:$rt),
	!strconcat(opstr, "\t$dst, $rs, $rt"),
	   [(set RO:$dst, (OpNode RO:$rs, RO:$rt))]> {
  let Constraints = "$rt = $dst";
  Format Form = FrmR;
}

class Arith4x4_Enc<bits<2> isel>:  _Pool_P16_4X4<isel>;

// 32-bit arithmetic and logical instructions with 3 register operands.

class ArithLogicR32_Desc<string opstr, RegisterOperand RO,
		    SDPatternOperator OpNode = null_frag>:
  InstNM<(outs RO:$rd), (ins RO:$rs, RO:$rt),
	 !strconcat(opstr, "\t$rd, $rs, $rt"),
	 [(set RO:$rd, (OpNode RO:$rs, RO:$rt))]>;

class ArithLogicR32_Enc<bits<6> psel>: _Pool_POOL32A0_0<psel> {
  bits<5> rd;
  bits<5> rs;
  bits<5> rt;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{15...11} = rd;
}

// 16-bit arithmetic and logical instructions with 2 register operands, POOL16C_0
class ArithLogicR16_Desc<string opstr, RegisterOperand RO,
		    SDPatternOperator OpNode = null_frag>:
    InstNM<(outs RO:$dst), (ins RO:$rs, RO:$rt),
	!strconcat(opstr, "\t$dst, $rs, $rt"),
	   [(set RO:$dst, (OpNode RO:$rs, RO:$rt))]> {
  let Constraints = "$dst = $rt";
}

class ArithLogicR16U_Desc<string opstr, RegisterOperand RO,
		    		 SDPatternOperator OpNode = null_frag>:
    InstNM<(outs RO:$rt), (ins RO:$rs),
	!strconcat(opstr, "\t$rt, $rs"),
	   [(set RO:$rt, (OpNode RO:$rs))]> {
}

class ArithLogicR16_Enc<bits<2> isel>: _Pool_POOL16C_00<isel> {
  bits<3> rs;
  bits<3> rt;
  let Inst{9...7} = rt;
  let Inst{6...4} = rs;
}

// 16-bit arithmetic instructions with 2 register operands, POOL16C_0
class AddSubR16_Desc<string opstr, RegisterOperand RO,
		    SDPatternOperator OpNode = null_frag>:
    InstNM<(outs RO:$rd), (ins RO:$rs, RO:$rt), !strconcat(opstr, "\t$rd, $rs, $rt"),
	   [(set RO:$rd, (OpNode RO:$rs, RO:$rt))]>;

class AddSubR16_Enc<bits<1> isel>: _Pool_P16_ADDU<isel> {
  bits<3> rd;
  bits<3> rs;
  bits<3> rt;
  let Inst{15-10} = 0b101100;
  let Inst{9...7} = rt;
  let Inst{6...4} = rs;
  let Inst{3...1} = rd;
  let Inst{0} = 0;
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
  bits<16> imm;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{15...0} = imm;
}

class LoadUpperI32<string opstr, Operand Od, RegisterOperand RO,
		   SDPatternOperator imm_type = null_frag,
		   SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>, _Pool_P32<0b00000> {
  bits<5> rt;
  bits<5> rs;
  bits<16> imm;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{15...0} = imm;
}

class DivMod<string opstr, SDPatternOperator OpNode = null_frag> :
    ArithLogicR32_Desc<opstr, GPR32NMOpnd, OpNode> {
  // Need to insert TEQ, because DIV(U)/MOD(U) don't trap on division by zero.
  bit usesCustomInserter = 1;
}

class CondLogicI32_Desc<string opstr, Operand Od, RegisterOperand RO,
                          SDPatternOperator imm_type = null_frag,
			  SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>;

class CondLogicI32_Enc<bits<4> psel> : _Pool_P_U12<psel> {
  bits<5> rt;
  bits<5> rs;
  bits<12> imm;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{11...0} = imm;
}

class ShiftI32_Desc<string opstr, Operand Od, RegisterOperand RO,
                    SDPatternOperator imm_type = null_frag,
                    SDPatternOperator OpNode = null_frag> :
  ArithLogicINM<opstr, Od, RO, imm_type, OpNode>;

class ShiftI32_Enc<bits<4> psel> : _Pool_P_SHIFT<psel> {
  bits<5> rt;
  bits<5> rs;
  bits<5> imm;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{4...0} = imm;
}

class ExtBaseNM<RegisterOperand RO = GPR32NMOpnd> :
  InstNM<(outs RO:$rt), (ins RO:$rs, uimm5:$pos, uimm5_plus1:$size),
         "ext\t$rt, $rs, $pos, $size",
         [(set RO:$rt, (MipsExt RO:$rs, immZExt5:$pos, immZExt5Plus1:$size))],
         II_EXT>;

class InsBaseNM<RegisterOperand RO = GPR32NMOpnd> :
  InstNM<(outs RO:$rt),
         (ins RO:$rs, uimm5:$pos, uimm5_inssize_plus1:$size, RO:$src),
         "ins \t$rt, $rs, $pos, $size",
         [(set RO:$rt,
               (MipsIns RO:$rs, immZExt5:$pos, immZExt5Plus1:$size, RO:$src))],
         II_INS>{
  let Constraints = "$src = $rt";
}

class ExtInsBase_Enc<bits<4> isel> : _Pool_P_EXT_INS<isel> {
  bits<5> rt;
  bits<5> rs;
  bits<5> pos;
  bits<5> size;
  
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{4...0} = pos;
  let Inst{10...6} = size;
}

class Trap_Desc<string opstr, RegisterOperand RO, Operand ImmOp> :
  InstNM<(outs), (ins RO:$rs, RO:$rt, ImmOp:$imm),
         !strconcat(opstr, "\t$rt, $rs, $imm"), []> {
  let hasSideEffects = 1;
  let isCTI = 1;
}

class Trap_Enc<bits<1> isel> : _Pool_P_TRAP<isel> {
  bits<5> rt;
  bits<5> rs;
  bits<5> imm;
  let Inst{25...21} = rt;
  let Inst{20...16} = rs;
  let Inst{15...11} = imm;
}

// Instructions with 1 register (dest) and 1 immediate operand.
class RegImmNM<string opstr, Operand Od, RegisterOperand RO,
               SDPatternOperator imm_type = null_frag,
               SDPatternOperator OpNode = null_frag> :
  InstNM<(outs RO:$rt), (ins Od:$imm), !strconcat(opstr, "\t$rt, $imm"),
         [(set RO:$rt, (OpNode imm_type:$imm))]>;

class RegImm48_Desc<string opstr, Operand Od, RegisterOperand RO,
               SDPatternOperator imm_type = null_frag,
               SDPatternOperator OpNode = null_frag> :
  InstNM<(outs RO:$rt), (ins Od:$imm), !strconcat(opstr, "\t$rt, $imm"),
         [(set RO:$rt, (OpNode imm_type:$imm))]>;

class RegImm48_Enc<bits<5> isel> : _Pool_P48I<isel> {
  bits<5> rt;
  bits<32> imm;
  let Inst{41...37} = rt;
  let Inst{31...16} = imm{15...0};
  let Inst{15...0} = imm{31...16};
}

class LSMem_S9_Enc<bits<3> psel, bits<4> isel> : _Pool_P_LS_S9<psel>
{
  bits<5> rt;
  bits<14> addr;
  bits<5> base = addr{13...9};
  bits<9> offset = addr{8...0};
  let Inst{25...21} = rt;
  let Inst{20...16} = base;
  let Inst{14...11} = isel;
  let Inst{15} = offset{8};
  let Inst{7...0} = offset{7...0};
}

class LSMem_S9_Mult_Enc<bits<4> isel> : _Pool_P_LS_S9<isel{2...0}>
{
  bits<5> rt;
  bits<14> addr;
  bits<5> base = addr{13...9};
  bits<9> offset = addr{8...0};
  bits<3> count;
  let Inst{25...21} = rt;
  let Inst{20...16} = base;
  let Inst{11} = isel{3};
  let Inst{15} = offset{8};
  let Inst{7...0} = offset{7...0};
  let Inst{14...12} = count;
}

class LSMem_U12_Enc<bits<4> isel> : _Pool_P_LS_U12<isel>
{
  bits<5> rt;
  bits<17> addr;
  bits<5> base = addr{16...12};
  bits<12> offset = addr{11...0};
  let Inst{25...21} = rt;
  let Inst{20...16} = base;
  let Inst{11...0} = offset;
}

class LSMemX_Enc<bit scaled, bits<4> isel> : _Pool_PP_LSX<scaled, isel>
{
  bits<5> rd;
  bits<5> index;
  bits<5> base;
  let Inst{25...21} = base;
  let Inst{20...16} = index;
  let Inst{15...11} = rd;
}

class LSMem16_Enc<bits<5> isel> : _Pool_P16<isel>
{
  bits<3> rt;
  bits<9> addr;
  bits<3> base = addr{8...6};
  bits<4> offset = addr{5...2};
  let Inst{9...7} = rt;
  let Inst{6...4} = base;
  let Inst{3...0} = offset;
}

class LSGPRegMem16_Enc<bits<5> isel> : _Pool_P16<isel>
{
  bits<3> rt;
  bits<9> addr;
  bits<7> offset = addr{8...2};
  let Inst{9...7} = rt;
  let Inst{6...0} = offset;
}

class LSSPRegMem16_Enc<bits<5> isel> : _Pool_P16<isel>
{
  bits<5> rt;
  bits<7> addr;
  bits<5> offset = addr{6...2};
  let Inst{9...5} = rt;
  let Inst{4...0} = offset;
}

class LHMem16_Enc<bits<2> isel> : _Pool_P16_LH<isel>
{
  bits<3> rt;
  bits<6> addr;
  bits<3> base = addr{5...3};
  bits<3> offset = addr{2...0};
  let Inst{9...7} = rt;
  let Inst{6...4} = base;
  let Inst{2...1} = offset{2...1};
}

class LBMem16_Enc<bits<2> isel> : _Pool_P16_LB<isel>
{
  bits<3> rt;
  bits<5> addr;
  bits<3> base = addr{4...2};
  bits<2> offset = addr{1...0};
  let Inst{9...7} = rt;
  let Inst{6...4} = base;
  let Inst{1...0} = offset{1...0};
}

class LSMemGP19S2_Enc<bits<2> isel> : _Pool_P_GP_W<isel>
{
  bits<5> rt;
  bits<21> addr;
  let Inst{25...21} = rt;
  let Inst{20...2} = addr{20...2};
}

class LSMemGP18_Enc<bits<3> isel> : _Pool_P_GP_BH<isel>
{
  bits<5> rt;
  bits<18> addr;
  let Inst{25...21} = rt;
  let Inst{17...0} = addr;
}

class LSMemGP17S1_Enc<bits<4> isel> : _Pool_P_GP_BH<isel{3...1}>
{
  bits<5> rt;
  bits<18> addr;
  let Inst{25...21} = rt;
  let Inst{17...1} = addr{17...1};
  let Inst{0} = isel{0};
}

class LoadMemoryNM<string opstr, DAGOperand MO,
                   SDPatternOperator OpNode = null_frag,
                   ComplexPattern Addr = addr,
                   InstrItinClass itin = NoItinerary> :
    InstNM<(outs GPR32NMOpnd:$rt), (ins MO:$addr), !strconcat(opstr, "\t$rt, $addr"),
           [(set GPR32NMOpnd:$rt, (OpNode Addr:$addr))],
           itin> {
  let DecoderMethod = "DecodeMem";
  let canFoldAsLoad = 1;
  let mayLoad = 1;
  string BaseOpcode = opstr;
}

class LoadMemoryX<string opstr, DAGOperand MO,
                   SDPatternOperator OpNode = null_frag,
                   ComplexPattern Addr = addr,
                   InstrItinClass itin = NoItinerary> :
  InstNM<(outs GPR32NMOpnd:$rd), (ins PtrRC:$base, PtrRC:$index),
         !strconcat(opstr, "\t$rd, ${index}(${base})"),
	 [],
	 itin> {
  let DecoderMethod = "DecodeMem";
  let canFoldAsLoad = 1;
  let mayLoad = 1;
  string BaseOpcode = opstr;
}

class StoreMemoryX<string opstr, DAGOperand MO,
                    SDPatternOperator OpNode = null_frag,
                    ComplexPattern Addr = addr,
                    InstrItinClass itin> :
    InstNM<(outs), (ins GPR32NMOpnd:$rd, PtrRC:$base, PtrRC:$index),
    		   !strconcat(opstr, "\t$rd, ${index}(${base})"),
           	   [],
           	   itin> {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
  string BaseOpcode = opstr;
}

class LoadMemoryNM16<string opstr, DAGOperand MO,
                    SDPatternOperator OpNode = null_frag,
                    ComplexPattern Addr = addr,
                    InstrItinClass itin = NoItinerary> :
    InstNM<(outs GPR3Opnd:$rt), (ins MO:$addr), !strconcat(opstr, "\t$rt, $addr"),
           [(set GPR3Opnd:$rt, (OpNode Addr:$addr))],
           itin> {
  let DecoderMethod = "DecodeMem";
  let canFoldAsLoad = 1;
  let mayLoad = 1;
  string BaseOpcode = opstr;
}

class StoreMemoryNM<string opstr, DAGOperand MO,
                    SDPatternOperator OpNode = null_frag,
                    ComplexPattern Addr = addr,
                    InstrItinClass itin> :
    InstNM<(outs), (ins GPR32NMOpnd:$rt, MO:$addr), !strconcat(opstr, "\t$rt, $addr"),
           [(OpNode GPR32NMOpnd:$rt, Addr:$addr)],
           itin> {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
  string BaseOpcode = opstr;
}

class StoreMemoryNM16<string opstr, DAGOperand MO,
                      SDPatternOperator OpNode = null_frag,
                      ComplexPattern Addr = addr,
                      InstrItinClass itin> :
    InstNM<(outs), (ins GPR3Opnd:$rt, MO:$addr), !strconcat(opstr, "\t$rt, $addr"),
           [(OpNode GPR3Opnd:$rt, Addr:$addr)],
           itin> {
  let DecoderMethod = "DecodeMem";
  let mayStore = 1;
  string BaseOpcode = opstr;
}

class Op48_Enc<bits<5> isel> : _Pool_P48I<isel> {
  bits<5> rt;
  bits<32> addr;
  let Inst{41...37} = rt;
  let Inst{31...16} = addr{15...0};
  let Inst{15...0} = addr{31...16};
}

class LoadPCBase<DAGOperand RO, DAGOperand MO, ComplexPattern Addr> :
    InstNM<(outs RO:$rt),
           (ins MO:$addr), "lwpc\t$rt, $addr", 
           [(set RO:$rt, (load Addr:$addr))],
           II_LW> {
  let mayLoad = 1;
}

class StorePCBase<DAGOperand RO, DAGOperand MO, ComplexPattern Addr> :
    InstNM<(outs),
           (ins RO:$rt, MO:$addr), "swpc\t$rt, $addr",
           [(store RO:$rt, Addr:$addr)],
	   II_SW> {
  let mayStore = 1;
}

class CallNM<string opstr,
             SDPatternOperator OpNode = null_frag,
             DAGOperand calltarget> :
  InstNM<(outs), (ins calltarget:$addr), !strconcat(opstr, "\t$addr"),
         [(OpNode tglobaladdr:$addr)]> {
  let DecoderMethod = "DecodeJumpTarget";
  let isCall = 1;
  let isCTI = 1;
  let Defs = [RA_NM];
}

class MoveBalcBase : InstNM<(outs GPR32NMOpnd:$rd),
                            (ins GPR32NMOpnd:$rt, calltarget25_nm:$addr),
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
    InstNM<(outs GPR32NMOpnd:$rt), (ins mem_nms9:$addr, uimm3plus1_nm:$count),
           !strconcat(opstr, "\t$rt, $addr, $count"), []> {
  let DecoderMethod = "DecodeMem";
  let mayLoad = 1;
}
class StoreMultipleNM<string opstr> :
    InstNM<(outs), (ins GPR32NMOpnd:$rt, mem_nms9:$addr, uimm3plus1_nm:$count),
           !strconcat(opstr, "\t$rt, $addr, $count"), []> {
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
    InstNM<(outs RO:$rt), (ins mem_nms9:$addr, RO:$src),
           !strconcat(opstr, "\t$rt, $addr"),
           [(set RO:$rt, (OpNode addrsimm9:$addr, RO:$src))]> {
  let DecoderMethod = "DecodeMem";
  string Constraints = "$src = $rt";
  let mayLoad = 1;
  let canFoldAsLoad = 1;
}

class UnalignedStore<string opstr, SDNode OpNode,
                     RegisterOperand RO = GPR32NMOpnd> :
    InstNM<(outs), (ins RO:$rt, mem_nms9:$addr),
           !strconcat(opstr, "\t$rt, $addr"),
           [(OpNode RO:$rt, addrsimm9:$addr)]> {
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

class LoadAddressPCRelNM<string opstr, RegisterOperand RO, DAGOperand MO, ComplexPattern Addr> :
  InstNM<(outs RO:$rt), (ins MO:$addr),
         !strconcat(opstr, "\t$rt, $addr"),
         [(set RO:$rt, Addr:$addr)]>;

class LoadAddressGPRelNM<string opstr, RegisterOperand RO, DAGOperand MO, ComplexPattern Addr> :
  InstNM<(outs RO:$rt), (ins MO:$addr),
         !strconcat(opstr, "\t$rt, $addr"),
         [(set RO:$rt, Addr:$addr)]>;

class LoadAddressAbsNM<string opstr, RegisterOperand RO, DAGOperand MO, ComplexPattern Addr> :
  InstNM<(outs RO:$rt), (ins MO:$addr),
         !strconcat(opstr, "\t$rt, $addr"),
         [(set RO:$rt, Addr:$addr)]>;

//===----------------------------------------------------------------------===//
//
// Instruction Definitions
//
//===----------------------------------------------------------------------===//


// _POOL32A0_0 pool of instructions.
def SLLV_NM  : ArithLogicR32_Desc<"sllv", GPR32NMOpnd, shl>,
	       ArithLogicR32_Enc<0b000010>;
def SRLV_NM  : ArithLogicR32_Desc<"srlv", GPR32NMOpnd, srl>,
	       ArithLogicR32_Enc<0b000110>;
def SRAV_NM  : ArithLogicR32_Desc<"srav", GPR32NMOpnd, sra>,
	       ArithLogicR32_Enc<0b001010>;
def ROTRV_NM : ArithLogicR32_Desc<"rotrv", GPR32NMOpnd, rotr>,
	       ArithLogicR32_Enc<0b001110>;
def ADD_NM   : ArithLogicR32_Desc<"add", GPR32NMOpnd>,
	       ArithLogicR32_Enc<0b001110>;
def ADDu_NM  : ArithLogicR32_Desc<"addu", GPR32NMOpnd, add>,
	       ArithLogicR32_Enc<0b010110>;
def SUB_NM   : ArithLogicR32_Desc<"sub", GPR32NMOpnd>,
	       ArithLogicR32_Enc<0b011010>;
def SUBu_NM  : ArithLogicR32_Desc<"subu", GPR32NMOpnd, sub>,
	       ArithLogicR32_Enc<0b011110>;
def AND_NM   : ArithLogicR32_Desc<"and", GPR32NMOpnd, and>,
    	       ArithLogicR32_Enc<0b100110>;
def OR_NM    : ArithLogicR32_Desc<"or", GPR32NMOpnd, or>,
	       ArithLogicR32_Enc<0b101010>;
def NOR_NM   : ArithLogicR32_Desc<"nor", GPR32NMOpnd>,
	       ArithLogicR32_Enc<0b101110>;
def XOR_NM   : ArithLogicR32_Desc<"xor", GPR32NMOpnd, xor>,
	       ArithLogicR32_Enc<0b110010>;
def SLT_NM   : ArithLogicR32_Desc<"slt", GPR32NMOpnd, setlt>,
	       ArithLogicR32_Enc<0b110110>;
def SLTU_NM  : ArithLogicR32_Desc<"sltu", GPR32NMOpnd, setult>,
	       ArithLogicR32_Enc<0b111010>;
def MUL_NM   : ArithLogicR32_Desc<"mul", GPR32NMOpnd, mul>,
	       ArithLogicR32_Enc<0b000011>;
def MUH_NM   : ArithLogicR32_Desc<"muh", GPR32NMOpnd, mulhs>,
	       ArithLogicR32_Enc<0b000111>;
def MULU_NM  : ArithLogicR32_Desc<"mulu", GPR32NMOpnd>,
	       ArithLogicR32_Enc<0b001011>;
def MUHU_NM  : ArithLogicR32_Desc<"muhu", GPR32NMOpnd, mulhu>,
	       ArithLogicR32_Enc<0b001111>;
def DIV_NM   : DivMod<"div", sdiv>,
	       ArithLogicR32_Enc<0b010011>;
def MOD_NM   : DivMod<"mod", srem>,
	       ArithLogicR32_Enc<0b010111>;
def DIVU_NM  : DivMod<"divu", udiv>,
	       ArithLogicR32_Enc<0b011011>;
def MODU_NM  : DivMod<"modu", urem>,
	       ArithLogicR32_Enc<0b011111>;

// 16-bit register operations
let FastISelShouldIgnore = 1 in {
def ADDu16_NM : AddSubR16_Desc<"addu", GPR3Opnd, add>,
    	      	AddSubR16_Enc<0b0>;
def SUBu16_NM  : AddSubR16_Desc<"subu", GPR3Opnd, sub>,
		 AddSubR16_Enc<0b1>;
def ADDu4x4_NM : Arith4x4_Desc<"addu", GPR4Opnd, add>,
		 Arith4x4_Enc<0b00>;
def MUL4x4_NM  : Arith4x4_Desc<"mul", GPR4Opnd, mul>,
    		  Arith4x4_Enc<0b01>;
}

// P.U12 pool of instructions
def ORI_NM   : CondLogicI32_Desc<"ori", uimm12_nm, GPR32NMOpnd, imm32ZExt12, or>,
	       CondLogicI32_Enc<0b0000>;
def XORI_NM  : CondLogicI32_Desc<"xori", uimm12_nm, GPR32NMOpnd, imm32ZExt12, xor>,
	       CondLogicI32_Enc<0b0001>;
def ANDI_NM  : CondLogicI32_Desc<"andi", uimm16, GPR32NMOpnd, imm32ZExt12ANDI, and>,
	       CondLogicI32_Enc<0b0010>;
def SLTI_NM  : CondLogicI32_Desc<"slti", uimm12_nm, GPR32NMOpnd, imm32ZExt12, setlt>,
	       CondLogicI32_Enc<0b0100>;
def SLTIU_NM : CondLogicI32_Desc<"sltiu", uimm12_nm, GPR32NMOpnd, imm32ZExt12, setult>,
	       CondLogicI32_Enc<0b0101>;
def SEQI_NM  : CondLogicI32_Desc<"seqi", uimm12_nm, GPR32NMOpnd, imm32ZExt12, seteq>,
	       CondLogicI32_Enc<0b0110>;

// P.SHIFT pool of instructions
def SLL_NM  : ShiftI32_Desc<"sll", uimm5_nm, GPR32NMOpnd, imm32ZExt5, shl>,
	      ShiftI32_Enc<0b0000>;
def SRL_NM  : ShiftI32_Desc<"srl", uimm5_nm, GPR32NMOpnd, imm32ZExt5, srl>,
	      ShiftI32_Enc<0b0010>;
def SRA_NM  : ShiftI32_Desc<"sra", uimm5_nm, GPR32NMOpnd, imm32ZExt5, sra>,
	      ShiftI32_Enc<0b0100>;
def ROTR_NM : ShiftI32_Desc<"rotr", uimm5_nm, GPR32NMOpnd, imm32ZExt5, rotr>,
	      ShiftI32_Enc<0b0110>;

def EXT_NM : ExtBaseNM, ExtInsBase_Enc<0b1111>;
def INS_NM : InsBaseNM, ExtInsBase_Enc<0b1110>;

def ADDiu_NM : AddiU32<"addiu", uimm16_simm12, GPR32NMOpnd,
                             imm32SExt12OrZExt16, add>;
def ADDIU48_NM : ArithLogicINM<"addiu", simm32_relaxed, GPR32NMOpnd,
                               imm32_NM, add>, Op48_Enc<0b00001>;

def ADDIUPC48_NM : LoadAddressPCRelNM<"addiu", GPR32NMOpnd, sym32_pc_nm,
                                      addrpcrel>, Op48_Enc<0b00011>;

def LSA_NM : LoadScaledAddressNM<"lsa", GPR32NMOpnd>;

def SEB_NM : SignExtInRegNM<"seb", i8, GPR32NMOpnd>;
def SEH_NM : SignExtInRegNM<"seh", i16, GPR32NMOpnd>;

def CLZ_NM : CountLeading0NM<"clz", GPR32NMOpnd>;
def CLO_NM : CountLeading1NM<"clo", GPR32NMOpnd>;

def BITREVW_NM : ReverseNM<"bitrevw", GPR32NMOpnd, bitreverse>;
def BYTEREVW_NM : ReverseNM<"byterevw", GPR32NMOpnd, bswap>;

// P.TRAP pool of instructions.
def TEQ_NM : Trap_Desc<"teq", GPR32NMOpnd, uimm5_nm>, Trap_Enc<0b0>;
def TNE_NM : Trap_Desc<"tne", GPR32NMOpnd, uimm5_nm>, Trap_Enc<0b1>;

def NOT_NM   : ArithLogicR16U_Desc<"not", GPR3Opnd, not>,
	       ArithLogicR16_Enc<0b00>;
def XOR16_NM : ArithLogicR16_Desc<"xor", GPR3Opnd>,
	       ArithLogicR16_Enc<0b01>;
def AND16_NM : ArithLogicR16_Desc<"and", GPR3Opnd>,
	       ArithLogicR16_Enc<0b10>;
def OR16_NM  : ArithLogicR16_Desc<"or	", GPR3Opnd>,
	       ArithLogicR16_Enc<0b11>;

def JRC_NM : IndirectBranchNM<"jrc", GPR32NMOpnd>;

def MOVEBALC_NM : MoveBalcBase;

let isReMaterializable = 1 in {
def Li_NM : LoadAddressAbsNM<"li", GPR32NMOpnd, sym32_abs_nm,
    	      		       addrpcrel>, Op48_Enc<0b00000>;
def LA_NM : RegImm48_Desc<"la", simm32_relaxed, GPR32NMOpnd>,
		Op48_Enc<0b00011>;

def LAGPB_NM : LoadAddressGPRelNM<"addiu", GPR32NMOpnd, sym32_gp_nm,
                                      addrgprel>, Op48_Enc<0b00010>;

} // isReMaterializable = 1


// Arithmetic and logical instructions with 2 register operands and immediate.
class LoadUpperINM<string opstr, Operand Od, RegisterOperand RO,
		   SDPatternOperator imm_type = null_frag,
		   SDPatternOperator OpNode = null_frag> :
  InstNM<(outs RO:$rt), (ins Od:$imm),
	 !strconcat(opstr, "\t$rt, $imm"),
	 [(set RO:$rt, (OpNode RO:$rs, imm_type:$imm))]> {
  let isReMaterializable = 1;
}

class LUI_Enc<bits<1> isel> : _Pool_P_LUI<isel> {
  bits<5> rt;
  bits<20> imm;
  let Inst{25...21} = rt;
  let Inst{20...12} = imm{8...0};
  let Inst{11...2} = imm{18...9};
  let Inst{0} = imm{19};
}

def LUI_NM : RegImmNM<"lui", simm32s12_nm, GPR32NMOpnd, imm32SExt20s12>, LUI_Enc<0b0>;

def ALUIPC_NM : RegImmNM<"aluipc", simm32s12_nm, GPR32NMOpnd, imm32SExt20s12>, LUI_Enc<0b1>;

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
    : InstNM<(outs), (ins RO:$rt, imm_type:$u, opnd:$offset),
             !strconcat(opstr, "\t$rt, $u, $offset"),
             [(brcond (i32 (cond_op RO:$rt, ImmOp:$u)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 0;
  bit isCTI = 1;
}

class CBranchZeroNM<string opstr, DAGOperand opnd, PatFrag cond_op,
                    RegisterOperand RO>
    : InstNM<(outs), (ins RO:$rs, opnd:$offset),
             !strconcat(opstr, "\t$rs, $offset"),
             [(brcond (i32 (cond_op RO:$rs, 0)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  bit isCTI = 1;
}

class CBranchBitNM<string opstr, DAGOperand opnd, PatFrag cond_op,
                   RegisterOperand RO,
                   Operand imm_type, SDPatternOperator ImmOp>
    : InstNM<(outs), (ins RO:$rt, imm_type:$u, opnd:$offset),
             !strconcat(opstr, "\t$rt, $u, $offset"),
        [(brcond (i32 (cond_op (and RO:$rt, (shl 1, ImmOp:$u)), 0)), bb:$offset)]> {
  let isBranch = 1;
  let isTerminator = 1;
  let hasDelaySlot = 0;
  bit isCTI = 1;
}

class BCBase<DAGOperand brtarget>
      : InstNM<(outs), (ins brtarget:$addr), "bc\t$addr",
	               [(br bb:$addr)], II_J> {
  let isTerminator = 1;
  let isBarrier = 1;
  let isBranch = 1;
  let isCTI = 1;
}

class BC32_Enc<bits<1> isel> : _Pool_P_BAL<isel>
{
  bits<26> addr;
  let Inst{24...0} = addr{25...1};
}

class BC16_Enc<bits<5> isel> : _Pool_P16<isel>
{
  bits<11> addr;
  let Inst{9...1} = addr{9...1};
  let Inst{0} = addr{10};
}

class B14_Enc<bits<3> isel> : _Pool_P_BR12<isel>
{
  bits<5> rt;
  bits<5> rs;
  bits<15> offset;
  let Inst{25...21} = rt;
  let Inst{20...16} = rt;
  let Inst{13...1} = offset{13...1};
  let Inst{0} =  offset{14};
}

class BZ16_Enc<bits<5> isel> : _Pool_P16<isel>
{
  bits<3> rt3;
  bits<5> rs;
  bits<8> offset;
  let Inst{9...7} = rt3;
  let Inst{6...1} = offset{6...1};
  let Inst{0} =  offset{7};
}

class BRI_Enc<bits<3> isel> : _Pool_P_BRI<isel>
{
  bits<5> rt;
  bits<7> u;
  bits<12> offset;
  let Inst{25...21} = rt;
  let Inst{17...11} = u;
  let Inst{10...1} = offset{10...1};
  let Inst{0} =  offset{11};
}

class BBit_Enc<bits<3> isel> : _Pool_P_BRI<isel>
{
  bits<5> rt;
  bits<6> u;
  bits<12> offset;
  let Inst{25...21} = rt;
  let Inst{16...11} = u;
  let Inst{10...1} = offset{10...1};
  let Inst{0} =  offset{11};
}

def BC_NM : BCBase<brtarget25_nm>, BC32_Enc<0b0>;
def BALC_NM : CallNM<"balc", MipsJmpLink, calltarget25_nm>, BC32_Enc<0b1>;
def BC16_NM : BCBase<brtarget10_nm>, BC16_Enc<0b00010>;
def BALC16_NM : CallNM<"balc", MipsJmpLink, calltarget10_nm>, BC16_Enc<0b00110>;

def : NMPat<(MipsJmpLink (i32 texternalsym:$dst)), (BALC_NM texternalsym:$dst)>;


def BEQC_NM : CBranchNM<"beqc", brtarget14_nm, seteq, GPR32NMOpnd>,
	      B14_Enc<0b000>;
def BGEC_NM : CBranchNM<"bgec", brtarget14_nm, setge, GPR32NMOpnd>,
	      B14_Enc<0b010>;
def BGEUC_NM : CBranchNM<"bgeuc", brtarget14_nm, setuge, GPR32NMOpnd>,
	       B14_Enc<0b011>;

def BNEC_NM : CBranchNM<"bnec", brtarget14_nm, setne, GPR32NMOpnd>,
	      B14_Enc<0b100>;
def BLTC_NM : CBranchNM<"bltc", brtarget14_nm, setlt, GPR32NMOpnd>,
	      B14_Enc<0b110>;
def BLTUC_NM : CBranchNM<"bltuc", brtarget14_nm, setult, GPR32NMOpnd>,
	       B14_Enc<0b111>;

def BEQZC_NM : CBranchZeroNM<"beqzc", brtarget7_nm, seteq, GPR32NMOpnd>,
	       BZ16_Enc<0b10010>;
def BNEZC_NM : CBranchZeroNM<"bnezc", brtarget7_nm, setne, GPR32NMOpnd>,
	       BZ16_Enc<0b10110>;

def BEQIC_NM : CBranchImmNM<"beqic", brtarget11_nm, seteq, GPR32NMOpnd, uimm7, immZExt7>,
	       BRI_Enc<0b000>;
def BGEIC_NM : CBranchImmNM<"bgeic", brtarget11_nm, setge, GPR32NMOpnd, uimm7, immZExt7>,
	       BRI_Enc<0b010>;
def BLTIC_NM : CBranchImmNM<"bltic", brtarget11_nm, setlt, GPR32NMOpnd, uimm7, immZExt7>,
	       BRI_Enc<0b110>;
def BNEIC_NM : CBranchImmNM<"bneic", brtarget11_nm, setne, GPR32NMOpnd, uimm7, immZExt7>,
	       BRI_Enc<0b100>;
def BGEIUC_NM : CBranchImmNM<"bgeiuc", brtarget11_nm, setuge, GPR32NMOpnd, uimm7, immZExt7>,
	        BRI_Enc<0b011>;
def BLTIUC_NM : CBranchImmNM<"bltiuc", brtarget11_nm, setult, GPR32NMOpnd, uimm7, immZExt7>,
	        BRI_Enc<0b111>;

// Bit-test branches
def BBNEZC_NM : CBranchBitNM<"bbnezc", brtarget11_nm, setne, GPR32NMOpnd, simm32, simm32power2>,
		BBit_Enc<0b001>;
def BBEQZC_NM : CBranchBitNM<"bbeqzc", brtarget11_nm, seteq, GPR32NMOpnd, simm32, simm32power2>,
		BBit_Enc<0b101>;

let isCodeGenOnly = 1, hasNoSchedulingInfo = 1,
    hasDelaySlot = 0 in {

// TODO: BBEQZ/BBNEZ bit-test conditional branch instructions

}

class TailCallBase : PseudoInstNM<(outs), (ins calltarget25_nm:$target), []>,
                     PseudoInstExpansion<(BC_NM brtarget25_nm:$target)> {
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

//def : NMPat<(MipsTailCall (i32 tglobaladdr:$dst)),
//            (TAILCALL_NM tglobaladdr:$dst)>;
//def : NMPat<(MipsTailCall (i32 texternalsym:$dst)),
//            (TAILCALL_NM texternalsym:$dst)>;

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
def LWSP16_NM : LoadMemoryNM16<"lw", mem_nm_sp5s2, load, addrsp5s2, II_LW>,
	        LSSPRegMem16_Enc<0b00101>;
def SWSP16_NM : StoreMemoryNM16<"sw", mem_nm_sp5s2, store, addrsp5s2, II_SW>,
	        LSSPRegMem16_Enc<0b10101>;
def LWGP16_NM : LoadMemoryNM16<"lw", mem_nm_gp7s2, load, addrgp7s2, II_LW>,
	        LSGPRegMem16_Enc<0b01001>;
def SWGP16_NM : StoreMemoryNM16<"sw", mem_nm_gp7s2, store, addrgp7s2, II_SW>,
	        LSGPRegMem16_Enc<0b11001>;

def LW16_NM : LoadMemoryNM16<"lw", mem_nm6s2, load, addruimm6s2, II_LW>,
    	      LSMem16_Enc<0b00001>;
def SW16_NM : StoreMemoryNM16<"sw", mem_nm6s2, store, addruimm6s2, II_SW>,
    	      LSMem16_Enc<0b10001>;
def LH16_NM : LoadMemoryNM16<"lh", mem_nm3s1, sextloadi16, addruimm3s1, II_LH>,
    	      LHMem16_Enc<0b00>;
def LHU16_NM : LoadMemoryNM16<"lhu", mem_nm3s1, zextloadi16, addruimm3s1, II_LH>,
    	      LHMem16_Enc<0b10>;
def SH16_NM : StoreMemoryNM16<"sh", mem_nm3s1, truncstorei16, addruimm3s1, II_SH>,
    	      LHMem16_Enc<0b01>;

def LB16_NM : LoadMemoryNM16<"lb", mem_nm2, sextloadi8, addruimm2, II_LB>,
    	      LBMem16_Enc<0b00>;
def LBU16_NM : LoadMemoryNM16<"lbu", mem_nm2, zextloadi8, addruimm2, II_LB>,
    	      LBMem16_Enc<0b10>;
def SB16_NM : StoreMemoryNM16<"sb", mem_nm2, truncstorei8, addruimm2, II_SB>,
    	      LHMem16_Enc<0b01>;

def LWGP_NM : LoadMemoryNM<"lw", mem_nm_gp19s2, load, addrgp19s2, II_LW>,
	      LSMemGP19S2_Enc<0b10>;
def SWGP_NM : StoreMemoryNM<"sw", mem_nm_gp19s2, store, addrgp19s2, II_SW>,
	      LSMemGP19S2_Enc<0b11>;

def LBGP_NM : LoadMemoryNM<"lb", mem_nm_gp18, sextloadi8, addrgp18, II_LB>,
	      LSMemGP18_Enc<0b000>;
def SBGP_NM : StoreMemoryNM<"sb", mem_nm_gp18, truncstorei8, addrgp18, II_SB>,
	      LSMemGP18_Enc<0b001>;
def LBUGP_NM : LoadMemoryNM<"lbu", mem_nm_gp18, zextloadi8, addrgp18, II_LB>,
	      LSMemGP18_Enc<0b010>;

def LHGP_NM : LoadMemoryNM<"lh", mem_nm_gp17s1, sextloadi16, addrgp17s1, II_LH>,
	      LSMemGP17S1_Enc<0b0000>;
def SHGP_NM : StoreMemoryNM<"sh", mem_nm_gp17s1, truncstorei16, addrgp17s1, II_SH>,
	      LSMemGP17S1_Enc<0b1010>;
def LHUGP_NM : LoadMemoryNM<"lhu", mem_nm_gp17s1, zextloadi16, addrgp17s1, II_LH>,
	      LSMemGP17S1_Enc<0b0001>;

// TODO: addruimm12 and addrsimm9 need to be looked into again. Currently
//       addruimm12 needs to come before addrsimm9, because addrsimm9 handles
//       loads/store that do not fit the offset. If we put the same handling in
//       addruimm12, this will cause addrsimm9 to never get selected.
def LB_NM : LoadMemoryNM<"lb", mem_nmu12, sextloadi8, addruimm12, II_LB>,
		LSMem_U12_Enc<0b0000>;
def SB_NM : StoreMemoryNM<"sb", mem_nmu12, truncstorei8, addruimm12, II_SB>,
		LSMem_U12_Enc<0b0001>;
def LH_NM : LoadMemoryNM<"lh", mem_nmu12, sextloadi16, addruimm12, II_LH>,
		LSMem_U12_Enc<0b0100>;
def SH_NM : StoreMemoryNM<"sh", mem_nmu12, truncstorei16, addruimm12, II_SH>,
		LSMem_U12_Enc<0b0101>;
def LW_NM : LoadMemoryNM<"lw", mem_nmu12, load, addruimm12, II_LW>,
    	      LSMem_U12_Enc<0b1000>;
def SW_NM : StoreMemoryNM<"sw", mem_nmu12, store, addruimm12, II_SW>,
    	      LSMem_U12_Enc<0b1001>;
def LBU_NM : LoadMemoryNM<"lbu", mem_nmu12, zextloadi8, addruimm12, II_LBU>,
		LSMem_U12_Enc<0b0010>;
def LHU_NM : LoadMemoryNM<"lhu", mem_nmu12, zextloadi16, addruimm12, II_LHU>,
		LSMem_U12_Enc<0b0110>;

def LBs9_NM : LoadMemoryNM<"lb", mem_nms9, sextloadi8, addrsimm9, II_LB>,
		LSMem_S9_Enc<0b000, 0b0000>;
def SBs9_NM : StoreMemoryNM<"sb", mem_nms9, truncstorei8, addrsimm9, II_SB>,
		LSMem_S9_Enc<0b000, 0b0001>;
def LHs9_NM : LoadMemoryNM<"lh", mem_nms9, sextloadi16, addrsimm9, II_LH>,
		LSMem_S9_Enc<0b000, 0b0100>;
def SHs9_NM : StoreMemoryNM<"sh", mem_nms9, truncstorei16, addrsimm9, II_SH>,
		LSMem_S9_Enc<0b000, 0b0101>;
def LWs9_NM : LoadMemoryNM<"lw", mem_nms9, load, addrsimm9, II_LW>,
	      LSMem_S9_Enc<0b000, 0b1000>;
def SWs9_NM : StoreMemoryNM<"sw", mem_nms9, store, addrsimm9, II_SW>,
	      LSMem_S9_Enc<0b000, 0b1001>;
def LBUs9_NM : LoadMemoryNM<"lbu", mem_nms9, zextloadi8, addrsimm9, II_LBU>,
		LSMem_S9_Enc<0b000, 0b0010>;
def LHUs9_NM : LoadMemoryNM<"lhu", mem_nms9, zextloadi16, addrsimm9, II_LHU>,
		LSMem_S9_Enc<0b000, 0b0110>;

def LBX_NM : LoadMemoryNM<"lbx", mem_nmrx, sextloadi8, addrindexed, II_LB>,
		LSMemX_Enc<0, 0b0000>;
def SBX_NM : StoreMemoryNM<"sbx", mem_nmrx, truncstorei8, addrindexed, II_SB>,
		LSMemX_Enc<0, 0b0001>;
def LHX_NM : LoadMemoryNM<"lhx", mem_nmrx, sextloadi16, addrindexed, II_LH>,
		LSMemX_Enc<0, 0b0100>;
def SHX_NM : StoreMemoryNM<"shx", mem_nmrx, truncstorei16, addrindexed, II_SH>,
		LSMemX_Enc<0, 0b0101>;
def LWX_NM : LoadMemoryX<"lwx", mem_nmrx, load, addrindexed, II_LW>,
		LSMemX_Enc<0, 0b1000>;
def SWX_NM : StoreMemoryNM<"swx", mem_nmrx, store, addrindexed, II_SW>,
		LSMemX_Enc<0, 0b1001>;
def LBUX_NM : LoadMemoryNM<"lbux", mem_nmrx, zextloadi8, addrindexed, II_LBU>,
		LSMemX_Enc<0, 0b0010>;
def LHUX_NM : LoadMemoryNM<"lhux", mem_nmrx, zextloadi16, addrindexed, II_LHU>,
		LSMemX_Enc<0, 0b0000>;

def LHXS_NM : LoadMemoryNM<"lhxs", mem_nmrx, sextloadi16, addrindexedlsl1, II_LH>,
		LSMemX_Enc<0b1, 0b0100>;
def SHXS_NM : StoreMemoryNM<"shxs", mem_nmrx, truncstorei16, addrindexedlsl1, II_SH>,
		LSMemX_Enc<0b1, 0b0101>;
def LHUXS_NM : LoadMemoryNM<"lhuxs", mem_nmrx, zextloadi16, addrindexedlsl1, II_LHU>,
		LSMemX_Enc<0b1, 0b0110>;
def LWXS_NM : LoadMemoryNM<"lwxs", mem_nmrx, load, addrindexedlsl2, II_LW>,
		LSMemX_Enc<0b1, 0b1000>;
def SWXS_NM : StoreMemoryNM<"swxs", mem_nmrx, store, addrindexedlsl2, II_SW>,
		LSMemX_Enc<0b1, 0b1001>;

def UALH_NM : UnalignedLoad<"ualh", NMUnalignedLH>, LSMem_S9_Enc<0b001, 0b0100>;
def UASH_NM : UnalignedStore<"uash", NMUnalignedSH>, LSMem_S9_Enc<0b001, 0b0101>;
def LWM_NM : LoadMultipleNM<"lwm">, LSMem_S9_Mult_Enc<0b0100>;
def UALWM_NM : LoadMultipleNM<"ualwm">, LSMem_S9_Mult_Enc<0b0101>;
def SWM_NM : StoreMultipleNM<"swm">, LSMem_S9_Mult_Enc<0b1100>;
def UASWM_NM : StoreMultipleNM<"uaswm">, LSMem_S9_Mult_Enc<0b1101>;

def UALW_NM : UnalignedLoad<"ualw", NMUnalignedLW>, LSMem_S9_Enc<0b101, 0b0000>;
def UASW_NM : UnalignedStore<"uasw", NMUnalignedSW>, LSMem_S9_Enc<0b101, 0b1000>;

//def CACHE_NM : LSMem_S9_Enc<0b001, 0b0111>;

def SWPC_NM : StorePCBase<GPR32NMOpnd, sym32_pc_nm, addrpcrel>, Op48_Enc<0b01011>;
def LWPC_NM : LoadPCBase<GPR32NMOpnd, sym32_pc_nm, addrpcrel>, Op48_Enc<0b01111>;

let isCodeGenOnly = 1 in {

// TODO: Halfword load/store is never selected, this needs to be looked into.

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
