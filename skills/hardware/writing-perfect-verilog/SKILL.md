---
name: writing-perfect-verilog
description: Reference for writing, editing, and reviewing synthesizable SystemVerilog RTL that reads top-down. Use when the user writes or edits Verilog/SystemVerilog, reviews RTL, asks about always blocks, flip-flops, FSMs, latches, blocking vs nonblocking, reset, width matching, case statements, or clock-domain crossing.
---

RTL is read far more than it is written, and it is read by someone reconstructing hardware in their head from text. **Readability** — a reader rebuilding the whole module in one downward pass, declarations then flops then logic, without jumping around — is the root virtue; every rule below serves it. The rules are not aesthetic. In RTL a readability failure is usually also a *silicon* failure: the same scattered logic that stalls the reader hides the inferred latch, the race, the missed synchronizer. Making the code legible and making it correct are the same act.

**Bold terms** are defined in [`GLOSSARY.md`](GLOSSARY.md); look them up there for the full meaning.

The consensus this skill encodes comes from the lowRISC Comportable style guide (naming, suffixes, formatting, language-feature rules) and Cliff Cummings' Sunburst Design papers (the nonblocking guidelines and the FSM coding style). Prefer **SystemVerilog-2017** (IEEE 1800-2017) for new RTL.

## Downflow

The one principle the rest lean on: a module reads **top-down**, datapath flowing downward. A signal is *declared* above where it is *driven*, and *driven* above where it is *consumed*, so when the reader meets a name its origin is always behind them, never ahead. Implicit net declarations are therefore banned — every signal is declared before use — and declarations sit close to first use so the type is never far from the reader's eye. Break **downflow** and you force the upward jump that this whole skill exists to prevent; it is the disease every failure mode below is a symptom of.

The reader's pass through a well-formed module, each region answering the question the last one raised:

1. **Header** — `module`, parameters, then ports: clock and reset first, then inputs, then outputs, one per line, direction and width visible at a glance.
2. **Params & localparams** — every magic number named here, so the body carries no bare literals.
3. **Typedefs & state enums** — the module's vocabulary, especially the FSM's, before any behaviour.
4. **Declarations** — all signals, each **`_d`/`_q`** pair adjacent, grouped by the block that drives them.
5. **Sequential logic** — the `always_ff` flops. What holds state, made obvious first.
6. **Combinational logic** — the `always_comb` and `assign` that compute the `_d` and the outputs.
7. **Submodule instances** — leaf connections last, once the local fabric is understood.

A signal used above its declaration, an output assigned in three scattered blocks, a param buried mid-body — each is a break in the pass and the first thing to fix.

## dq

The **`_d`/`_q` convention** is the load-bearing **leading word** of readable RTL. `_q` is a signal *as it leaves a flop* — the registered, held value. `_d` is the value *about to enter* that flop on the next clock edge. Read a name, know its timing, without tracing a wire.

The payoff is structural, not cosmetic. Every flop collapses to one trivial, identical `always_ff` that does nothing but copy `_d` into `_q`; *all* the design — the actual logic — lives in `always_comb` blocks computing `_d` from `_q`. Sequential blocks become boilerplate the reader skims; combinational blocks become the one place intent lives. The reader learns where to look and never relearns it.

```systemverilog
// Sequential — boilerplate, skimmed. One block, one job: hold state.
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) count_q <= '0;
  else         count_q <= count_d;
end

// Combinational — the design. count_d defined on every path (see defaults).
always_comb begin
  count_d = count_q;                 // default: hold
  if (incr_i) count_d = count_q + 1'b1;
end
```

Suffix the rest for the same reason, and reserve each suffix to its one meaning so it stays trustworthy: `_i`/`_o`/`_io` on ports, `_n` on active-low, `_ni` on an active-low input reset, `_q`/`_d` on flopped state, `_e` on an enum type, `_t` on other typedefs. A stray `_q` on a wire that never sees a flop poisons the convention for every future read — **suffix rot** is the failure, and the convention only pays if it is absolute.

## defaults

An unintended **latch** is the canonical RTL bug, and it is a readability failure first: a combinational path where the reader cannot see what a signal becomes. The defence is a rule the reader verifies *locally*, at the top of the block, before reading a single branch:

**Every `always_comb` opens by assigning a default to every signal it drives.** With defaults set first, no `if`/`case` path can leave a signal unassigned, so no latch can form — and the reader confirms latch-freedom by reading one region, not by simulating every branch. This is why `_d = _q` as the first line is idiomatic: "hold unless something below overrides" is both the safe default and the readable one. Every `case` carries a `default:` arm for the identical reason.

