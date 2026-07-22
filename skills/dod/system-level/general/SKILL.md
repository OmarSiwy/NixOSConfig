---
name: general-programming
description: "General programming principles: Data-Oriented Design (Mike Acton, Andrew Kelley), API Design (Casey Muratori), negative-overhead abstraction. Loaded for design questions, architecture decisions, and code review across any language."
---

# General Programming Principles

This skill provides the decision framework for designing data structures, APIs, and abstractions. It's language-agnostic — the language-specific companions (rust.md, zig.md) show how to realize these ideas in code.

The full theory lives in [../../Brogramming/principles/](../../Brogramming/principles/SKILL.md). Load specific parts when depth is needed:

| Decision | Load | Key idea |
|---|---|---|
| AoS vs SoA, hot/cold split, index vs pointer | [foundations.md Part I](../../Brogramming/principles/foundations.md) | Layout follows access pattern. Data touched together lives together. |
| Should I abstract this? How? | [foundations.md Part II](../../Brogramming/principles/foundations.md) | Zero-cost if the optimizer sees through it. Grow by compression, not speculation. |
| How should this API look? | [foundations.md Part III](../../Brogramming/principles/foundations.md) | Write the usage code first. Caller owns memory. Expose fine-grained + convenience. |
| Which allocator? Arena vs pool vs bump? | [foundations.md Part IV](../../Brogramming/principles/foundations.md) | Match allocator lifetime to data lifetime. Reserve up front. |
| How to parallelize? | [foundations.md Part V](../../Brogramming/principles/foundations.md) | Partition, don't share. Disjoint slices → no locks. |
| How to make illegal states impossible? | [foundations.md Part VI](../../Brogramming/principles/foundations.md) | Parse, don't validate. Sum types over flag-bags. Newtypes for IDs. |
| Will this autovectorize? | [foundations.md Part VII](../../Brogramming/principles/foundations.md) | SoA + contiguous + branchless + no loop-carried dep = vectorizes. |

## Quick reference (no file load needed)

### Five questions before writing any code (Acton)

1. **What data goes in? What data comes out?** — State the transformation. A function, module, or service is a mapping from input bytes to output bytes. If you can't state it, you don't understand the problem.
2. **How many?** — "Where there is one, there are many." Design for the collection, not the element. A single `Particle` struct is a lie — you have 10,000 of them, and how you lay those 10,000 out is the real design decision.
3. **What's the access pattern?** — Which fields are read together, by which functions, how often? This determines AoS vs SoA. If physics reads `pos` and `vel` but not `color`, those fields should be in separate arrays.
4. **What's the lifetime?** — Does this data live for a phase (arena), for the program (static), or individually (pool)? Match allocator to lifetime. A per-frame arena means zero individual frees.
5. **Is this parallelizable?** — Disjoint partitions of the same transformation? If yes, design for data parallelism from the start — SoA makes the partition boundaries clean.

### One API rule (Muratori)

Write the usage code first. The API is defined by the call site, not by the implementer's mental model. Before writing `fn process(...)`, write the code you *wish* you could call. Then implement to match.

Every non-atomic function should be expressible via finer-grained functions. Expose both the convenience call and the primitives it's built on.

### One abstraction rule

Grow by compression, not speculation. Write the concrete code. When you see the same pattern repeat in two or three places, factor it out. A little duplication is cheaper than the wrong abstraction. Two blocks that merely look alike but evolve differently were never the same thing.

### Code review lens

When reviewing code (yours or others'), scan for these DOD smells:

- [ ] Can you state what data goes in and comes out for every function?
- [ ] Any pointer that could be an index? (8 bytes → 4 bytes, relocatable)
- [ ] Any bool inside a hot struct that could be out-of-band?
- [ ] Any `dyn`/vtable in a hot loop that could be an `enum` + `match`?
- [ ] Any abstraction not discovered by compression (speculative)?
- [ ] Any field wider than necessary? (`u64` where `u16` fits?)
- [ ] Allocations in a hot loop that could be hoisted or arena'd?
- [ ] Shared mutable state that could be partitioned?
- [ ] Validation repeated downstream that could be parsed once at the boundary?

## For full analysis

Use [../../Brogramming/analyze-data-layout/](../../Brogramming/analyze-data-layout/SKILL.md) for automated type map, access pattern heatmap, and DOD restructure across an entire module.
