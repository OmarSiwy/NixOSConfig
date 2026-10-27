---
name: systems
description: Router for the systems-code skills — which one to reach for, in what order, and who wins when they disagree.
disable-model-invocation: true
---

# Systems skills

Every skill below is model-invoked and fires on its own; this page is the map for when you want to steer. The build order (what to settle before the first line, while writing, after) is `codebase-rules`; this page names the pieces and settles their conflicts.

## Which skill

| Situation | Skill |
|---|---|
| Laying out a program or subsystem; where a feature goes; pattern vs concrete code; translating a GoF pattern | `codebase-clean-code` — Data → Owners → Spines → Seams → Ladder → Drill → Record → Prove |
| A library, engine, SDK or FFI boundary someone else calls | `api-design` |
| Struct layout, SoA/AoS, field widths, hot/cold split, profiling a hot path | `data-oriented-design` |
| Writing or reviewing a `.zig` file; 0.16 → 0.17 port; does this abstraction cost anything | `zig` (`zero-cost.md` for the probe, `simd-first.md` for the lane axis) |
| Writing or reviewing a `.rs` file; same questions in Rust; explicit SIMD on stable | `rust` (`zero-cost.md`, `simd-first.md` with `fearless_simd`) |
| Extract or inline; file order; struct field vs parameter vs local; splitting files, flattening folders; does this meet the house style | `code-style` (checklist + `check_style.py`) |
| A data-dependent branch in a hot loop | `branchless` |
| A hot scalar loop to vectorize | `simd-loops` (after `branchless`) |
| Programmer-error contracts, capacities, bounded loops, asserts that remove bounds checks | `assertions` |
| A `pub` item, error set or module needs its doc comment | `doc-comments` |
| A GUI app, editor or canvas; choosing or fitting a GUI framework | `gui-architecture` |
| A lexer, parser, AST, IR, interner, diagnostics, or compiler goldens | `compiler-construction` |
| A circuit simulator engine: stamping, sparse LU, Newton, timestep control, device models | `spice-engine` |
| Test strategy, fuzzing, differential or golden testing, CI gates | `test-plan` |
| Applying all of this to an existing repo, block by block | `codebase-improvement` |

## Conflict rules

When two skills give different answers, these decide, in this order:

1. **Data layout beats code brevity.** A layout that `data-oriented-design` derived from the six questions stands even when it costs more lines, more parameters, or a less familiar shape.
2. **Ponytail decides how little code to write, never what shape the data takes.** `ponytail` cuts speculative code, wrappers and dependencies; it does not merge tables, widen fields, or fold SoA back into structs to save lines.
3. **The zero-cost proof comes before the abstraction.** Any seam at ladder rung 5 or above (`codebase-clean-code`'s `LADDER.md`) enters hot code only with a probe verdict of FOLDED, IDENTICAL, EQUIVALENT or NEGATIVE from the `zig` or `rust` skill's `zero-cost.md`.

Remaining rulings (Clean Code vs hot code, purity vs testability, measure before any performance rung) live in `codebase-rules`.