## blocking

The delimiter is not a style choice; it is how the reader knows the timing, and the wrong one makes simulation disagree with synthesis. Cummings' guidelines, distilled to what synthesizable RTL needs:

- **Sequential logic → nonblocking `<=`.** Flops assign with `<=`, which mimics real pipelined-register behaviour and eliminates the races that plague blocking flops.
- **Combinational logic → blocking `=`.** Logic in an `always_comb` assigns with `=`.
- **Never mix `<=` and `=` in one block.** The block's kind and its delimiter agree, always.
- **One signal, one block.** Never assign the same variable from more than one `always` block — to know its value the reader would have to find and merge every block that touches it, which is exactly **downflow** breaking down.

Mechanically: `always_ff` for flops, `always_comb` for logic, `assign` for simple continuous wires — prefer `assign` wherever practical. Never bare `always`. Never the `#0` delay. The block type alone should tell the reader the timing before they read a line of its body.

## fsm

A state machine is where scattered RTL does the most damage, so it earns the strictest shape — the **two-block FSM**, Cummings' preferred style, three regions in downflow order, each a peer the reader meets once:

1. **State register** — the lone `always_ff`, copying `state_d` into `state_q`. Nonblocking only.
2. **Next-state logic** — one `always_comb`, a single `case (state_q)`, every state an arm, computing `state_d`. Opens with `state_d = state_q` (the default) so unlisted transitions hold.
3. **Output logic** — Moore outputs off `state_q` alone; Mealy outputs off `state_q` and inputs. Prefer **registered outputs** where glitch-free or timing-clean outputs matter — an extra flop stage, not combinational outputs that can glitch between states and eat the downstream clock budget.

Name states with an `enum` typedef, never bare parameters, and never smuggle a raw binary encoding in beside the symbolic names — that defeats the enum. The enum is the machine's vocabulary and waveform viewers print it, which is half the debugging win. Keep each FSM in its **own module**, unmingled with other logic, so both the reader and the synthesis/FSM tools can see it whole. One `case`, one default arm, and the machine reads top-to-bottom without a state diagram beside it.

```systemverilog
typedef enum logic [1:0] { StIdle, StRead, StDone } state_e;
state_e state_d, state_q;

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) state_q <= StIdle;
  else         state_q <= state_d;
end

always_comb begin
  state_d = state_q;                 // default: hold
  unique case (state_q)
    StIdle: if (go_i)   state_d = StRead;
    StRead: if (done_i) state_d = StDone;
    StDone:             state_d = StIdle;
    default:            state_d = StIdle;
  endcase
end
```

## width

Width mismatches are the silent-corruption class of RTL bug — they simulate, they synthesize, they truncate or zero-extend where the reader never looked. Make width explicit everywhere so the reader can check it by eye:

- **Size every literal.** Write `8'd0` / `'0` / `4'hF`, never a bare `0` or `15` in a sized context. `'0` and `'1` fill to context width and are the readable way to say all-zeros/all-ones.
- **Match widths on assignment and on port connections.** Left and right side agree; instance port and connected signal agree. A deliberate width change is written explicitly, not left to implicit resize.
- **No multi-bit signal in a boolean context.** Reduce it (`|vec`, `vec != '0`) so the intent is on the page rather than in the language's coercion rules.
- **Make the base obvious.** Bare numbers are decimal; hex and binary carry their `'h`/`'b`. Parenthesize any expression a reader would otherwise take to an operator-precedence chart.

## case

`case` is where priority, completeness, and don't-cares hide, so it earns its own discipline:

- **`unique case`** when arms are mutually exclusive and you want the tools to check it — but only when they truly are; a false `unique` is a synthesis/simulation mismatch waiting to fire. **`priority case`** when order matters. Plain `case` when neither guarantee applies.
- **Always a `default:` arm.** It carries the else-everything value and, with the top-of-block defaults, keeps the block latch-free.
- **Never `full_case` / `parallel_case`.** Cummings' "evil twins" — they let synthesis and simulation disagree about what the unlisted cases do. The `unique`/`priority` keywords express the same intent to both tools honestly; the pragmas do not.
- **Wildcards:** `case inside` for wildcard matching in SystemVerilog; `casez` only where Verilog-2001 compatibility forces it. Avoid `casex` — its X-matching hides bugs.

## reset

Reset is one decision, stated once and applied uniformly, so the reader learns it from the first flop and trusts it holds. Pick **synchronous or asynchronous** for the design and don't mix within it. Reset only what needs it — control and state, rarely wide datapath — and give every reset flop a defined value at the top of its `always_ff`, never a fall-through. The active-low reset (`rst_ni`, `negedge rst_ni`) is the common convention; whatever you pick, the suffix carries the polarity so no reader has to guess.

