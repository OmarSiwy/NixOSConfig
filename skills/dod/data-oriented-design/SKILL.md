---
name: data-oriented-design
description: Data-oriented design principles for code layout and architecture. Enforces SoA layouts, hot/cold splitting, existence-based processing, cache-friendly access, arena allocation, and flat data structures. Use when writing Rust, Zig, or C code; designing entity/component systems; optimizing data layouts; reviewing struct definitions; refactoring OOP code toward data-oriented patterns; or when user mentions DOD, cache performance, SoA, ECS, or data layout.
---

# Data-Oriented Design

> "The purpose of all programs is to transform data. If you don't understand the data, you don't understand the problem." — Mike Acton

## When to Use

- Defining structs, components, or entity types
- Designing systems that process collections of things
- Refactoring OOP hierarchies or pointer-heavy code
- Reviewing data layout for performance
- Writing Zig code (comptime, explicit allocators, SIMD)
- Any code that iterates over more than ~64 elements

## Five Questions (answer before writing ANY code)

1. **What data goes in, what comes out?** State the transformation.
2. **How many?** Where there is one, there are many. Design for the collection, not the element.
3. **What's the access pattern?** Which fields are read together, how often, in what order — this decides AoS vs SoA.
4. **What's the lifetime?** Phase (arena), program (static), or individual (pool). Match allocator to lifetime.
5. **Is it parallelizable?** Disjoint partitions of the same transformation → design for data parallelism from the start.

## Core Rules

1. **Know your data first.** Before writing any struct or function, answer the five questions above. Design the layout from those answers.

2. **SoA by default.** Store parallel arrays of each field, not an array of structs. Switch to AoS ONLY when you always access all fields of an entity together in the same loop.

3. **Hot/cold split.** Fields accessed every frame (position, velocity) go in one struct. Fields accessed rarely (debug name, creation timestamp) go in a separate cold-data table indexed by the same ID.

4. **Existence-based processing.** If an entity has a component, it exists in that system's array. Never store a component with an `active: bool` or `Option<T>` to skip — add/remove from the array instead. No null checks, no type tags. Iterate what exists.

5. **Tables > Trees > Graphs.** Flat arrays with integer indices first. B-trees if you need ordered lookup. Pointer-heavy graphs are last resort. Indices into arenas, never raw pointers between objects.

6. **Arena allocation.** Allocate in bulk, free in bulk. Group by lifetime. An arena of `Bullet` lives and dies with the level — no per-bullet malloc/free.

7. **Sequential access.** Linear iteration over contiguous memory beats random access every time. Sort by access pattern, not by "logical" grouping. Prefetch-friendly > "clean" hierarchy.

8. **No hidden control flow.** (Zig/Acton) No virtual dispatch, no operator overloading that hides allocations, no implicit copies. Every branch and allocation visible at the call site.

## Workflows

### Designing a New Data Type

- [ ] List every field the type needs
- [ ] Classify each field: hot (accessed every tick/request) vs cold (occasional)
- [ ] Group hot fields into a dense struct; cold fields into a separate table
- [ ] Choose SoA (parallel arrays) unless ALL fields always accessed together
- [ ] Use indices (u32/u16) into arenas, not pointers or references
- [ ] Add a generation counter to indices if you need to detect stale handles

### Refactoring OOP to DOD

- [ ] Identify the base class hierarchy — flatten it
- [ ] Replace inheritance with composition: separate data tables per "component"
- [ ] Replace virtual dispatch with switch on a tag OR separate arrays per type
- [ ] Replace `HashMap<EntityId, Component>` with a dense packed array + sparse-to-dense map
- [ ] Delete getters/setters — expose the data directly or use bulk accessors

## Types

- **Parse, don't validate**: validate once at the boundary, return a refined type; downstream takes only the refined type and never re-checks.
- Sum types over flag-bags: an `enum` over a struct of bools whose combinations are mostly illegal.
- Newtypes for IDs, units, indices — a `UserId` cannot be confused with a `PostId`.
- Smallest integer that fits: `u16` if max < 65536, `u8` if max < 256. Never default to `usize`/`u64`.
- **Encode, don't polymorphize**: closed `enum` + `match` in hot loops. `dyn`/vtable only for genuinely open, cold sets.

## Review Checklist

Run against any code — each a checkable question, no vibes:

- [ ] **transformation** — can you state bytes-in/bytes-out for every function?
- [ ] **layout** — collections match access pattern; no pointer that could be an index; no bool/rare field in hot struct; no field wider than its max value; no `dyn` in hot loop that could be an enum
- [ ] **memory** — caller owns allocation; nothing grows element-wise in a loop; nothing allocates per-iteration that an arena or reused buffer could hoist
- [ ] **parallel** — shared mutable state that could be partitioned; per-thread hot data on separate cache lines
- [ ] **types** — no flag-bag that should be a sum type; no validation repeated downstream of a boundary that could parse once
- [ ] **compression** — no abstraction that wasn't discovered by repetition
- [ ] **verify** — hot loops confirmed to vectorize, or the blocking branch/access identified

## Language Companions

Auto-detect project language, load the companion:

| Language | Companion | Key primitives |
|----------|-----------|---------------|
| Rust | [rust.md](rust.md) | `soa_derive`, `slotmap`, `bumpalo`, `rayon`, `enum` + `match`, `NonZero*` |
| Zig | [zig.md](zig.md) | `MultiArrayList`, `enum(u32)`, `packed struct`, `ArenaAllocator`, `@Vector` |

See [foundations.md](foundations.md) for the full theoretical grounding (Parts I–VII: Acton, Kelley, Muratori).

See [REFERENCE.md](REFERENCE.md) for extended anti-patterns and Zig-specific guidance.
