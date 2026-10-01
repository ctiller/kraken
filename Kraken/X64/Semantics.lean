module

-- The reference semantics are taken from https://www.felixcloutier.com/x86/,
-- which itself is just extracted from https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html

import Kraken.Attribute
public import Kraken.Layout
public import Kraken.Mem
meta import Kraken.Mem
public import Kraken.X64.Syntax
meta import Kraken.X64.Syntax
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

@[expose] public section

-- injective coercions only
attribute [-instance] BitVec.instNatCast
attribute [-instance] BitVec.instIntCast
instance : Coe Bool Nat where coe := Bool.toNat

namespace BitVec
def unsigned {w} (x : BitVec w) : Int := x.toNat
def signed {w} (x : BitVec w) : Int := x.toInt
@[kstep] def take {w} (x : BitVec w) (n : Nat) : BitVec n := x.extractLsb' 0 n
@[kstep] def drop {w} (x : BitVec w) (n : Nat) : BitVec (w - n) := x.extractLsb' n (w-n)
end BitVec
attribute [kstep]
  BitVec.extractLsb'
  BitVec.ofInt_add
  BitVec.ofInt_toInt
  BitVec.signed
  BitVec.truncate

namespace Reg
@[kstep] def base {w} (r : Reg w) : Reg64 := match r with
  | .low r _ => r
  | .ah => .rax | .bh => .rbx | .ch => .rcx | .dh => .rdx

@[kstep] def offset {w} (r : Reg w) : Nat := match r with
  | .low _ _ => 0
  | .ah | .bh | .ch | .dh => 8
end Reg

namespace AvxReg
def base {w} (r : AvxReg w) : RegMm := match r with
  | .xmm r => r
  | .ymm r => r
  | .zmm r => r
end AvxReg

structure Reg64s where
  rax : UInt64 := 0
  rbx : UInt64 := 0
  rcx : UInt64 := 0
  rdx : UInt64 := 0
  rsi : UInt64 := 0
  rdi : UInt64 := 0
  rsp : UInt64 := 0
  rbp : UInt64 := 0
  r8  : UInt64 := 0
  r9  : UInt64 := 0
  r10 : UInt64 := 0
  r11 : UInt64 := 0
  r12 : UInt64 := 0
  r13 : UInt64 := 0
  r14 : UInt64 := 0
  r15 : UInt64 := 0
  deriving Repr, BEq, DecidableEq, Hashable, Hashable, Lean.ToExpr

@[kstep] def Reg64s.get64 (s : Reg64s) (r : Reg64) : Width.W64.type := UInt64.toBitVec (match r with
  | .rax => s.rax | .rbx => s.rbx | .rcx => s.rcx | .rdx => s.rdx
  | .rsi => s.rsi | .rdi => s.rdi | .rsp => s.rsp | .rbp => s.rbp
  | .r8  => s.r8  | .r9  => s.r9  | .r10 => s.r10 | .r11 => s.r11
  | .r12 => s.r12 | .r13 => s.r13 | .r14 => s.r14 | .r15 => s.r15)

@[kstep] def Reg64s.set64 (regs : Reg64s) (r : Reg64) (v : Width.W64.type) : Reg64s :=
  let  v := UInt64.ofBitVec v
  match r with
  | .rax => { regs with rax := v } | .rbx => { regs with rbx := v }
  | .rcx => { regs with rcx := v } | .rdx => { regs with rdx := v }
  | .rsi => { regs with rsi := v } | .rdi => { regs with rdi := v }
  | .rsp => { regs with rsp := v } | .rbp => { regs with rbp := v }
  | .r8  => { regs with r8  := v } | .r9  => { regs with r9  := v }
  | .r10 => { regs with r10 := v } | .r11 => { regs with r11 := v }
  | .r12 => { regs with r12 := v } | .r13 => { regs with r13 := v }
  | .r14 => { regs with r14 := v } | .r15 => { regs with r15 := v }

@[kstep] def Reg64s.get (s : Reg64s) {w} (r : Reg w) : w.type :=
  ((s.get64 r.base).drop r.offset).take w.bits
  -- BitVec because it may be signed or unsigned depending on context

@[kstep] def Reg64s.set (s : Reg64s) {w} (r : Reg w) (v : w.type) : Reg64s := match r with
  | .low r .W64 => s.set64 r v
  | .low r .W32 => s.set64 r (v.zeroExtend _)
  | .low r w => s.set64 r ((s.get64 r).replaceLow v)
  | .ah | .bh | .ch | .dh => let old := s.get64 r.base;
    s.set64 r.base (old.replaceLow (BitVec.append v (s.get (.low r.base .W8))))

def ZmmValue : Type := BitVec 512
  deriving Repr, BEq, DecidableEq, Hashable, Hashable, Lean.ToExpr

def zmmZero : ZmmValue := 0#512

structure RegZmms where
  zmm0  : ZmmValue := zmmZero
  zmm1  : ZmmValue := zmmZero
  zmm2  : ZmmValue := zmmZero
  zmm3  : ZmmValue := zmmZero
  zmm4  : ZmmValue := zmmZero
  zmm5  : ZmmValue := zmmZero
  zmm6  : ZmmValue := zmmZero
  zmm7  : ZmmValue := zmmZero
  zmm8  : ZmmValue := zmmZero
  zmm9  : ZmmValue := zmmZero
  zmm10 : ZmmValue := zmmZero
  zmm11 : ZmmValue := zmmZero
  zmm12 : ZmmValue := zmmZero
  zmm13 : ZmmValue := zmmZero
  zmm14 : ZmmValue := zmmZero
  zmm15 : ZmmValue := zmmZero
  zmm16 : ZmmValue := zmmZero
  zmm17 : ZmmValue := zmmZero
  zmm18 : ZmmValue := zmmZero
  zmm19 : ZmmValue := zmmZero
  zmm20 : ZmmValue := zmmZero
  zmm21 : ZmmValue := zmmZero
  zmm22 : ZmmValue := zmmZero
  zmm23 : ZmmValue := zmmZero
  zmm24 : ZmmValue := zmmZero
  zmm25 : ZmmValue := zmmZero
  zmm26 : ZmmValue := zmmZero
  zmm27 : ZmmValue := zmmZero
  zmm28 : ZmmValue := zmmZero
  zmm29 : ZmmValue := zmmZero
  zmm30 : ZmmValue := zmmZero
  zmm31 : ZmmValue := zmmZero
  deriving Repr, BEq, DecidableEq, Hashable, Hashable, Lean.ToExpr

def RegZmms.get512 (s : RegZmms) (r : RegMm) : AvxWidth.W512.type := (match r with
  | .mm0  => s.zmm0  | .mm1  => s.zmm1  | .mm2  => s.zmm2  | .mm3  => s.zmm3
  | .mm4  => s.zmm4  | .mm5  => s.zmm5  | .mm6  => s.zmm6  | .mm7  => s.zmm7
  | .mm8  => s.zmm8  | .mm9  => s.zmm9  | .mm10 => s.zmm10 | .mm11 => s.zmm11
  | .mm12 => s.zmm12 | .mm13 => s.zmm13 | .mm14 => s.zmm14 | .mm15 => s.zmm15
  | .mm16 => s.zmm16 | .mm17 => s.zmm17 | .mm18 => s.zmm18 | .mm19 => s.zmm19
  | .mm20 => s.zmm20 | .mm21 => s.zmm21 | .mm22 => s.zmm22 | .mm23 => s.zmm23
  | .mm24 => s.zmm24 | .mm25 => s.zmm25 | .mm26 => s.zmm26 | .mm27 => s.zmm27
  | .mm28 => s.zmm28 | .mm29 => s.zmm29 | .mm30 => s.zmm30 | .mm31 => s.zmm31)