## cdc

A signal crossing clock domains without a synchronizer is a metastability bug that simulates perfectly clean and fails in silicon — invisible to the reader who most needs to see it. So make it the most visible line in the file, not the least. Mark every crossing by name (a suffix or clear prefix), contain each in a **named synchronizer submodule** — two-flop for a single bit, a handshake or gray-coded FIFO for a bus — and never let combinational logic sit between the domains. The crossing is the most dangerous thing in the module; treat invisibility, not the crossing itself, as the bug.

## naming

A name is the cheapest documentation and the only kind that never goes stale. lowRISC's construct casing, which lets a reader infer what a name *is* from how it's written:

- `lower_snake_case` — modules, packages, interfaces, instances, signals, ports, variables, functions, tasks, named blocks.
- `UpperCamelCase` — tunable parameters of parameterized modules; derived localparams.
- `ALL_CAPS` — `` `define `` macros and true constant localparams.
- `lower_snake_case_e` / `lower_snake_case_t` — enum types / other typedefs; `UpperCamelCase` enum members.

Spell concepts out — `rx_fifo_full`, not `rff` — because the reader budgets attention for logic, not decryption. Whole words, no abbreviations except the most common, descriptive over terse. Never end a name with `_<number>` (`foo_1`): synthesis tools use that for bus bits and it corrupts netlist reading. Never use a reserved word. Group signals that operate together with a shared prefix.

## comments

RTL structure already says *what* — the d/q suffixes, the block types, the FSM shape carry the mechanics. A comment restating them is a **no-op**: `// increment counter` over `count_d = count_q + 1'b1` costs a line and says nothing. Spend comments on what structure cannot show — the *why*: a protocol quirk, a timing assumption, a constant's origin, a workaround for a downstream bug, and any deliberate deviation from this guide (justify every exception in a comment, plus a lint waiver where the tool needs one). Header comments may frame major sections (Controller, Datapath) on a single line; skip the fence-of-slashes banners that clutter without informing. If a comment could be deleted without losing intent, delete it.

## Review checklist

Run these against any module, top to bottom. Each is a reader's-eye check with a **checkable** answer, not a vibe:

- **Downflow** — header, params, types, decls, `always_ff`, `always_comb`, instances, in that order. Any signal used above its declaration, any implicit net, is a break.
- **dq** — flops carry `_d`/`_q`; sequential blocks are boilerplate; all logic lives in comb; suffixes used only in their one meaning.
- **defaults** — every `always_comb` assigns defaults to all its outputs before any branch; every `case` has `default:`. No inferred latch.
- **blocking** — `<=` in every `always_ff`, `=` in every `always_comb`, never mixed; each signal driven from exactly one block; no bare `always`, no `#0`.
- **fsm** — enum states, one next-state `case` with a default, outputs separated, registered where it matters, own module.
- **width** — every literal sized; assignment and port widths match; no multi-bit boolean; bases explicit.
- **case** — `unique`/`priority` used honestly; `default:` present; no `full_case`/`parallel_case`; no `casex`.
- **reset** — one strategy across the module; every reset flop reset to a defined value.
- **cdc** — every crossing named and inside a synchronizer; no logic between domains.
- **naming & comments** — casing matches construct; names descriptive; comments explain *why*, not *what*; exceptions justified.

## Failure modes

Diagnose a hard-to-read (and usually hard-to-verify) module by which of these it shows. Each traces back to a broken **downflow**.

- **Scatter** — one signal driven across multiple blocks, or logic split so the reader must gather fragments to know a value. The pass breaks; this is the root disease the whole skill treats, and the multi-driver race is its silicon face.
- **Inferred latch** — a combinational path leaves a signal unassigned. Always a missing default; fix at the top of the block, never in the branch.
- **Timing surprise** — `<=` in combinational logic or `=` in a flop makes simulation and synthesis disagree. The delimiter didn't match the block.
- **Silent truncation** — a width mismatch that simulates and synthesizes while quietly dropping or padding bits. The literal wasn't sized, or the assignment widths weren't checked.
- **Magic number** — a bare literal in the body the reader can't source. It wanted a named `localparam` up top.
- **Silent crossing** — a CDC with no synchronizer and no marking. Simulates clean, fails in hardware, invisible on the page.
- **Suffix rot** — `_q`/`_n`/`_i` used loosely until they signal nothing. One misuse degrades every future read; the convention is all-or-nothing.
