#!/usr/bin/env python3
"""Differential fuzzer: runs random x86_64 sequences (krakenrunner_x64 --generate) on the hardware,
recording the observable state after every instruction and any fault, and asks Kraken for the values
of its `undefined` choices (an oracle, see Kraken/X64/Observe.lean) under which Semantics.lean
reproduces each run (--observe). The reproduced runs can be written out as Lean statements
(--lean-out)."""

import argparse
import collections
import json
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from asm_tests import (KRAKEN_RUNNER, LD_STACK, REGS, SAFE_YMMS, STACK, STACK_SIZE, STACK_SECTION,
                       reset_state)

# A snapshot of the observable state: GPRs, rflags, ymms, then the stack (see `parse_snapshot`).
YMM_BASE = 8 * len(REGS) + 8
MEM_BASE = YMM_BASE + 32 * len(SAFE_YMMS)
SNAP_BYTES = MEM_BASE + STACK_SIZE
# A fault record: instruction index, signal, si_code, si_addr (see `run_hardware`).
FAULT_BYTES = 4 * 8
# rt_sigaction flags: SA_SIGINFO | SA_ONSTACK | SA_RESTORER.
SA_FLAGS = 0x4 | 0x08000000 | 0x04000000
ALTSTACK_BYTES = 1 << 16
SIGILL, SIGTRAP, SIGBUS, SIGFPE, SIGSEGV = 4, 5, 7, 8, 11
SIGNAL_NAMES = {SIGILL: "SIGILL", SIGTRAP: "SIGTRAP", SIGBUS: "SIGBUS", SIGFPE: "SIGFPE", SIGSEGV: "SIGSEGV"}
SI_KERNEL = 0x80


def kraken(*args, inp=None):
    res = subprocess.run([KRAKEN_RUNNER, *map(str, args)], input=inp, stdout=subprocess.PIPE, check=True)
    return json.loads(res.stdout)


def snapshot_macro():
    """A `snapshot slot` assembler macro that stores the observable state at `slot` (SNAP_BYTES bytes,
    the layout `parse_snapshot` reads) without changing it: rflags is read through a scratch stack,
    and rax, rsp and ymm0, the only registers it uses, are restored from their saved values."""
    lines = [f"movq %{r}, \\slot+{8 * i}(%rip)" for i, r in enumerate(REGS)]
    lines += ["leaq _scratch+64(%rip), %rsp", "pushfq", "popq %rax", f"movq %rax, \\slot+{8 * len(REGS)}(%rip)"]
    lines += [f"vmovups %{y}, \\slot+{YMM_BASE + 32 * i}(%rip)" for i, y in enumerate(SAFE_YMMS)]
    lines += [f"movq ${STACK - STACK_SIZE}, %rax"]
    for off in range(0, STACK_SIZE, 32):
        lines += [f"vmovups {off}(%rax), %ymm0", f"vmovups %ymm0, \\slot+{MEM_BASE + off}(%rip)"]
    lines += [f"vmovups \\slot+{YMM_BASE}(%rip), %ymm0", f"movq \\slot+{8 * REGS.index('rsp')}(%rip), %rsp",
              "movq \\slot(%rip), %rax"]
    return ".macro snapshot slot\n    " + "\n    ".join(lines) + "\n.endm"


