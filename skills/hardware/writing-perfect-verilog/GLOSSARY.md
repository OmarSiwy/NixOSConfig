# Glossary

Full definitions for the **bold terms** in [`SKILL.md`](SKILL.md). The skill body keeps each term to the fewest words that anchor behaviour; the weight lives here.

**Readability** — the root virtue. A reader reconstructs the whole module in a single top-down pass without jumping upward. In RTL this is not cosmetic: the structures that make code legible (adjacent `_d`/`_q`, defaults-first, one driver per signal) are the same structures that make it correct, because the classic bugs — inferred latch, race, silent truncation, unsynchronized crossing — are precisely the things a broken reading pass hides.

**Downflow** — the governing principle. Datapath flows down the file: a signal is declared above where it is driven, and driven above where it is consumed, so a name's origin is always behind the reader. Enforced by two hard rules — no implicit net declarations (declare before use) and declarations close to first use — and expressed as the seven-region reader's pass (header → params → types → declarations → sequential → combinational → instances). Every failure mode is a break in downflow.

**`_d`/`_q` convention** — the load-bearing leading word. `_q` names a signal as it *leaves* a flip-flop (the registered, held value); `_d` names the value about to *enter* it on the next clock edge. The suffix carries timing, so the reader never traces a wire to learn it. Structurally it splits every design into skimmable boilerplate flops (`always_ff` copying `_d`→`_q`) and the one place logic lives (`always_comb` computing `_d` from `_q`).

**Leading word** — a compact concept already in the model's pretraining, reused so it accumulates a distributed definition and anchors a region of behaviour in the fewest tokens. In this skill: *downflow*, *dq*, *defaults*, *scatter*. In RTL culture more broadly: *flop*, *latch*, *Moore*/*Mealy*, *one-hot*. Naming a section after one recruits everything the model already knows about it.

**Latch** — memory the reader didn't ask for. When a combinational path leaves a signal unassigned on some branch, synthesis infers a level-sensitive latch to "remember" the old value. Almost always a bug, and always a readability failure first — the reader cannot see, locally, what the signal becomes. Prevented entirely by the defaults rule.

**defaults** — the latch-free-by-construction rule: every `always_comb` opens by assigning a default to every signal it drives, before any `if`/`case`. Because no path can then leave a signal unassigned, no latch can form, and the reader verifies this by reading one region rather than simulating every branch. `_d = _q` ("hold unless overridden") is the idiomatic default; a `default:` arm on every `case` is the same rule for case statements.

**Blocking (`=`) vs nonblocking (`<=`)** — the two procedural assignment operators, and the timing contract the reader reads off the delimiter. Blocking `=` evaluates and updates immediately, in order — correct for combinational logic. Nonblocking `<=` evaluates right-hand sides, then updates all left-hand sides at the end of the time step — modelling real registers and avoiding races, correct for sequential logic. Cummings' guidelines: sequential → `<=`, combinational → `=`, never mixed in one block, never the same signal from two blocks. The wrong operator makes simulation and synthesis disagree.

**Two-block FSM** — Cummings' preferred state-machine shape: one `always_ff` for the state register (`state_q <= state_d`) and one `always_comb` for next-state logic (a single `case (state_q)` computing `state_d`), with outputs derived separately. Reads top-down as a machine; the alternative one-block style folds state and next-state together and is harder to read and to get glitch-free.

**Registered outputs** — FSM (or module) outputs taken from a flip-flop rather than straight from combinational logic. Costs one cycle of latency but buys glitch-free, timing-clean outputs that don't eat the downstream clock budget. Preferred for outputs that leave the module or feed timing-critical paths.

**CDC (clock-domain crossing)** — a signal sampled in a different clock domain from the one that drove it. Without a synchronizer the receiving flop can go metastable; the failure simulates perfectly clean and only appears in silicon. Contained in a named synchronizer submodule (two-flop for a bit, handshake or gray-coded FIFO for a bus) with no combinational logic between domains. The danger is *invisibility*, so the fix is visibility: mark and name every crossing.

**No-op** — a comment or line the reader already knows from structure, so it costs tokens and attention to say nothing. `// increment counter` over `count_d = count_q + 1'b1` is the canonical example. The test: could it be deleted without losing intent? If yes, delete it. Comments should carry *why* (protocol quirks, timing assumptions, constant origins, deviations), never *what*.

**Scatter** — the root failure mode: one signal driven across multiple blocks, or logic fragmented so the reader must gather pieces to know a value. Breaks downflow directly, and its silicon face is the multi-driver race. Most other failure modes (latch, timing surprise, silent crossing) are specific shapes of scatter.

**Suffix rot** — the decay that follows using a reserved suffix (`_q`, `_n`, `_i`, `_d`) loosely, until it no longer signals its meaning. One `_q` on a non-flopped wire degrades every future read of every `_q` in the file. The suffix convention only pays if it is absolute, so this failure is all-or-nothing.