def RegZmms.set512 (regs : RegZmms) (r : RegMm) (v : AvxWidth.W512.type) : RegZmms :=
  match r with
  | .mm0  => { regs with zmm0  := v } | .mm1  => { regs with zmm1  := v }
  | .mm2  => { regs with zmm2  := v } | .mm3  => { regs with zmm3  := v }
  | .mm4  => { regs with zmm4  := v } | .mm5  => { regs with zmm5  := v }
  | .mm6  => { regs with zmm6  := v } | .mm7  => { regs with zmm7  := v }
  | .mm8  => { regs with zmm8  := v } | .mm9  => { regs with zmm9  := v }
  | .mm10 => { regs with zmm10 := v } | .mm11 => { regs with zmm11 := v }
  | .mm12 => { regs with zmm12 := v } | .mm13 => { regs with zmm13 := v }
  | .mm14 => { regs with zmm14 := v } | .mm15 => { regs with zmm15 := v }
  | .mm16 => { regs with zmm16 := v } | .mm17 => { regs with zmm17 := v }
  | .mm18 => { regs with zmm18 := v } | .mm19 => { regs with zmm19 := v }
  | .mm20 => { regs with zmm20 := v } | .mm21 => { regs with zmm21 := v }
  | .mm22 => { regs with zmm22 := v } | .mm23 => { regs with zmm23 := v }
  | .mm24 => { regs with zmm24 := v } | .mm25 => { regs with zmm25 := v }
  | .mm26 => { regs with zmm26 := v } | .mm27 => { regs with zmm27 := v }
  | .mm28 => { regs with zmm28 := v } | .mm29 => { regs with zmm29 := v }
  | .mm30 => { regs with zmm30 := v } | .mm31 => { regs with zmm31 := v }

def RegZmms.get (s : RegZmms) {w} (r : AvxReg w) : w.type :=
  (s.get512 r.base).take w.bits

def RegZmms.set (s : RegZmms) {w} (r : AvxReg w) (v : w.type) : RegZmms := match r with
  | .zmm r => s.set512 r v
  | .ymm r => s.set512 r (v.zeroExtend _)
  | .xmm r => s.set512 r (v.zeroExtend _)

def RegZmms.setLegacy (s : RegZmms) {w} (r : AvxReg w) (v : w.type) : RegZmms := match r with
  | .zmm r => s.set512 r v  -- impossible
  | .ymm r => s.set512 r ((s.get512 r).replaceLow v)  -- impossible
  | .xmm r => s.set512 r ((s.get512 r).replaceLow v)

def RegZmms.vzeroupper (s : RegZmms) : RegZmms :=
  RegMm.low16.foldl (fun s r => s.set (.xmm r) (s.get (.xmm r))) s

def RegZmms.vzeroall (s : RegZmms) : RegZmms :=
  RegMm.low16.foldl (fun s r => s.set512 r zmmZero) s

@[kstep]
def BitVec.toAddressSize [address_size: AddressSize] (w: BitVec 64): BitVec address_size.address_size.bits :=
  w.take address_size.address_size.bits

structure StatusFlags where
  cf : Bool
  pf : Bool
  af : Bool
  zf : Bool
  sf : Bool
  of : Bool
  df : Bool := false
  deriving Repr, BEq, DecidableEq, Hashable, Lean.ToExpr

abbrev DataMem := Mem 64
instance : Repr DataMem where reprPrec _ _ := "<opaque memory>"
structure MachineData where -- does not include code or program position
  regs : Reg64s := {}
  zmms : RegZmms := {}
  status : StatusFlags := .mk false false false false false false false
  dmem : DataMem := ∅
  deriving Repr, BEq, DecidableEq

-- We only allow nondeterministic choices for a fixed set of types.
class inductive NondetSupportingType : Type -> Type
  | bitvec (w : Width) : NondetSupportingType w.type
  | avx_bitvec (aw : AvxWidth) : NondetSupportingType aw.type
  | bool : NondetSupportingType Bool
  | statusFlags : NondetSupportingType StatusFlags

def NondetSupportingType.from_hash {α} [t : NondetSupportingType α] (h : UInt64) : α :=
  match t with
  | .bool => h % 2 != 0
  | .statusFlags => let h := h.toBitVec; (.mk h[0] h[1] h[2] h[3] h[4] h[5] h[6])
  | .bitvec w => h.toBitVec.setWidth w.bits
  | .avx_bitvec w => h.toBitVec.setWidth w.bits

instance (w : Width) : NondetSupportingType w.type := .bitvec w
instance (w : AvxWidth) : NondetSupportingType w.type := .avx_bitvec w
instance : NondetSupportingType Bool := .bool
instance : NondetSupportingType StatusFlags := .statusFlags

inductive Effects
  | done (a : MachineData × Int64)
  | unimplemented (msg : String)
  | gp_unaligned (addr : BitVec 64) (w : Nat)
  | fault (exception : String)
  -- loads and stores *outside* the data memory, eg. MMIO, might still affect the data memory:
  -- for instance, MMIO reads/writes at certain device register addresses might change what
  -- data memory the process logically owns vs what memory is owned by devices
  | nonmem_load (dmem : DataMem) (addr : BitVec 64) (w : Width) (ret : w.type → DataMem → Effects)
  | nonmem_store (dmem : DataMem) (addr : BitVec 64) {w : Width} (v : w.type) (ret: DataMem → Effects)
  | undefined {α : Type} [NondetSupportingType α] (ret : α → Effects)
  | require_read_access (addr : BitVec 64) (w : Width) (ok : Unit → Effects)
  | require_write_access (addr : BitVec 64) (w : Width) (ok : Unit → Effects)
  | require_exec_access (p: Std.Rco Int64) (ok : Unit → Effects)
export Effects (unimplemented nonmem_load nonmem_store undefined require_read_access require_write_access require_exec_access)

-- the unused `Std.Rco Int64` argument and the unmodified `MachineData` return
-- value are present for uniformity with RegOrMem.interp
@[kstep] def Reg.interp {w} (r : Reg w) (s : MachineData) (_ : Std.Rco Int64)
  (ret : w.type → MachineData → Effects) : Effects :=
  ret (s.regs.get r) s

-- Since MMIO can cause devices to do arbitrary actions, a load might actually
-- *modify* memory. For instance:
-- A TEST instruction might load a flag from an MMIO address and bitwise-and it with
-- an immediate, and if the result is non-zero, it might mean that some device has
-- finished processing a buffer and therefore now passes ownership of that buffer
-- to the CPU.
-- Note that `ret` takes a whole `MachineData` instead of only `DataMem`, which
-- provides a bit more flexibility than we need: MachineData.load might change
-- dmem, but will not change the registers or status flags.
-- But this superfluous flexibility helps us simplify the state-threading:
-- Instead of writing `fun v dmem => ... { s with dmem } ...` everywhere, we
-- can just write `fun v s => ...` and the new `s` will shadow the old `s`.
def MachineData.load
  (s : MachineData) (addr : BitVec 64) (w : Width)
  (ret : w.type → MachineData → Effects): Effects :=
  require_read_access addr w (fun _unit =>
    match Mem.loadInt s.dmem addr w.bytes with
    | .some i => ret (.ofInt _ i) s
    | .none => nonmem_load s.dmem addr w (fun v dmem => ret v { s with dmem }))

-- Alternatively, we could define this in terms of BitVecs without %:
-- (addr &&& BitVec.ofNat 64 (bytes - 1)) == 0#64
def isAligned (bytes : Nat) (addr : BitVec 64) : Bool :=
  addr.toNat % bytes == 0

-- Legacy SSE instructions are generally stricter about alignment requirements,
-- while AVX (VEX-encoded) instructions can mostly deal with unaligned
-- addresses (https://discourse.llvm.org/t/memory-alignment-model-on-avx-avx2-and-avx-512-targets/34705).
-- For this reason we default checkAlign to false.
def MachineData.loadAvx
  (s : MachineData) (addr : BitVec 64) (w : AvxWidth)
  (ret : w.type → MachineData → Effects) (checkAlign : Bool := false) : Effects :=
  if checkAlign && !(isAligned w.bytes addr) then
    .gp_unaligned addr w.bytes
  else
    require_read_access addr .W64 (fun _unit =>
  match Mem.loadInt s.dmem addr w.bytes with
      | .some i => ret (.ofInt _ i) s
      | .none => unimplemented "AVX nonmem load not supported")

def MachineData.store (s : MachineData) (addr : BitVec 64) {w : Width} (v : w.type) (ret: MachineData → Effects) : Effects :=
  require_write_access addr w (fun _unit =>
    match Mem.loadInt s.dmem addr w.bytes with
    | .some _ =>
        ret { s with dmem := Mem.storeInt s.dmem addr w.bytes v.toInt }
    | .none => nonmem_store s.dmem addr v (fun dmem' => ret { s with dmem := dmem' }))

