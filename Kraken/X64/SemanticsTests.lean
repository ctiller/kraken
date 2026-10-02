module

import Kraken.X64.Semantics
meta import Kraken.X64.Semantics

/-! Concrete-evaluation tests of semantics that the native asm tests can't observe. -/

/-- The read and the write access checks, as `(address, width)` lists, that `e` requests before
it is `done`, granting each one; `none` if it isn't `done` then. -/
private partial def accessChecks :
    Effects → Option (List (BitVec 64 × Width) × List (BitVec 64 × Width))
  | .done _ => some ([], [])
  | .require_read_access addr w ok => (accessChecks (ok ())).map fun (rs, ws) => ((addr, w) :: rs, ws)
  | .require_write_access addr w ok => (accessChecks (ok ())).map fun (rs, ws) => (rs, (addr, w) :: ws)
  | _ => none

/-- 64 bytes of data memory at `0x1000`. -/
private def s : MachineData := { dmem := (List.replicate 64 0).At 0x1000 }

-- The asm tests' runner grants every access check. A vector load or store requests access to
-- every byte it touches, 8 bytes at a time.
#guard accessChecks (s.loadAvx 0x1000 .W128 fun _ s => .done (s, 0)) ==
  some ([(0x1000, .W64), (0x1008, .W64)], [])
#guard accessChecks (s.loadAvx 0x1000 .W256 fun _ s => .done (s, 0)) ==
  some ([(0x1000, .W64), (0x1008, .W64), (0x1010, .W64), (0x1018, .W64)], [])
#guard accessChecks (s.loadAvx 0x1000 .W512 fun _ s => .done (s, 0)) ==
  some ([(0x1000, .W64), (0x1008, .W64), (0x1010, .W64), (0x1018, .W64),
         (0x1020, .W64), (0x1028, .W64), (0x1030, .W64), (0x1038, .W64)], [])
#guard accessChecks (s.storeAvx (w := .W128) 0x1000 0 fun s => .done (s, 0)) ==
  some ([], [(0x1000, .W64), (0x1008, .W64)])
#guard accessChecks (s.storeAvx (w := .W256) 0x1000 0 fun s => .done (s, 0)) ==
  some ([], [(0x1000, .W64), (0x1008, .W64), (0x1010, .W64), (0x1018, .W64)])
#guard accessChecks (s.storeAvx (w := .W512) 0x1000 0 fun s => .done (s, 0)) ==
  some ([], [(0x1000, .W64), (0x1008, .W64), (0x1010, .W64), (0x1018, .W64),
             (0x1020, .W64), (0x1028, .W64), (0x1030, .W64), (0x1038, .W64)])

/-- Runs `e`, granting every access check; `none` on a fault, an access outside the data memory,
`undefined`, or anything unimplemented. -/
private partial def run : Effects → Option MachineData
  | .done (s, _) => some s
  | .require_read_access _ _ ok | .require_write_access _ _ ok | .require_exec_access _ ok => run (ok ())
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
    .done (s.setAvxReg (.zmm .mm0) v, 0))).map (·.zmms.zmm0)

/-- The `n`-bit value whose `bits`-bit lanes are `f 0, f 1, ...`. -/
private def lanes (n bits count : Nat) (f : Nat → Nat) : BitVec n :=
  (List.range count).foldl (fun acc i => acc ||| (BitVec.ofNat n (f i) <<< (bits * i))) 0

/-- Bytes 1, 2, ..., 32. -/
private def bytes32 : List UInt8 := (List.range 32).map (·.toUInt8 + 1)

-- Sub-vector memory operand sizes (1, 2, 4, 8, 16, and 32 bytes).
#guard [1, 2, 4, 8, 16, 32].all fun n => loadZmm (some n) bytes32 == some (lanes 512 8 n (· + 1))
#guard loadZmm (some 32) (bytes32.take 31) == none
#guard loadZmm (some 3) bytes32 == none