def hardware_asm(seqs):
    """One binary that runs every sequence from Kraken's initial state (`initData`), snapshotting the
    state after each instruction, and writes the fault records, then the snapshots, to stdout. A
    fault ends its sequence: the handler records it and resumes at the next sequence."""
    blocks, offset = [], 0
    for j, seq in enumerate(seqs):
        lines = seq.split("\n")
        body = [f"leaq _end_{j}(%rip), %rax", "movq %rax, _resume(%rip)",
                f"leaq _faults+{FAULT_BYTES * j}(%rip), %rax", "movq %rax, _fault(%rip)",
                "movq $-1, _instr(%rip)", reset_state()]
        for i, line in enumerate(lines):
            body += [f"movq ${i}, _instr(%rip)", line, f"snapshot _states+{offset + SNAP_BYTES * i}"]
        body += [f"movq ${len(lines)}, _faults+{FAULT_BYTES * j}(%rip)", f"_end_{j}:"]
        blocks.append("\n    ".join(body))
        offset += SNAP_BYTES * len(lines)
    return f"""
.bss
_states: .space {offset}
_faults: .space {FAULT_BYTES * len(seqs)}
_scratch: .space 64
_altstack: .space {ALTSTACK_BYTES}
_resume: .space 8                 # where a fault resumes: the end of the current sequence
_fault: .space 8                  # the current sequence's fault record
_instr: .space 8                  # the index of the instruction being run
{STACK_SECTION}
.data
_altstack_desc: .quad _altstack, 0, {ALTSTACK_BYTES}       # stack_t: ss_sp, ss_flags, ss_size
_action: .quad _handler, {SA_FLAGS}, _restorer, 0        # the kernel's sigaction: handler, flags, restorer, mask
.text
{snapshot_macro()}
.globl _start
_start:
    # sigaltstack(&_altstack_desc, NULL): a sequence may have moved rsp anywhere, so faults are
    # handled on their own stack.
    leaq _altstack_desc(%rip), %rdi
    xorl %esi, %esi
    movl $131, %eax
    syscall
    # rt_sigaction(sig, &_action, NULL, 8) for SIGILL, SIGTRAP, SIGBUS, SIGFPE and SIGSEGV.
    .irp sig, {", ".join(map(str, SIGNAL_NAMES))}
    movl $\\sig, %edi
    leaq _action(%rip), %rsi
    xorl %edx, %edx
    movl $8, %r10d
    movl $13, %eax
    syscall
    .endr
    {"".join(blocks)}
    leaq _altstack+{ALTSTACK_BYTES}(%rip), %rsp
    leaq _faults(%rip), %rsi
    movq ${FAULT_BYTES * len(seqs)}, %rdx
    call _write
    leaq _states(%rip), %rsi
    movq ${offset}, %rdx
    call _write
    movl $60, %eax                # exit(0)
    xorl %edi, %edi
    syscall

# write(stdout, rsi, rdx), retrying partial writes.
_write:
    movl $1, %eax
    movl $1, %edi
    syscall
    testq %rax, %rax
    js 1f
    addq %rax, %rsi
    subq %rax, %rdx
    jnz _write
1:  ret

# Signal handler (rdi = signal, rsi = siginfo_t*, rdx = ucontext_t*): records the fault in the
# current sequence's record and resumes at the end of the sequence.
_handler:
    movq _fault(%rip), %rax
    movq _instr(%rip), %rcx
    movq %rcx, 0(%rax)
    movq %rdi, 8(%rax)
    movslq 8(%rsi), %rcx          # si_code
    movq %rcx, 16(%rax)
    movq 16(%rsi), %rcx           # si_addr
    movq %rcx, 24(%rax)
    movq _resume(%rip), %rcx
    movq %rcx, 168(%rdx)          # uc_mcontext.gregs[REG_RIP]
    ret
_restorer:
    movl $15, %eax                # rt_sigreturn
    syscall
"""


def parse_snapshot(raw):
    """A snapshot as `--observe` takes it: GPRs, rflags, each ymm as four little-endian 64-bit words,
    and the stack bytes that are not the initial 0xff."""
    regs = list(struct.unpack_from(f"<{len(REGS)}Q", raw))
    (rflags,) = struct.unpack_from("<Q", raw, 8 * len(REGS))
    ymms = [list(struct.unpack_from("<4Q", raw, YMM_BASE + 32 * i)) for i in range(len(SAFE_YMMS))]
    mem = [[i, b] for i, b in enumerate(raw[MEM_BASE:]) if b != 0xff]
    return {"regs": regs, "rflags": rflags, "ymms": ymms, "mem": mem}


def run_hardware(seqs):
    """For each sequence, the snapshots after the instructions that completed and the fault that
    stopped it, `(signal, si_code, si_addr)`, or None."""
    with tempfile.TemporaryDirectory() as tmp:
        src, obj, exe = (Path(tmp) / f"batch.{ext}" for ext in ("S", "o", "bin"))
        src.write_text(hardware_asm(seqs))
        subprocess.run(["as", "-o", obj, src], check=True)
        # `--section-start` maps the `.stack` section at a fixed address, giving the binary exactly
        # Kraken's stack, so rsp (and anything computed from it, e.g. PF of `subq $8, %rsp`) matches.
        subprocess.run(["ld", LD_STACK, "-o", exe, obj], check=True)
        raw = subprocess.run([exe], check=True, capture_output=True, timeout=60).stdout
    runs, offset = [], FAULT_BYTES * len(seqs)
    for j, seq in enumerate(seqs):
        n = seq.count("\n") + 1
        instr, signo, code, addr = struct.unpack_from("<qqqQ", raw, FAULT_BYTES * j)
        assert signo or instr == n, f"sequence {j} ran {instr} of {n} instructions without a fault"
        done = instr if signo else n
        snaps = [parse_snapshot(raw[offset + SNAP_BYTES * i:offset + SNAP_BYTES * (i + 1)]) for i in range(done)]
        runs.append((snaps, (signo, code, addr) if signo else None))
        offset += SNAP_BYTES * n
    return runs


