module

public import Kraken.X64.Mnemonic
public import Lean.ToExpr
meta import Lean.Elab.Deriving.ToExpr

/-! Hint instructions (pause, fences, endbr64): architectural no-ops in single-threaded user code. -/

@[expose] public section

inductive HintOp
  | pause | lfence | mfence | sfence | endbr64
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic HintOp := ⟨mnemonics% HintOp⟩

inductive MemHintOp
  | prefetcht0 | prefetcht1 | prefetcht2 | prefetchnta | prefetchw
  deriving Repr, DecidableEq, Hashable, Lean.ToExpr

instance : Mnemonic MemHintOp := ⟨mnemonics% MemHintOp⟩