def MachineData.storeAvx (s : MachineData) (addr : BitVec 64) {w : AvxWidth} (v : w.type) (ret: MachineData → Effects) (checkAlign : Bool := false) : Effects :=
  if checkAlign && !(isAligned w.bytes addr) then
    .gp_unaligned addr w.bytes
  else
    require_write_access addr .W64 (fun _unit =>
  match Mem.loadInt s.dmem addr w.bytes with
      | .some _ =>
          ret { s with dmem := Mem.storeInt s.dmem addr w.bytes v.toInt }
      | .none => unimplemented "AVX nonmem store not supported")

class Labels where label : Label → Int64
export Labels (label)

@[kstep] def ConstExpr.interp [Labels] : ConstExpr → Std.Rco _root_.Int64 → _root_.Int64
  | .label l, _ => Labels.label l
  | .int64 i, _ => i
  | .before_current_instruction, r => r.lower
  | .after_current_instruction, r => r.upper
  | .add e1 e2, p => e1.interp p + e2.interp p
  | .sub e1 e2, p => e1.interp p - e2.interp p

@[kstep] def AddrExpr.interp [Labels] [address_size : AddressSize] (a : AddrExpr) (s : Reg64s) (p : Std.Rco Int64) :=
  let base := match a.base with
              | .some (.reg r) => (s.get64 r).toAddressSize.signed
              | .some .rip => p.upper.toInt
              | .none => 0
  let idx := match a.idx with
             | .some ⟨r, c⟩ => (s.get64 r).toAddressSize.signed * c.bytes
             | .none => 0
  BitVec.ofInt address_size.address_size.bits (base + idx + (a.disp.interp p).toInt)

@[kstep] def RegOrMem.interp {w} [Labels] [AddressSize]
  (o : RegOrMem w) (s : MachineData) (p : Std.Rco Int64)
  (ret : w.type → MachineData → Effects) :=
match o with
  | .reg r => ret (s.regs.get r) s
  | .mem a => s.load ((a.interp s.regs p).zeroExtend _) w ret

def AvxRegOrMem.interp {w} [Labels] [AddressSize]
  (o : AvxRegOrMem w) (s : MachineData) (p : Std.Rco Int64)
  (ret : w.type → MachineData → Effects) (checkAlign : Bool := false) :=
match o with
  | .avx r => ret (s.zmms.get r) s
  | .mem a => s.loadAvx ((a.interp s.regs p).zeroExtend _) w ret checkAlign

/-- A SIMD source operand: a register, or memory holding `bytes?` bytes (zero-extended) or the whole
vector. Legacy SSE instructions fault on unaligned whole-vector memory operands. -/
def AvxRegOrMem.interpSimd {w} [Labels] [AddressSize]
  (o : AvxRegOrMem w) (bytes? : Option Nat) (s : MachineData) (p : Std.Rco Int64) (legacy : Bool)
  (ret : w.type → MachineData → Effects) : Effects :=
  let addr (a : AddrExpr) := (a.interp s.regs p).zeroExtend 64
  match o, bytes? with
  | .mem a, some 16 => s.loadAvx (addr a) .W128 (fun v s => ret (v.zeroExtend _) s)
  | .mem a, some n => s.load (addr a) (.ofBytes n) (fun v s => ret (v.zeroExtend _) s)
  | _, _ => o.interp s p ret (checkAlign := legacy)

def SimdCount.interp [Labels] [AddressSize] (c : SimdCount) (s : MachineData) (p : Std.Rco Int64)
  (legacy : Bool) (ret : Nat → MachineData → Effects) : Effects := match c with
  | .imm v => ret ((v.interp p).toBitVec.take 8).toNat s
  -- Counts of at least 64 all have the same effect; this caps them to keep shifts cheap.
  | .reg src => src.interp s p (checkAlign := legacy) (fun v s => ret (min (v.take 64).toNat 64) s)

@[kstep]
def MachineData.setReg (s : MachineData) {w} (r : Reg w) (v : w.type) : MachineData :=
  { s with regs := s.regs.set r v }

def MachineData.setAvxReg (s : MachineData) {w : AvxWidth} (r : AvxReg w) (v : w.type) : MachineData :=
  { s with zmms := s.zmms.set r v }

def MachineData.setAvxLegacyReg (s : MachineData) {w : AvxWidth} (r : AvxReg w) (v : w.type) : MachineData :=
  { s with zmms := s.zmms.setLegacy r v }

@[kstep]
def MachineData.set {w} [Labels] [AddressSize] (s : MachineData) (d : Dst w) (v : w.type) (p : Std.Rco Int64) (ret : MachineData → Effects) : Effects :=
  match d with
  | .reg r => ret (s.setReg r v)
  | .mem a => s.store ((a.interp s.regs p).zeroExtend _) v ret

def MachineData.setAvx {aw} [Labels] [AddressSize] (s : MachineData) (d : AvxDst aw) (v : aw.type) (p : Std.Rco Int64) (ret : MachineData → Effects) (checkAlign : Bool := false) : Effects :=
match d with
  | .avx r => ret (s.setAvxReg r v)
  | .mem a => s.storeAvx ((a.interp s.regs p).zeroExtend _) v ret checkAlign

def MachineData.setAvxLegacy {w} [Labels] [AddressSize] (s : MachineData) (d : AvxDst w) (v : w.type) (p : Std.Rco Int64) (ret : MachineData → Effects) (checkAlign : Bool := false) : Effects :=
match d with
  | .avx r => ret (s.setAvxLegacyReg r v)
  | .mem a => s.storeAvx ((a.interp s.regs p).zeroExtend _) v ret checkAlign

def MachineData.storeScalar [Labels] [AddressSize] {w : AvxWidth} (s : MachineData) (addr : BitVec 64) (op : SimdScalarMov)
  (v : w.type) (next : MachineData → Effects) : Effects :=
  s.store addr (w := .ofBytes op.bytes) (v.take _) next

@[kstep] def Operand.interp {w} [Labels] [AddressSize]
  (o : Operand w) (s : MachineData) (p : Std.Rco Int64)
  (ret : w.type → MachineData → Effects) :=
  match o with
  | regOrMem rm => rm.interp s p ret
  | .imm v => ret ((v.interp p).toBitVec.truncate _) s
  -- we rely on assemblers erroring out on too-large immediates in uniform ops

@[kstep]
def CondCode.interp (cc : CondCode) (s : StatusFlags) : Bool := match cc with
  | .o  => s.of | .no => !s.of
  | .c  => s.cf | .nc => !s.cf
  | .z  => s.zf | .nz => !s.zf
  | .be => s.cf || s.zf | .a  => !s.cf && !s.zf
  | .s  => s.sf | .ns => !s.sf
  | .p  => s.pf | .np => !s.pf
  | .l  => s.sf != s.of | .ge => s.sf == s.of
  | .le => (s.sf != s.of) || s.zf | .g  => !s.zf && (s.sf == s.of)

def FlagOut.apply (f : FlagOut) (old : Bool) (k : Bool → Effects) : Effects := match f with
  | .keep => k old | .set b => k b | .undef => undefined k

def StatusFlags.update (s : StatusFlags) (f : FlagsOut) (k : StatusFlags → Effects) : Effects :=
  f.cf.apply s.cf fun cf => f.pf.apply s.pf fun pf => f.af.apply s.af fun af =>
  f.zf.apply s.zf fun zf => f.sf.apply s.sf fun sf => f.of.apply s.of fun of => k ⟨cf, pf, af, zf, sf, of, s.df⟩

@[kstep] def ConstExpr.imm8 [Labels] (imm : ConstExpr) (p : Std.Rco Int64) : BitVec 8 :=
  (imm.interp p).toBitVec.take 8

@[kstep] def Option.imm8 [Labels] (imm : Option ConstExpr) (p : Std.Rco Int64) : BitVec 8 :=
  match imm with | some e => e.imm8 p | none => 0

@[kstep] def ShiftCountExpr.interp [Labels] (c : ShiftCountExpr) (s : MachineData) (p : Std.Rco Int64) := match c with
  | .cl => s.regs.rcx.toBitVec.take 8
  | .imm8 v => v.imm8 p