def signal_matches(ending, fault):
    """Whether the hardware's fault, `(signal, si_code, si_addr)` or None, shows Kraken's ending."""
    kind = ending["kind"]
    if kind == "ok" or fault is None:
        return kind == "ok" and fault is None
    signo, code, addr = fault
    if kind == "fault":
        # #GP and hlt (a #GP in user mode) are SIGSEGV.
        return signo == {"#DE": SIGFPE, "#UD": SIGILL, "#BP": SIGTRAP}.get(ending["exception"][:3], SIGSEGV)
    if kind == "unaligned":
        return signo == SIGSEGV and code == SI_KERNEL  # #GP(0)
    if kind == "unmapped":
        lo, w = ending["addr"], ending["w"]
        # An access reaching a non-canonical address is a #GP with no address (or a #SS, which
        # Linux reports as SIGBUS, when made through rsp or rbp); the kernel half and unmapped user
        # addresses page-fault at the address.
        return signo in (SIGSEGV, SIGBUS) and (lo + w > 1 << 47 or lo <= addr < lo + w)
    return False


def describe_ending(ending):
    kind = ending["kind"]
    if kind == "ok":
        return "completes"
    where = f"instruction {ending['instr']}"
    if kind == "fault":
        return f"{where}: {ending['exception']}"
    if kind == "unsupported":
        return f"{where}: {ending['message']}"
    return f"{where}: {kind} access to {ending['w']} bytes at {ending['addr']:#x}"


def describe_fault(fault):
    if fault is None:
        return "completes"
    signo, code, addr = fault
    return f"{SIGNAL_NAMES.get(signo, signo)} (si_code {code}, si_addr {addr:#x})"


def numbered(seq):
    return "\n".join(f"{i:3}: {line}" for i, line in enumerate(seq.split("\n")))


def lean_file(decls, cmdline):
    cpu = "this machine"
    try:
        for line in Path("/proc/cpuinfo").read_text().split("\n"):
            if line.startswith("model name"):
                cpu = line.split(":", 1)[1].strip()
                break
    except OSError:
        pass
    return f"""import Kraken.X64.Observe

/-! Hardware observations recorded by `{cmdline}` on {cpu}. Each states that the hardware's behaviour
is one Semantics.lean allows: under the given oracle (the values of its `undefined` choices, see
Kraken/X64/Observe.lean) Kraken computes what the hardware did. -/

""" + "\n\n".join(decls) + "\n"


def outside_data_memory(ending, states):
    """Whether Kraken's ending is an access outside its data memory that the hardware, which
    completed the instruction, may well have had memory for: Kraken's data memory is only its
    stack, but the hardware has whole pages around it (an address the hardware surely has nothing
    at is a Kraken bug, though). For an AVX access, Semantics.lean does not even report the
    address, so nothing can be checked."""
    if ending is None:
        return False
    if ending["kind"] == "unmapped":
        return ending["instr"] < len(states) and not ending["surelyUnmapped"]
    return ending["kind"] == "unsupported" and "nonmem" in ending["message"]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--batches", type=int, default=5)
    p.add_argument("--batch-size", type=int, default=100)
    p.add_argument("--length", type=int, default=12)
    p.add_argument("--only", default="", help="comma-separated mnemonic prefixes to draw instructions from")
    p.add_argument("--lean-out", type=Path, help="write the reproduced runs to this file as Lean statements")
    args = p.parse_args()

    failures = total = unobservable = 0
    endings = collections.Counter()
    decls = []
    start = time.perf_counter()
    for b in range(args.batches):
        seed = args.seed + b
        seqs = kraken("--generate", seed, args.batch_size, args.length, *filter(None, args.only.split(",")))
        hw = run_hardware(seqs)
        runs = [{"seq": seq, "states": states} for seq, (states, _) in zip(seqs, hw)]
        results = kraken("--observe", inp=json.dumps(runs).encode())
        for i, (seq, (states, fault), r) in enumerate(zip(seqs, hw, results, strict=True)):
            ending = r["ending"]
            if r["ok"] and signal_matches(ending, fault):
                endings[ending["kind"]] += 1
                decls.append(f"-- seed {seed}, sequence {i}\n{r['lean']}")
                continue
            if outside_data_memory(ending, states):
                unobservable += 1
                continue
            failures += 1
            kraken_says = [f"Kraken {describe_ending(ending)}"] if ending else []
            if r["ok"]:
                problem = kraken_says + [f"hardware {describe_fault(fault)}"]
            else:
                problem = ([f"instruction {r['instr']}: {r['error']}", *r["diff"][:20]] + kraken_says
                           + [f"hardware {describe_fault(fault)} after {len(states)} instructions"])
            print(f"\n[FAIL] seed={seed} seq={i}:\n{numbered(seq)}\n" + "\n".join(problem))
        total += len(seqs)
        faults = sum(n for k, n in endings.items() if k != "ok")
        print(f"batch {b + 1}/{args.batches}: {total} seqs, {total / (time.perf_counter() - start):.0f} seq/s, "
              f"{failures} failures, {endings['ok']} reproduced, {faults} faults, {unobservable} unobservable")
    if args.lean_out:
        args.lean_out.write_text(lean_file(decls, "Kraken/X64/Test/fuzz_x64.py " + " ".join(sys.argv[1:])))
        print(f"wrote {len(decls)} observations to {args.lean_out}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
