# Kraken Assembly Test Suite

This directory contains the assembly-level test suite used to validate Kraken’s x86 semantics. It compares Kraken's internal state transitions against native execution using the GNU Assembler (`as`).

## Writing Tests

Tests are written as sequences of x86 instructions using **AT&T syntax**. The test runner executes these instructions through both Kraken and the host hardware, reporting a failure if the resulting register or flag states diverge.

### Best Practices

- **Keep tests atomic**: Write small, self-contained unit tests. Each file should target a single behavior or instruction variant.
- **Prioritize debuggability**: If a test fails, the culprit instruction should be immediately obvious. Avoid long, complex instruction chains that obfuscate the point of failure.
- **Isolate state**: Ensure the test clearly sets up the necessary register values before executing the target instruction.

### Handling Undefined Flags

Many x86 instructions leave specific status flags (e.g., `AF`, `OF`) in an undefined state. To prevent test flakes, use a preamble to exclude these flags from the comparison:
```
# Undefined flags: sf, zf, af, pf

movq $100, %rax
movq $7, %rbx
mulq %rbx 
```
Note: Always consult the [instruction manual](https://www.felixcloutier.com/x86/) to identify which flags are architecturally undefined for a given instruction.

## Running Tests

Ensure you have `binutils` (specifically `as` and `ld`) installed. Currently, the test suite is verified on **Ubuntu (latest)**; other platforms may produce incompatible results.

### Execution Commands
```bash
# Run all tests
python3 Kraken/X64/Test/asm_tests.py Kraken/X64/Test/asm

# Run a specific test
python3 Kraken/X64/Test/asm_tests.py Kraken/X64/Test/asm/test_arithmetic.S

# Manual inspection of Kraken output
./.lake/build/bin/krakenrunner_x64 Kraken/X64/Test/asm/test_arithmetic.S
```

## Differential Fuzzing

`fuzz_x64.py` runs random instruction sequences (`krakenrunner_x64 --generate`) on the hardware, recording the registers, flags, ymm0-15 and the stack after every instruction, and the signal if an instruction faults. Where Semantics.lean leaves a result `undefined`, the hardware made some choice; `krakenrunner_x64 --observe` recovers those choices from the recorded states (an *oracle*, see `Kraken/X64/Observe.lean`), so that each run becomes the statement "there is an oracle under which Kraken computes what the hardware did". A run is a failure when no oracle does, or when Kraken's reason for the sequence to stop (a `#DE`, a misaligned SSE access, an access outside the stack) does not match the hardware's signal.

```bash
# 10 batches of 100 sequences (the CI configuration)
python3 Kraken/X64/Test/fuzz_x64.py --batches 10 --batch-size 100 --seed 1

# Only shifts and rotates, and write the reproduced runs out as Lean statements
python3 Kraken/X64/Test/fuzz_x64.py --only sh,sa,ro,rc --lean-out /tmp/observations.lean
lake env lean /tmp/observations.lean
```

Each statement in the output is checked by evaluation (`native_decide`), with the extracted oracle as the witness:
```lean
example : ∃ o : Oracle, observe o "movq $1, %rax\n\
    andq $3, %rax" = { state := { regs := { rax := 0x1, rsp := 0x7ffecafee200 }, status := { cf := false, pf := false, af := true, zf := false, sf := false, of := false, df := false } }, ending := .ok } :=
  ⟨[0x1], by native_decide⟩
```