@[kstep] def ShiftCountExpr.interpMasked [Labels] (c : ShiftCountExpr) (s : MachineData) (p : Std.Rco Int64) (w : Width) : Nat :=
  (c.interp s p).toNat &&& match w with | .W64 => 0x3f | _ => 0x1f -- "masked to 5 bits (or 6 bits with a 64-bit operand)"

def RelRegOrMem.interp [Labels] [AddressSize]
  (o : RelRegOrMem) (s : MachineData) (p : Std.Rco Int64)
  (ret : BitVec 64 → MachineData → Effects) :=
  match o with
  | .rel c => ret (p.upper + c.interp p).toBitVec s
  | .reg r => ret (s.regs.get r) s
  | .mem a => s.load ((a.interp s.regs p).zeroExtend _) .W64 ret

structure StatusFlags.from_result.Remaining where
  cf : Bool
  af : Bool
  of : Bool
  deriving Repr, BEq, DecidableEq

-- TEMPORARY: definitions stolen from Lean 4.28's standard library, but with a
-- different name so that this file builds with both 4.27 and 4.28
namespace BitVec
def cpopNatRec_ {w} (x : BitVec w) (pos acc : Nat) : Nat :=
  match pos with
  | 0 => acc
  | n + 1 => x.cpopNatRec_ n (acc + (x.getLsbD n).toNat)

def cpop_ {w} (x : BitVec w) : BitVec w := BitVec.ofNat w (cpopNatRec_ x w 0)
end BitVec

def crc32cStep (crc : BitVec 32) (b : BitVec 8) : BitVec 32 :=
  let poly : BitVec 32 := 0x82F63B78#32
  (List.range 8).foldl (fun c _ =>
    if c.getLsbD 0 then (c >>> 1) ^^^ poly else c >>> 1
  ) (crc ^^^ b.zeroExtend 32)

def byteSwap {w : Width} (v : BitVec w.bits) : BitVec w.bits :=
  .ofLanes w.bits 8 fun i => v.lane 8 (w.bytes - 1 - i)

@[kstep] def StatusFlags.from_result {w} (old : StatusFlags) (result : BitVec w) (f : from_result.Remaining) : StatusFlags :=
  { old with
    pf := (result.take 8).cpop_ % 2 == BitVec.zero _
    zf := result == BitVec.zero _
    sf := result.msb, cf := f.cf, af := f.af, of := f.of }

@[kstep] def addFlags {w} (old : StatusFlags) (a b : BitVec w) (c : Bool := false) : BitVec w × StatusFlags :=
  let cin : BitVec w := if c then 1 else 0
  let v := a + b + cin
  let cint : Int := if c then 1 else 0
  (v, StatusFlags.from_result old v {
    cf := v.unsigned != a.unsigned + b.unsigned + cint
    af := (v.take 4).unsigned != (a.take 4).unsigned + (b.take 4).unsigned + cint
    of := v.signed != a.signed + b.signed + cint })

@[kstep] def subFlags {w} (old : StatusFlags) (a b : BitVec w) (c : Bool := false) : BitVec w × StatusFlags :=
  let cin : BitVec w := if c then 1 else 0
  let v := a - b - cin
  let cint : Int := if c then 1 else 0
  (v, StatusFlags.from_result old v {
    cf := v.unsigned != a.unsigned - b.unsigned - cint
    af := (v.take 4).unsigned != (a.take 4).unsigned - (b.take 4).unsigned - cint
    of := v.signed != a.signed - b.signed - cint })

@[kstep] def incFlags {w} (old : StatusFlags) (a : BitVec w) : BitVec w × StatusFlags :=
  let v := a + 1
  (v, StatusFlags.from_result old v {
    cf := old.cf
    af := (v.take 4).unsigned != (a.take 4).unsigned + 1
    of := v.signed != a.signed + 1 })

@[kstep] def decFlags {w} (old : StatusFlags) (a : BitVec w) : BitVec w × StatusFlags :=
  let v := a - 1
  (v, StatusFlags.from_result old v {
    cf := old.cf
    af := (v.take 4).unsigned != (a.take 4).unsigned - 1
    of := v.signed != a.signed - 1 })

@[kstep] def negFlags {w} (old : StatusFlags) (b : BitVec w) : BitVec w × StatusFlags :=
  let v := -b
  (v, StatusFlags.from_result old v {
    cf := b != 0
    af := (b.take 4) != 0
    of := v.signed != - b.signed })

/-- Runs a string instruction on `w`-sized elements: `body delta` processes one element and
advances rsi/rdi by `delta` (backwards if DF is set). With a `rep` prefix this repeats while rcx,
decremented after each element, is nonzero; comparing instructions (`cmp`: cmps, scas) also stop
when ZF is clear (repe) or set (repne). -/
def stringLoop (w : Width) (rp : RepPrefix) (cmp : Bool) (s : MachineData) (next : MachineData → Effects)
    (body : BitVec 64 → MachineData → (MachineData → Effects) → Effects) : Effects :=
  let delta : BitVec 64 := if s.status.df then -w.bytesv else w.bytesv
  let rec loop (fuel : Nat) (s : MachineData) : Effects :=
    match fuel with
    | 0 => .unimplemented "rep count exceeded limit"
    | fuel + 1 =>
      body delta s fun s =>
        match rp with
        | .none => next s
        | _ =>
          let rcx := s.regs.get64 .rcx - 1
          let s := { s with regs := s.regs.set64 .rcx rcx }
          if rcx == 0 || (cmp && s.status.zf == (rp == .repne)) then next s
          else loop fuel s
  match rp with
  | .none => loop 1 s
  | _ => if s.regs.get64 .rcx == 0 then next s else loop 1000000 s

