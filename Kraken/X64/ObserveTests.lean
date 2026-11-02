module

/-
  Concrete-evaluation tests of Kraken/X64/Observe.lean: resolving `undefined` choices from an
  oracle, classifying how a run ends, what is observed, and the Lean statement printed for a run.
-/

import Kraken.X64.Observe
meta import Kraken.X64.Observe

private def flags (cf pf af zf sf of : Bool) : StatusFlags := { cf, pf, af, zf, sf, of, df := false }

-- An oracle entry is read at the choice's own width: status flags from bits 0-5 (with df false),
-- wide bit-vectors without 64-bit truncation.
#guard NondetSupportingType.statusFlags.decode 0x2a == flags false true false true false true
#guard (NondetSupportingType.avx_bitvec .W128).decode (2 ^ 100 + 1) == 2 ^ 100 + 1

-- A deterministic sequence completes; only nonzero registers and non-initial stack bytes are
-- reported, with stack offsets from the bottom of the 800-byte stack.
#guard observe [] "movq $1, %rax\naddq $2, %rax" ==
  { state := { regs := { rax := 3, rsp := stackLocation }, status := flags false true false false false false },
    ending := .ok }
#guard (observe [] "movq $0x1234, -8(%rsp)").state.mem == [(792, 0x34), (793, 0x12), (794, 0), (795, 0), (796, 0), (797, 0), (798, 0), (799, 0)]
#guard (observe [] "movq $1, %rax\nmovq %rax, -16(%rsp)\nmovq %rax, -8(%rsp)\nmovups -16(%rsp), %xmm3").state.ymms ==
  [(3, 1#256 ||| 1#256 <<< 64)]

-- `andq` leaves AF undefined: the oracle decides it, and only its low bit matters.
#guard (observe [0] "andq $1, %rax").state.status == flags false true false true false false
#guard (observe [1] "andq $1, %rax").state.status == flags false true true true false false
#guard (observe [2] "andq $1, %rax").state.status == flags false true false true false false
-- Choices consume the oracle in order; a short oracle ends the run, with the state before the
-- instruction that needed it.
#guard (observe [1, 0] "andq $1, %rax\nandq $1, %rbx").state.status == flags false true false true false false
#guard observe [1] "andq $1, %rax\nandq $1, %rbx" ==
  { state := { regs := { rsp := stackLocation }, status := flags false true true true false false },
    ending := .unsupported 1 "the oracle has no value for an undefined choice" }

-- Endings: the instruction index counts from 0, and the state is the one before it.
#guard (observe [] "movq $1, %rax\nmovq (%rbx), %rcx").ending == .unmapped 1 0#64 8
#guard (observe [] "movq $1, %rax\nmovq (%rbx), %rcx").state.regs.rax == 1
#guard (observe [] "movq %rax, (%rbx)").ending == .unmapped 0 0#64 8
#guard (observe [] "movaps -8(%rsp), %xmm0").ending == .unaligned 0 (stackLocation.toBitVec - 8) 16
#guard (observe [] "pushq %rax\nret").ending == .unsupported 1 "jump"
#guard (observe [] "not an instruction").ending matches .unsupported 0 _
#guard (Effects.fault "#DE: divide by zero").run 3 [] matches (.error (.fault 3 "#DE: divide by zero"), [])
#guard (Effects.gp_unaligned 8#64 16).run 0 [7] matches (.error (.unaligned 0 8#64 16), [7])

-- The printed statement: the sequence is an exact string literal, one instruction per line.
#guard observationDecl "movq $1, %rax\nandq $3, %rax" [1] (observe [1] "movq $1, %rax\nandq $3, %rax") ==
  "example : ∃ o : Oracle, observe o \"movq $1, %rax\\n\\\n    andq $3, %rax\" = { state := { regs := { rax := 0x1, rsp := 0x7ffecafee200 }, status := { cf := false, pf := false, af := true, zf := false, sf := false, of := false, df := false } }, ending := .ok } :=\n  ⟨[0x1], by native_decide⟩"
#guard quoteLines "a\"b\\c\n\nd" == "\"a\\\"b\\\\c\\n\\\n    \\n\\\n    d\""
#guard quoteLines " a\nb" == "\" a\\nb\""
-- So the statement holds even when the parse error names a line.
#guard observationDecl "nop\nbogus" [] (observe [] "nop\nbogus") ==
  "example : ∃ o : Oracle, observe o \"nop\\n\\\n    bogus\" = { state := { regs := { rsp := 0x7ffecafee200 }, status := { cf := false, pf := false, af := false, zf := false, sf := false, of := false, df := false } }, ending := .unsupported 0 \"line 2: unsupported instruction: bogus\" } :=\n  ⟨[], by native_decide⟩"

-- And such statements check.
example : ∃ o : Oracle, observe o "movq $1, %rax\n\
    andq $3, %rax" = { state := { regs := { rax := 0x1, rsp := 0x7ffecafee200 }, status := { cf := false, pf := false, af := true, zf := false, sf := false, of := false, df := false } }, ending := .ok } :=
  ⟨[0x1], by native_decide⟩
example : ∃ o : Oracle, observe o "movq $1, %rax\n\
    movq %rax, -16(%rsp)\n\
    movq %rax, -8(%rsp)\n\
    movups -16(%rsp), %xmm3\n\
    movaps -8(%rsp), %xmm0" = { state := { regs := { rax := 0x1, rsp := 0x7ffecafee200 }, status := { cf := false, pf := false, af := false, zf := false, sf := false, of := false, df := false }, ymms := [(3, 0x10000000000000001#256)], mem := [(784, 0x1), (785, 0x0), (786, 0x0), (787, 0x0), (788, 0x0), (789, 0x0), (790, 0x0), (791, 0x0), (792, 0x1), (793, 0x0), (794, 0x0), (795, 0x0), (796, 0x0), (797, 0x0), (798, 0x0), (799, 0x0)] }, ending := .unaligned 4 0x7ffecafee1f8#64 16 } :=
  ⟨[], by native_decide⟩
