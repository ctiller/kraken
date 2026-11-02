module

import Kraken.X64.Semantics
meta import Kraken.X64.Semantics

/-! Concrete-evaluation tests of semantics that the native asm tests can't observe. -/

private partial def accessChecks :
    Effects → Option (List (Nat × Nat) × List (Nat × Nat))
  | .done _ => some ([], [])
  | .require_read_access p ok => (accessChecks (ok ())).map fun (rs, ws) => ((p.lower, p.upper) :: rs, ws)
  | .require_write_access p ok => (accessChecks (ok ())).map fun (rs, ws) => (rs, (p.lower, p.upper) :: ws)
  | _ => none

/-- 64 bytes of data memory at `0x1000`. -/
private def s : MachineData := { dmem := (List.replicate 64 0).At 0x1000 }

#guard accessChecks (s.loadAvx 0x1000 .W128 fun _ s => .done ⟨s, 0⟩) ==
  some ([(0x1000, 0x1010)], [])
#guard accessChecks (s.loadAvx 0x1000 .W256 fun _ s => .done ⟨s, 0⟩) ==
  some ([(0x1000, 0x1020)], [])
#guard accessChecks (s.loadAvx 0x1000 .W512 fun _ s => .done ⟨s, 0⟩) ==
  some ([(0x1000, 0x1040)], [])
#guard accessChecks (s.storeAvx (w := .W128) 0x1000 0 fun s => .done ⟨s, 0⟩) ==
  some ([], [(0x1000, 0x1010)])
#guard accessChecks (s.storeAvx (w := .W256) 0x1000 0 fun s => .done ⟨s, 0⟩) ==
  some ([], [(0x1000, 0x1020)])
#guard accessChecks (s.storeAvx (w := .W512) 0x1000 0 fun s => .done ⟨s, 0⟩) ==
  some ([], [(0x1000, 0x1040)])

#guard ([Width.W8, .W16, .W32, .W64].all fun w =>
  accessChecks (s.load 0x1000 w fun _ s => .done ⟨s, 0⟩) ==
    some ([(0x1000, 0x1000 + w.bytes)], []) &&
  accessChecks (s.store (w := w) 0x1000 0 fun s => .done ⟨s, 0⟩) ==
    some ([], [(0x1000, 0x1000 + w.bytes)]))

#guard accessChecks (s.loadAvx 0x1001 .W128 fun _ s => .done ⟨s, 0⟩) ==
  some ([(0x1001, 0x1011)], [])
#guard match s.loadAvx 0x1001 .W128 (fun _ s => .done ⟨s, 0⟩) (checkAlign := true) with
  | .gp_unaligned addr bytes => addr == 0x1001 && bytes == 16
  | _ => false
#guard match s.storeAvx (w := .W128) 0x1001 0 (fun s => .done ⟨s, 0⟩) (checkAlign := true) with
  | .gp_unaligned addr bytes => addr == 0x1001 && bytes == 16
  | _ => false

private def wrapping : MachineData :=
  { dmem := (List.replicate 64 0).At 0xfffffffffffffff8 }

#guard accessChecks (wrapping.load 0xffffffffffffffff .W8 fun _ s => .done ⟨s, 0⟩) ==
  some ([(0xffffffffffffffff, UInt64.size)], [])
#guard accessChecks (wrapping.loadAvx 0xfffffffffffffff8 .W128 fun _ s => .done ⟨s, 0⟩) ==
  some ([(0xfffffffffffffff8, UInt64.size), (0, 8)], [])
#guard accessChecks (wrapping.storeAvx (w := .W128) 0xfffffffffffffff8 0 fun s => .done ⟨s, 0⟩) ==
  some ([], [(0xfffffffffffffff8, UInt64.size), (0, 8)])

/-- Runs `e`, granting every access check; `none` on a fault, an access outside the data memory,
`undefined`, or anything unimplemented. -/
private partial def run : Effects → Option MachineData
  | .done st => some st.data
  | .require_read_access _ ok | .require_write_access _ ok | .require_exec_access _ ok => run (ok ())
  | _ => none

/-- The value that the SIMD source operand `(%rsp)` with `bytes?` bytes gives a zmm destination,
where `stack` (at `rsp`) is the only mapped memory. -/
private def loadZmm (bytes? : Option Nat) (stack : List UInt8) : Option (BitVec 512) :=
  let : Labels := ⟨fun _ => 0⟩
  let : AddressSize := ⟨.W64⟩
  let rsp : UInt64 := 0x7ffecafee000
  let s : MachineData := { regs := { rsp }, dmem := stack.At rsp.toBitVec }
  let src : AvxRegOrMem .W512 := .mem { base := some (.reg .rsp), idx := none }
  (run (src.interpSimd bytes? s ⟨0, 0⟩ (legacy := false) fun v s =>
    .done ⟨s.setAvxReg (.zmm .mm0) v, 0⟩)).map (·.zmms.zmm0)

/-- The `n`-bit value whose `bits`-bit lanes are `f 0, f 1, ...`. -/
private def lanes (n bits count : Nat) (f : Nat → Nat) : BitVec n :=
  (List.range count).foldl (fun acc i => acc ||| (BitVec.ofNat n (f i) <<< (bits * i))) 0

/-- Bytes 1, 2, ..., 32. -/
private def bytes32 : List UInt8 := (List.range 32).map (·.toUInt8 + 1)

-- Sub-vector memory operand sizes (1, 2, 4, 8, 16, and 32 bytes).
#guard [1, 2, 4, 8, 16, 32].all fun n => loadZmm (some n) bytes32 == some (lanes 512 8 n (· + 1))
#guard loadZmm (some 32) (bytes32.take 31) == none
#guard loadZmm (some 3) bytes32 == none