@[kstep] def Operation.interp [Labels] [address_size : AddressSize]
  {w} (i : Operation w) (p : Std.Rco Int64) (s : MachineData)
  (next : MachineData → Effects) (jmp : Int64 → MachineData → Effects) : Effects :=
  match (generalizing := false) (motive := Operation w → Effects) i with
  | .mov dst src => src.interp s p (fun val s => s.set dst val p next)
  | .movnti dst src =>
    let addr := (dst.interp s.regs p).zeroExtend 64
    s.store addr (s.regs.get src) next
  | .movsx dst src => src.interp s p (fun val s => s.set dst (val.signExtend _) p next)
  | .movzx dst src => src.interp s p (fun val s => s.set dst (val.zeroExtend _) p next)
  | .push src =>
    src.interp s p (fun v s =>
    let rsp := s.regs.get64 .rsp - w.bytesv
    { s with regs := s.regs.set64 .rsp rsp }.store rsp v next)
  | .pop dst =>
    let rsp := s.regs.get64 .rsp
    s.load rsp w (fun val s =>
    let s := { s with regs := s.regs.set64 .rsp (rsp + w.bytesv) }
    s.set dst val p next)
  | .leave =>
    let rbp := s.regs.get64 .rbp
    s.load rbp .W64 (fun val s =>
    let s := { s with regs := (s.regs.set64 .rsp (rbp + 8)).set64 .rbp val }
    next s)
  | .pushf =>
    let rflags_val : BitVec 64 :=
      ((BitVec.ofNat 64 2)) |||
      ((BitVec.ofNat 64 0x200)) |||
      ((BitVec.ofBool s.status.cf).zeroExtend 64) |||
      ((BitVec.ofBool s.status.pf).zeroExtend 64 <<< 2) |||
      ((BitVec.ofBool s.status.af).zeroExtend 64 <<< 4) |||
      ((BitVec.ofBool s.status.zf).zeroExtend 64 <<< 6) |||
      ((BitVec.ofBool s.status.sf).zeroExtend 64 <<< 7) |||
      ((BitVec.ofBool s.status.df).zeroExtend 64 <<< 10) |||
      ((BitVec.ofBool s.status.of).zeroExtend 64 <<< 11)
    let rsp := s.regs.get64 .rsp - 8
    { s with regs := s.regs.set64 .rsp rsp }.store rsp rflags_val next
  | .popf =>
    let rsp := s.regs.get64 .rsp
    s.load rsp .W64 (fun val s =>
    if val.getLsbD 8 then .fault "#DB: trap flag set" else
    -- NT, AC and ID are not modeled (AC would also make misaligned accesses fault).
    if val &&& 0x244000 != 0 then .unimplemented "popf: NT/AC/ID" else
    let status := { s.status with
      cf := val.getLsbD 0
      pf := val.getLsbD 2
      af := val.getLsbD 4
      zf := val.getLsbD 6
      sf := val.getLsbD 7
      df := val.getLsbD 10
      of := val.getLsbD 11 }
    let s := { s with regs := s.regs.set64 .rsp (rsp + 8), status }
    next s)
  | .setcc cc dst =>
    s.set dst (cc.interp s.status) p next
  | .cmovcc cc dst src =>
    src.interp s p (fun src s =>
    let v := if cc.interp s.status then src else s.regs.get dst
    next (s.setReg dst v))
  | .xchg dst src =>
    dst.interp s p (fun dval s =>
    let sval := s.regs.get src
    let s := s.setReg src dval
    s.set dst sval p next)
  | .xadd dst src =>
    dst.interp s p (fun dval s =>
    let sval := s.regs.get src
    let (v, status) := addFlags s.status dval sval
    let s := { s with status }.setReg src dval
    s.set dst v p next)
  | .cmpxchg dst src =>
    let acc := s.regs.get (Reg.low .rax w)
    dst.interp s p (fun dval s =>
    let (_, status) := subFlags s.status acc dval
    let s := { s with status }
    if acc == dval then
      let sval := s.regs.get src
      s.set dst sval p next
    else
      let s := s.setReg (Reg.low .rax w) dval
      match dst with
      | .mem _ => s.set dst dval p next
      | .reg _ => next s)
  | .cmpxchg8b a =>
    let addr := (a.interp s.regs p).zeroExtend 64
    s.load addr .W64 (fun mem_val s =>
    let edx := s.regs.get (.low .rdx .W32)
    let eax := s.regs.get (.low .rax .W32)
    let edx_eax := (edx ++ eax).setWidth 64
    if mem_val == edx_eax then
      let ecx := s.regs.get (.low .rcx .W32)
      let ebx := s.regs.get (.low .rbx .W32)
      let ecx_ebx := (ecx ++ ebx).setWidth 64
      let status := { s.status with zf := true }
      { s with status }.store addr ecx_ebx next
    else
      let status := { s.status with zf := false }
      let s := { s with status }
      let low := (mem_val.take 32).setWidth 32
      let high := (mem_val.drop 32).setWidth 32
      let s := (s.setReg (.low .rax .W32) low).setReg (.low .rdx .W32) high
      s.store addr mem_val next)
  | .cmpxchg16b a =>
    let addr := (a.interp s.regs p).zeroExtend 64
    if !isAligned 16 addr then
      .gp_unaligned addr 16
    else
      s.load addr .W64 (fun mem_low s =>
      s.load (addr + 8) .W64 (fun mem_high s =>
      let rdx := s.regs.get64 .rdx
      let rax := s.regs.get64 .rax
      if mem_low == rax && mem_high == rdx then
        let rcx := s.regs.get64 .rcx
        let rbx := s.regs.get64 .rbx
        let status := { s.status with zf := true }
        let s := { s with status }
        s.store addr rbx (fun s =>
        s.store (addr + 8) rcx next)
      else
        let status := { s.status with zf := false }
        let s := { s with status }
        let s := (s.setReg (.low .rax .W64) mem_low).setReg (.low .rdx .W64) mem_high
        s.store addr mem_low (fun s =>
        s.store (addr + 8) mem_high next)))
  | .ud2 => Effects.fault "#UD: undefined instruction"
  | .int3 => Effects.fault "#BP: breakpoint trap"
  | .hlt => Effects.fault "HLT: halt instruction"
  | .clc => next { s with status := { s.status with cf := false } }
  | .stc => next { s with status := { s.status with cf := true } }
  | .cmc => next { s with status := { s.status with cf := !s.status.cf } }
  | .lahf =>
    let ah_val : BitVec 8 :=
      ((BitVec.ofBool s.status.sf).zeroExtend 8 <<< 7) |||
      ((BitVec.ofBool s.status.zf).zeroExtend 8 <<< 6) |||
      ((BitVec.ofBool s.status.af).zeroExtend 8 <<< 4) |||
      ((BitVec.ofBool s.status.pf).zeroExtend 8 <<< 2) |||
      (BitVec.ofNat 8 2) |||
      (BitVec.ofBool s.status.cf).zeroExtend 8
    next (s.setReg Reg.ah ah_val)
  | .sahf =>
    let ah_val := s.regs.get Reg.ah
    let status := { s.status with
      sf := ah_val.getLsbD 7
      zf := ah_val.getLsbD 6
      af := ah_val.getLsbD 4
      pf := ah_val.getLsbD 2
      cf := ah_val.getLsbD 0 }
    next { s with status }
  | .cld => next { s with status := { s.status with df := false } }
  | .std => next { s with status := { s.status with df := true } }
  | .movs rp =>
    stringLoop w rp false s next fun delta s k =>
      let rsi := s.regs.get64 .rsi
      let rdi := s.regs.get64 .rdi
      s.load rsi w fun val s =>
      s.store rdi val fun s =>
      k { s with regs := (s.regs.set64 .rsi (rsi + delta)).set64 .rdi (rdi + delta) }
  | .stos rp =>
    stringLoop w rp false s next fun delta s k =>
      let rdi := s.regs.get64 .rdi
      let val := s.regs.get (Reg.low .rax w)
      s.store rdi val fun s =>
      k { s with regs := s.regs.set64 .rdi (rdi + delta) }
  | .lods rp =>
    stringLoop w rp false s next fun delta s k =>
      let rsi := s.regs.get64 .rsi
      s.load rsi w fun val s =>
      let s := s.setReg (Reg.low .rax w) val
      k { s with regs := s.regs.set64 .rsi (rsi + delta) }
  | .cmps rp =>
    stringLoop w rp true s next fun delta s k =>
      let rsi := s.regs.get64 .rsi
      let rdi := s.regs.get64 .rdi
      s.load rsi w fun a s =>
      s.load rdi w fun b s =>
      let (_, status) := subFlags s.status a b
      k { s with status, regs := (s.regs.set64 .rsi (rsi + delta)).set64 .rdi (rdi + delta) }
  | .scas rp =>
    stringLoop w rp true s next fun delta s k =>
      let rdi := s.regs.get64 .rdi
      let a := s.regs.get (Reg.low .rax w)
      s.load rdi w fun b s =>
      let (_, status) := subFlags s.status a b
      k { s with status, regs := s.regs.set64 .rdi (rdi + delta) }
