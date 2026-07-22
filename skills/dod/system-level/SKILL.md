---
name: system-level
description: "Router for system-level programming skills. Auto-detects language (Rust, Zig) and intent (write, simplify, design) then loads the relevant sub-skill. Use when writing Rust or Zig code, simplifying existing code, or applying data-oriented / API design principles."
---

# System-Level Programming Skills

Router. Detects context, loads the minimum set of companions needed. **Do not load all files upfront** — load only what the detected intent requires.

## 1. Detect intent

| User intent | What to load | Why |
|---|---|---|
| Writing new Rust code | [rust-style/SKILL.md](rust-style/SKILL.md) + [shared/problem-mapping.md](shared/problem-mapping.md) + [shared/pseudocode.md](shared/pseudocode.md) | Problem mapping → pseudocode → implement with Rust style rules |
| Writing new Zig code | [zig-style/SKILL.md](zig-style/SKILL.md) + [shared/problem-mapping.md](shared/problem-mapping.md) + [shared/pseudocode.md](shared/pseudocode.md) | Problem mapping → pseudocode → implement with Zig style rules |
| Simplifying existing code | [simplify/SKILL.md](simplify/SKILL.md) | Extract pseudocode from existing file → fresh-eyes → rewrite |
| Design / architecture questions | [general/SKILL.md](general/SKILL.md) | DOD, API design, negative-overhead principles |
| Code review | Language skill + [general/SKILL.md](general/SKILL.md) | Style rules + DOD review lens |

## 2. Shared process (both languages)

When writing new code in Rust or Zig, **always** run these steps in order before writing any real code:

1. **Map to architectural pattern** — identify which patterns from [shared/problem-mapping.md](shared/problem-mapping.md) the problem maps to. State the mapping explicitly: "This is [pattern] because [reason]."
2. **Decompose into algorithmic subproblems** — name the subproblems, state complexities, default to cache-friendly (Tier 1) algorithms. See [shared/problem-mapping.md](shared/problem-mapping.md).
3. **Write pseudocode** — create a `.pseudocode` file capturing the data flow. Review it with fresh eyes. See [shared/pseudocode.md](shared/pseudocode.md).
4. **Implement minimally** — translate the pseudocode line-by-line using the detected language's style rules. Don't add what the pseudocode didn't say.

Skipping these steps is acceptable only for one-line fixes, mechanical changes, or trivially obvious code (< 20 lines).

## 3. Foundations

All skills here build on the data-oriented, API design, and negative-overhead principles documented in [../Brogramming/principles/](../Brogramming/principles/SKILL.md). Load that companion when DOD-specific decisions arise:

- **Layout decision** (AoS vs SoA, hot/cold split, index vs pointer) → load [foundations.md Parts I, III](../Brogramming/principles/foundations.md)
- **Memory decision** (arena vs pool vs bump, reserve vs grow) → load [foundations.md Part IV](../Brogramming/principles/foundations.md)
- **Type design** (parse-don't-validate, sum types, newtypes) → load [foundations.md Part VI](../Brogramming/principles/foundations.md)
- **SIMD / vectorization** → load [foundations.md Part VII](../Brogramming/principles/foundations.md)
- **Full module DOD analysis** → load [analyze-data-layout](../Brogramming/analyze-data-layout/SKILL.md)

## 4. Quick reference (no file load needed)

Three questions before writing any code (Acton):
1. **What data goes in? What data comes out?**
2. **How many?** (Where there is one, there are many.)
3. **What's the access pattern?** (Which fields read together, how often?)

One API rule (Muratori): write the usage code first. The API is defined by the call site.

One abstraction rule: grow by compression, not speculation. Concrete first, abstract only when patterns genuinely repeat.