-- Arithmetic
  | .lea dst src => next (s.setReg dst ((src.interp s.regs p).zeroExtend _))
  | .add dst src =>
    src.interp s p (fun a s =>
    dst.interp s p (fun b s =>
    let (v, status) := addFlags s.status a b
    { s with status }.set dst v p next))
  | .adc dst src =>
    src.interp s p (fun a s =>
    dst.interp s p (fun b s =>
    let (v, status) := addFlags s.status a b s.status.cf
    { s with status }.set dst v p next))
  | .adcx dst src =>
    src.interp s p (fun a s =>
    dst.interp s p (fun b s =>
    let v := a + b + s.status.cf
    let cf := v.unsigned != a.unsigned + b.unsigned + s.status.cf
    next { s with regs := s.regs.set dst v, status := { s.status with cf := cf }}))
  | .adox dst src =>
    src.interp s p (fun a s =>
    dst.interp s p (fun b s =>
    let v := a + b + s.status.of
    let of := v.unsigned != a.unsigned + b.unsigned + s.status.of
    next { s with regs := s.regs.set dst v, status := { s.status with of := of }}))
  | .inc dst =>
    dst.interp s p (fun a s =>
    let (v, status) := incFlags s.status a
    { s with status }.set dst v p next)
  | .dec dst =>
    dst.interp s p (fun a s =>
    let (v, status) := decFlags s.status a
    { s with status }.set dst v p next)
  | .neg dst =>
    dst.interp s p (fun b s =>
    let (v, status) := negFlags s.status b
    { s with status }.set dst v p next)
  | .sub dst src =>
    src.interp s p (fun a s =>
    dst.interp s p (fun b s =>
    let (v, status) := subFlags s.status b a
    { s with status }.set dst v p next))
  | .sbb dst src =>
    src.interp s p (fun a s =>
    dst.interp s p (fun b s =>
    let (v, status) := subFlags s.status b a s.status.cf
    { s with status }.set dst v p next))
  | .cmp a b =>
    a.interp s p (fun a s =>
    b.interp s p (fun b s =>
    let (_, status) := subFlags s.status a b
    next { s with status }))
  | .mul src =>
    let a := s.regs.get (Reg.low .rax w)
    src.interp s p (fun b s =>
    let v := a * b
    let vn := a.unsigned * b.unsigned
    let s := if w == .W8
      then s.setReg (.low .rax .W16) (.ofInt _ vn)
      else (s.setReg (.low .rax w) v).setReg (.low .rdx w) (.ofInt _ (vn >>> w.bits))
    let cf := v.unsigned != vn
    s.status.update { cf, of := cf, sf := .undef, zf := .undef, af := .undef, pf := .undef } fun status =>
    next { s with status })
  | .mulx r_hi r_lo src1 =>
    src1.interp s p (fun a s =>
    let b := s.regs.get (.low .rdx w)
    let v := a.unsigned * b.unsigned
    let s := s.setReg r_lo (.ofInt _ v) -- if r_hi = r_li, hi is written:
    let s := s.setReg r_hi (.ofInt _ (v >>> w.bits))
    next s)
  -- imul1 and imul collectively describe variants of the same
  -- syntax level `imul` instruction, where imul1 is the 1-operand case
  | .imul1 src =>
    let a := s.regs.get (Reg.low .rax w)
    src.interp s p (fun b s =>
    let v := a.toInt * b.toInt
    let s := if w == .W8 then
      s.setReg (.low .rax .W16) (BitVec.ofInt 16 v)
    else
      let result := BitVec.ofInt (w.bits * 2) v
      let low := result.take w.bits
      let high := (result.drop w.bits).setWidth _
      (s.setReg (.low .rax w) low).setReg (.low .rdx w) high
    let low := BitVec.ofInt w.bits v
    let cf := v != low.toInt
    s.status.update { cf, of := cf, sf := .undef, zf := .undef, af := .undef, pf := .undef } fun status =>
    next { s with status })
  | .imul dst src1 src2 =>
    src1.interp s p (fun a s =>
    src2.interp s p (fun b s =>
    let v := a * b
    s.set (match (generalizing := false) (motive := Option (RegOrMem w) → RegOrMem w)
             dst with | .some dst => dst | _ => src1) v p (fun s =>
    let cf := v.signed != a.signed * b.signed
    s.status.update { cf, of := cf, sf := .undef, zf := .undef, af := .undef, pf := .undef } fun status =>
    next { s with status })))
  | .div src | .idiv src =>
    src.interp s p (fun b s =>
    let signed := i matches .idiv ..
    let bVal : Int := if signed then b.signed else b.unsigned
    if bVal == 0 then .fault "#DE: divide by zero" else
    let aVal : Int := if w == .W8
      then (if signed then (s.regs.get (.low .rax .W16)).signed else (s.regs.get (.low .rax .W16)).unsigned)
      else (s.regs.get (Reg.low .rax w)).unsigned + ((if signed then (s.regs.get (.low .rdx w)).signed else (s.regs.get (.low .rdx w)).unsigned) <<< w.bits)
    let q := aVal.tdiv bVal
    let r := aVal.tmod bVal
    let (lo, hi) : Int × Int := if signed then (-(2 ^ (w.bits - 1)), 2 ^ (w.bits - 1) - 1) else (0, 2 ^ w.bits - 1)
    if q < lo || q > hi then .fault "#DE: divide overflow" else
    let s := if w == .W8
      then s.setReg (.low .rax .W16) (BitVec.ofInt 8 r ++ BitVec.ofInt 8 q)
      else (s.setReg (.low .rax w) (.ofInt _ q)).setReg (.low .rdx w) (.ofInt _ r)
    s.status.update .allUndef fun status => next { s with status })
  | .cbw =>
    if w == .W8 then .unimplemented "cbw w8" else
    let low := (s.regs.get (Reg.low .rax w)).take (w.bits / 2)
    next (s.setReg (.low .rax w) (low.signExtend w.bits))
  | .cwd =>
    if w == .W8 then .unimplemented "cwd w8" else
    let ax := s.regs.get (Reg.low .rax w)
    let dx := BitVec.ofInt w.bits (if ax.msb then -1 else 0)
    next (s.setReg (.low .rdx w) dx)
-- Bitwise
  | .test a b =>
    a.interp s p (fun a s =>
    b.interp s p (fun b s =>
    let v := a &&& b
    undefined (fun af =>
    let status := .from_result s.status v { cf := false, af, of := false }
    next { s with status})))
  | .and dst src | .or dst src | .xor dst src =>
    dst.interp s p (fun a s =>
    src.interp s p (fun b s =>
    let v := match i with | .and _ _ => a &&& b | .or _ _ => a ||| b | _ => a ^^^ b
    undefined (fun af =>
    let status := .from_result s.status v { cf := false, of := false, af }
    { s with status }.set dst v p next)))
  | .not dst =>
    dst.interp s p (fun a s =>
    let v := ~~~a
    s.set dst v p next)
  | .shl dst count | .shr dst count | .sar dst count =>
    dst.interp s p (fun a s =>
    let count := count.interpMasked s p w
    -- A zero count leaves flags unchanged but still writes dst, zero-extending 32-bit registers.
    if count == 0 then s.set dst a p next else
    let v := match i with
      | .shl _ _ => a <<< count
      | .shr _ _ => a.ushiftRight count
      | _ /- sar -/ => a.sshiftRight count
    let cfBit := match i with
      | .shl _ _ => (a <<< (count-1)).msb
      | _ /- shr, sar -/ => a.getLsbD (count-1)
    let ofBit := match i with
      | .shl _ _ => v.msb != a.msb
      | .shr _ _ => a.msb
      | _ /- sar -/ => false
    undefined (λ af =>
    (λ setcf => if count < w.bits then setcf cfBit else undefined setcf) (λ cf =>
    (λ setof => if count == 1 then setof ofBit else undefined setof) (λ of =>
    { s with status := .from_result s.status v { cf, af, of } }.set dst v p next))))
  | .shrd dst src count | .shld dst src count =>
    dst.interp s p (fun a s =>
    src.interp s p (fun b s =>
    let count := count.interpMasked s p w
    if count == 0 then s.set dst a p next else
    let v := match i with
      | .shrd _ _ _ => (((b.append a) >>> count).take w.bits).setWidth _
      | _ /- shld -/ => (((a.append b) <<< count).drop w.bits).setWidth _
    (λ setstatus => if count >= w.bits then s.status.update .allUndef setstatus else
      let cf := match i with
        | .shrd _ _ _ => a.getLsbD (count-1)
        | _ /- shld -/ => (a <<< (count-1)).msb
      undefined (λ af =>
      (λ setof => if count == 1 then setof (v.msb != a.msb) else undefined setof) (λ of =>
      setstatus (.from_result s.status v { cf, af, of })))) (λ status =>
    -- The result is undefined if the count exceeds the operand size (only possible for 16 bits).
    (λ setv => if count > w.bits then undefined setv else setv v) (λ v =>
    { s with status }.set dst v p next))))
  | .rol dst count | .ror dst count =>
    dst.interp s p (fun a s =>
    let count := count.interpMasked s p w
    if count == 0 then s.set dst a p next else
    let (v, cf) := match i with
      | .rol _ _ => let v := a.rotateLeft count; (v, v.getLsbD 0)
      | _ /- ror -/ => let v := a.rotateRight count; (v, v.msb)
    (λ setof => if count == 1 then setof (v.msb != a.msb) else undefined setof) (λ of =>
    { s with status := { s.status with cf, of } }.set dst v p next))
  | .rcr dst count | .rcl dst count =>
    dst.interp s p (fun a s =>
    let count := count.interpMasked s p w
    if count == 0 then s.set dst a p next else
    let ext := BitVec.ofBool s.status.cf ++ a
    let t := match i with
      | .rcr _ _ => ext.rotateRight count
      | _ /- rcl -/ => ext.rotateLeft count
    let (cf, v) := (t.msb, t.take w.bits)
    (λ setof => if count == 1 then setof (v.msb != a.msb) else undefined setof) (λ of =>
    { s with status := { s.status with cf, of } }.set dst v p next))
  | .bswap dst =>
    let a := s.regs.get dst
    match (generalizing := false) (motive := Width → Effects) w with
    | .W32 | .W64 => next (s.setReg dst (byteSwap a))
    | _ => undefined (fun v => next (s.setReg dst v))
  | .movbe dst src =>
    match dst, src with
    | .reg d, .mem _ =>
      src.interp s p (fun v s =>
        next (s.setReg d (byteSwap v)))
    | .mem _, .reg s_reg =>
      let v := s.regs.get s_reg
      s.set dst (byteSwap v) p next
    | _, _ => Effects.fault "movbe requires one memory and one register operand"
  | .crc32 (w' := w') dst src =>
    src.interp s p (fun src_val s =>
      let acc := (s.regs.get dst).take 32
      let n_bytes := w'.bytes
      let res32 := (List.range n_bytes).foldl (fun c i =>
        crc32cStep c (src_val.extractLsb' (i * 8) 8)
      ) acc
      next (s.setReg dst (res32.zeroExtend _)))
  | .rorx dst src cnt =>
    src.interp s p (fun a s =>
      let count := (cnt.interp p).toInt.emod w.bits |>.toNat
      let res := a.rotateRight count
      next (s.setReg dst res))
  | .un op dst src =>
    src.interp s p (fun a s =>
    let (r, f) := op.interp a
    s.status.update f fun status =>
    (fun k => match r with | some r => k r | none => undefined k) fun r =>
    next { s.setReg dst r with status })
  | .bin op dst src1 src2 =>
    src2.interp s p (fun b s =>
    let (r, f) := op.interp (s.regs.get src1) b
    s.status.update f fun status => next { s.setReg dst r with status })
  | .bt op dst bit =>
    bit.interp s p (fun off s =>
    -- A register bit offset into memory is signed and may select a bit outside the operand.
    let (dst, i) : Dst w × Nat := match dst, bit with
      | .mem a, .regOrMem _ => (.mem { a with disp := .add a.disp (.int64 (.ofInt
          (off.toInt.ediv w.bits * w.bytes))) }, off.toInt.emod w.bits |>.toNat)
      | dst, _ => (dst, off.toNat % w.bits)
    dst.interp s p (fun v s =>
    s.status.update { cf := v.getLsbD i, pf := .undef, af := .undef, sf := .undef, of := .undef }
      fun status => let s := { s with status }
    match op.update (v.getLsbD i) with
    | none => next s
    | some b => s.set dst (if b then v ||| BitVec.twoPow _ i else v &&& ~~~BitVec.twoPow _ i) p next))
  | .jcc cc l =>
    if cc.interp s.status
    then jmp (label l) s
    else next s
  | .jrcxz l =>
    if s.regs.get64 .rcx == 0#64
    then jmp (label l) s
    else next s
  | .jecxz l =>
    if s.regs.get (.low .rcx .W32) == 0#32
    then jmp (label l) s
    else next s
  | .loop cond l =>
    let rcx := s.regs.get64 .rcx - 1
    let s := s.setReg (.low .rcx .W64) rcx
    let take := match cond with
      | .none => rcx != 0#64
      | .e => rcx != 0#64 && s.status.zf
      | .ne => rcx != 0#64 && !s.status.zf
    if take then jmp (label l) s else next s
  | .jmp tgt =>
    tgt.interp s p (fun a s =>
    jmp (.ofBitVec a) s)
  | .call tgt =>
    tgt.interp s p (fun a s =>
    let rsp := s.regs.get64 .rsp - Width.W64.bytesv
    { s with regs := s.regs.set64 .rsp rsp }.store rsp (w:=.W64) p.upper.toBitVec (jmp (.ofBitVec a)))
  | .ret =>
    let rsp := s.regs.get64 .rsp
    s.load rsp .W64 (fun ra s =>
    jmp (.ofBitVec ra) { s with regs := s.regs.set64 .rsp (rsp + 8) })
  | .xlat =>
    let addr : BitVec 64 := match address_size.address_size with
      | .W32 => ((s.regs.get (.low .rbx .W32) + (s.regs.get (.low .rax .W8)).zeroExtend 32)).zeroExtend 64
      | _ => s.regs.get64 .rbx + (s.regs.get (.low .rax .W8)).zeroExtend 64
    s.load addr .W8 (fun val s => next (s.setReg (.low .rax .W8) val))
  | nop _ | nopalign _ _ | nopm _ | memHint _ _ | hint _ => next s

-- AVX Operations Interpreter
def AvxOperation.interp [Labels] [address_size : AddressSize]
  {w} (i : AvxOperation w) (p : Std.Rco Int64) (s : MachineData)
  (next : MachineData → Effects) : Effects :=
match i with
  | .mov op dst src =>
    src.interp s p (checkAlign := op.aligned) (fun v s => s.setAvxLegacy dst v p next op.aligned)
  | .vmov op dst src =>
    src.interp s p (checkAlign := op.aligned) (fun v s => s.setAvx dst v p next op.aligned)
  | .sse op dst src =>
    src.interpSimd op.memBytes? s p (legacy := true) (fun b s =>
    next (s.setAvxLegacyReg dst (op.interp (s.zmms.get dst) b)))
  | .vex op dst src1 src2 =>
    src2.interpSimd op.memBytes? s p (legacy := false) (fun b s =>
    next (s.setAvxReg dst (op.interp (s.zmms.get src1) b)))
  | .sseUn op dst src =>
    src.interpSimd (op.memBytes? w.bytes) s p (legacy := true) (fun a s =>
    next (s.setAvxLegacyReg dst (op.interp a)))
  | .vexUn op dst src =>
    src.interpSimd (op.memBytes? w.bytes) s p (legacy := false) (fun a s =>
    next (s.setAvxReg dst (op.interp a)))
  | .sseUnImm op dst src imm =>
    src.interp s p (checkAlign := true) (fun a s =>
    next (s.setAvxLegacyReg dst (op.interp a (imm.imm8 p))))
  | .vexUnImm op dst src imm =>
    src.interp s p (fun a s => next (s.setAvxReg dst (op.interp a (imm.imm8 p))))
  | .sseImm op dst src imm =>
    src.interpSimd op.memBytes? s p (legacy := true) (fun b s =>
    next (s.setAvxLegacyReg dst (op.interp (s.zmms.get dst) b (imm.imm8 p) (legacy := true) (src matches .mem _))))
  | .vexImm op dst src1 src2 imm =>
    src2.interpSimd op.memBytes? s p (legacy := false) (fun b s =>
    next (s.setAvxReg dst (op.interp (s.zmms.get src1) b (imm.imm8 p) (legacy := false) (src2 matches .mem _))))
  | .sseShift op dst count =>
    count.interp s p (legacy := true) (fun c s =>
    next (s.setAvxLegacyReg dst (op.interp (s.zmms.get dst) c)))
  | .vexShift op dst src count =>
    count.interp s p (legacy := false) (fun c s => next (s.setAvxReg dst (op.interp (s.zmms.get src) c)))
  | .sseTest op src1 src2 | .vexTest op src1 src2 =>
    src2.interpSimd op.memBytes? s p (legacy := i matches .sseTest ..) (fun b s =>
    s.status.update (op.interp (s.zmms.get src1) b) fun status => next { s with status })
  | .sseBlendv op dst src =>
    src.interp s p (checkAlign := true) (fun b s =>
    next (s.setAvxLegacyReg dst (op.interp (s.zmms.get dst) b (s.zmms.get ((AvxReg.xmm .mm0).as w)))))
  | .vexBlendv op dst src1 src2 mask =>
    src2.interp s p (fun b s => next (s.setAvxReg dst (op.interp (s.zmms.get src1) b (s.zmms.get mask))))
  | .fma op dst src2 src3 =>
    src3.interpSimd op.memBytes? s p (legacy := false) (fun c s =>
    next (s.setAvxReg dst (op.interp (s.zmms.get dst) (s.zmms.get src2) c)))
  | .vzeroupper => next { s with zmms := s.zmms.vzeroupper }
  | .vzeroall => next { s with zmms := s.zmms.vzeroall }
  | .sseMovs op dst src => match dst, src with
    | .avx d, .avx s_reg =>
      let dval := (s.zmms.get d).take 128
      let sval := (s.zmms.get s_reg).take 128
      let v := dval.replaceLow (sval.take (op.bytes * 8))
      next (s.setAvxLegacyReg d (v.zeroExtend _))
    | .avx d, .mem _ =>
      src.interpSimd (some op.bytes) s p (legacy := true) (fun v s =>
        next (s.setAvxLegacyReg d v))
    | .mem a, .avx s_reg =>
      s.storeScalar ((a.interp s.regs p).zeroExtend 64) op (s.zmms.get s_reg) next
    | _, _ => next s
  | .vexMovs op dst src => match dst, src with
    | .avx d, .mem _ =>
      src.interpSimd (some op.bytes) s p (legacy := false) (fun v s =>
        next (s.setAvxReg d v))
    | .mem a, .avx s_reg =>
      s.storeScalar ((a.interp s.regs p).zeroExtend 64) op (s.zmms.get s_reg) next
    | _, _ => next s
  | .vexScalar op dst src1 src2 =>
    let s1val := (s.zmms.get src1).take 128
    let s2val := (s.zmms.get src2).take 128
    let v := s1val.replaceLow (s2val.take (op.bytes * 8))
    next (s.setAvxReg dst (v.zeroExtend _))
  | .vextract _ dst src imm =>
    let bit := ((imm.interp p).toBitVec.take 1)[0]
    let yval : BitVec 256 := (s.zmms.get src).take 256
    let val128 : BitVec 128 := if bit then yval.extractLsb' 128 128 else yval.take 128
    s.setAvx dst val128 p next
  | .vinsert _ dst src1 src2 imm =>
    src2.interp s p (fun b s =>
    let bit := ((imm.interp p).toBitVec.take 1)[0]
    let yval : BitVec 256 := (s.zmms.get src1).take 256
    let low128 := if bit then yval.take 128 else b
    let high128 := if bit then b else yval.extractLsb' 128 128
    let res256 : BitVec 256 := (BitVec.append high128 low128).setWidth _
    next (s.setAvxReg dst (res256.zeroExtend _)))
  | .vcvtps2ph dst src imm =>
    let mode := roundImmMode (imm.imm8 p)
    let sval := s.zmms.get src
    match w with
    | .W128 =>
      let res64 : BitVec 64 := BitVec.ofLanes 64 16 fun i =>
        f32ToF16 mode (sval.lane 32 i)
      match dst with
      | .avx r => next (s.setAvxReg r (res64.zeroExtend 128))
      | .mem addr =>
        let a := (addr.interp s.regs p).zeroExtend 64
        s.store a res64 next
    | .W256 =>
      let res128 : BitVec 128 := BitVec.ofLanes 128 16 fun i =>
        f32ToF16 mode (sval.lane 32 i)
      s.setAvx dst res128 p next
    | _ => .unimplemented "vcvtps2ph requires 128- or 256-bit source"
  | .sseToGpr op (gw := gw) dst src | .vexToGpr op (gw := gw) dst src =>
    src.interpSimd op.memBytes? s p (legacy := i matches .sseToGpr ..) (fun a s =>
    next (s.setReg dst (op.interp gw.bits a)))
  | .sseExtract op (gw := gw) dst src imm | .vexExtract op (gw := gw) dst src imm =>
    let res := op.interp gw.bits (s.zmms.get src) (imm.imm8 p)
    s.set dst res p next
  | .sseInsert op dst (gw := gw) src imm =>
    src.interp s p (fun v s =>
    next (s.setAvxLegacyReg dst (op.interp (s.zmms.get dst) gw.bits v (imm.imm8 p))))
  | .vexInsert op dst src1 (gw := gw) src2 imm =>
    src2.interp s p (fun v s =>
    next (s.setAvxReg dst (op.interp (s.zmms.get src1) gw.bits v (imm.imm8 p))))

@[kstep]
def Instr.interp [Labels]
  (i : Instr) (s : MachineData) (p : Std.Rco Int64)
  (next : MachineData → Effects) (jmp : Int64 → MachineData → Effects) : Effects :=
  require_exec_access p (fun _unit =>
    match i with
      | .regular addr_sz op_sz op =>
          Operation.interp (w := op_sz) (address_size := .mk addr_sz) op p s next jmp
      | .avx addr_sz op_sz op =>
          AvxOperation.interp (w := op_sz) (address_size := .mk addr_sz) op p s next
  )

@[kstep] def Directive.interp [Labels]
  (d : Directive) (s : MachineData) (p : Std.Rco Int64)
  (next : MachineData → Effects) (jmp : Int64 → MachineData → Effects) : Effects :=
  match d with
  | .label _ => next s
  | .instr i => i.interp s p next jmp
  | .byteArray _ => .unimplemented s!"Unimplemented: execution reached data block at {p.1}"

def Directives.interp [Labels]
  (ds : List (Directive × Nat)) (s : MachineData) (pc : Int64)
  (ret : Int64 → MachineData → Effects) : Effects :=
  match ds with
  | [] => ret pc s
  | (d, sz) :: ds =>
    d.interp s (.mk pc (pc+.ofNat sz)) (jmp:=ret) (next := (fun s =>
    interp ds s (pc+.ofNat sz) ret))

abbrev Layout := Kraken.Layout Directive

@[reducible]
def Executable.labels (e : Executable) : Labels :=
  { label l := (e.withAddresses.findSome?
      (fun (p, d, _) => if d = .label l then .some p else .none)).getD (-1) }

def Executable.directivesFromLabel (e : Executable) (l : Label) : List (Directive × Nat) :=
  e.2.dropWhile (·.1 != .label l)

abbrev MachineState := MachineData × Int64

def Executable.step (e : Executable) (s : MachineState) (ret : MachineState → Effects) : Effects :=
  let := Executable.labels e
  Directives.interp (e.directivesAtAddress s.2) s.1 s.2 (fun pc s => ret (s, pc))

def Executable.straightline (e : Executable) (s : MachineState) (ret : MachineState → Effects) : Effects :=
  let := Executable.labels e
  Directives.interp (e.directivesFromAddress s.2) s.1 s.2 (fun pc s => ret (s, pc))

-- -- Concrete evaluators for expedient testing

partial def Executable.eval (e : Executable) (s : MachineState) (until_ : MachineState → Bool) : Except String (MachineState) :=
  if until_ s then .ok s else handleEffects (Executable.straightline e s .done)
where
  handleEffects es :=
    match es with
    | .done s => eval e s until_
    | .unimplemented msg => .error msg
    | .gp_unaligned addr w => .error s!"#GP: Memory op at {repr addr} did not have mandatory alignment of {w}"
    | .fault exc => .error exc
    | .require_read_access _ _ ok => handleEffects (ok ())
    | .require_write_access _ _ ok => handleEffects (ok ())
    | .require_exec_access _ ok => handleEffects (ok ())
    | .nonmem_load _ addr _ _ => .error s!"Load at unmapped address {repr addr}"
    | .nonmem_store _ addr _ _ => .error s!"Store at unmapped address {repr addr}"
    | @Effects.undefined _ t cont => handleEffects (cont (t.from_hash (hash s.1.regs)))

def Directive.fakeSize (hashOfProgram : UInt64) (d : Directive) : Nat :=
  match d with
  | .label _ => 0
  | .instr (.regular _ _ (.nop sz)) => sz -- may be zero
  | .instr i => (1 + hash (hashOfProgram, i) % 15).toNat
  | .byteArray bs => bs.size

def Program.fakeLayout (prog : Program) : Executable :=
  let : Inhabited Directive := .mk (.byteArray (.mk #[]))
  let h := hash prog;
  let layout : Layout := { start := h.toInt64<<<16, size i := prog[i]!.fakeSize h }
  layout prog

abbrev eval [layout : Layout] (prog : Program) := Executable.eval (layout prog)

/-- info: Except.ok 42 -/
#guard_msgs in
#eval
  let exe := Program.fakeLayout [
    .label "main",
    .instr (.regular .W64 .W64 (.lea (.low .rax .W64) (.mk .none .none (.int64 41)))),
    .instr (.regular .W64 .W64 (.inc (.reg (.low .rax .W64)))),
    .instr (.regular .W64 .W64 .ret) ]
  let start := (Executable.labels exe).label "main"
  let data : MachineData := { dmem := Mem.storeInt {} 0x100 8 0x1337, regs := {rsp := 0x100} }
  (Executable.eval exe (data, start) (fun (_, pc) => pc = 0x1337)).bind (fun s => .ok s.1.regs.rax)
