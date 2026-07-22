---
name: analyze-data-layout
description: "Analyze a module/crate for Data-Oriented Design opportunities. Finds type redundancy, minimizes data sizes, optimizes access patterns for cache locality. Presents an HTML report, then rewrites on confirmation. Launches a dynamic workflow with scout -> analyst -> synthesis -> rewrite agents."
---

# Analyze Data Layout

Analyze an entire module or crate through the DOD lens: find every type, trace every access pattern, identify semantic overlap between types, propose restructured layouts, and rewrite on confirmation.

This skill builds on the foundations in [../data-oriented-design/foundations.md](../data-oriented-design/foundations.md) and the language companions ([../data-oriented-design/rust.md](../data-oriented-design/rust.md), [../data-oriented-design/zig.md](../data-oriented-design/zig.md)). It applies those principles systematically to an existing codebase via a multi-agent workflow.

## Glossary

Use these terms exactly. Full definitions in [LANGUAGE.md](LANGUAGE.md).

- **Type map** — catalog of every type in scope with field names, sizes, padding, and total footprint.
- **Semantic overlap** — two or more types that represent the same or overlapping real-world data. A `Point` that is a degenerate `Rect` that is a degenerate `Polygon` — three representations of the same geometry.
- **Canonical type** — the single type chosen to replace overlapping types. Level 2: a unified struct. Level 3: a flat buffer with index offsets.
- **Access pattern** — which fields are read/written together, by which functions, how often. Determines AoS vs SoA and hot/cold split.
- **Hot field** — accessed in the majority of passes over the collection. Lives in the main array.
- **Cold field** — accessed rarely (error paths, debug, metadata). Moves to a side table keyed by index.
- **Cache line utilization** — fraction of a fetched cache line (typically 64 bytes) that contains fields actually read by the current pass. Higher is better.
- **Restructure level** — the aggressiveness of the transform. Level 1: field reordering + padding elimination. Level 2: canonical type unification + SoA split. Level 3: flat buffer with index offsets into shared storage.

## Process

### 1. Scope & Detect

User invokes `/analyze-data-layout` and points at a module, crate, or directory.

1. Identify the language. Load the language-specific strategy:

| Language | SoA primitive | Arena/index primitive | Encoding primitive |
|----------|--------------|----------------------|-------------------|
| Rust | `soa_derive` / parallel `Vec`s | `slotmap` / `generational-arena` | `enum` + `match` |
| Zig | `std.MultiArrayList` | `NodeIndex = enum(u32)` | `union(enum)` + `packed struct` |
| C | Manual parallel arrays | `uint32_t` index into `malloc`'d array | `union` + tag `enum` |
| C++ | Template SoA wrapper / parallel `std::vector`s | `uint32_t` index | `std::variant` + `std::visit` |

2. Confirm scope with user: "Analyzing module `X` — N files, ~M types detected. Proceed?"

### 2. Scout (Agent)

Launch a **scout agent** that scans the entire module. It produces:

1. **Type map** — every struct/type with:
   - Field names, types, sizes
   - Padding bytes (computed from alignment rules)
   - Total sizeof
   - Number of instances allocated (if detectable from code)

2. **Semantic overlap graph** — types that represent the same or overlapping data:
   - Structural overlap: `Point(x,y)` fields are a subset of `Rect(x,y,w,h)`
   - Convertibility: code that converts between types (`.into()`, cast, constructor)
   - Shared field names/semantics across types

3. **Access pattern map** — for each type, which functions touch which fields:
   - Per-function field access list
   - Frequency estimate: hot path vs cold path (based on call graph position, loop nesting)
   - Read-only vs read-write per field per function

4. **Type relationship graph** — ownership, containment, reference relationships between all types in scope.

The scout agent passes this data forward as structured output.

### 3. Analyze (Workflow Fan-out)

Launch **one analyst agent per type** (or per type cluster if types overlap semantically). Each analyst receives:

- The type's entry from the type map
- Its access pattern data
- Its semantic overlap neighbors
- The language-specific strategy table

Each analyst runs all three phases in a single pass — they're coupled:

#### Phase 1: DOD Restructure

- **AoS vs SoA decision** — based on access patterns. If most passes read a subset of fields across many elements → SoA. If most passes read all fields of one element → AoS. Mixed → hybrid (SoA for hot fields, AoS for element-level ops).
- **Hot/cold split** — fields accessed < 10% of passes → cold. Move to side table.
- **Flatten hierarchies** — nested structs that are always accessed through the parent → inline the fields.

#### Phase 2: Minimize Data Size

- **Semantic dedup** — if this type overlaps with others, propose canonical type (Level 2). Show flat buffer alternative (Level 3) as option.
- **Shrink fields** — `u64` → `u32` if max value fits. `u32` → `u16`. `bool` → bitfield. Enum → smallest integer that fits variant count.
- **Eliminate derivable fields** — field whose value can always be computed from other fields → remove, add a function instead.
- **Kill padding** — reorder fields by alignment (largest first) or go SoA to eliminate inter-field padding entirely.

#### Phase 3: Optimize Access Patterns

- **Function rewrites** — how each function changes to work with the new layout. Iterate over contiguous arrays. Batch operations that touch the same fields.
- **Cache line reuse** — estimate elements per cache line before/after. Show which loops now hit contiguous memory.
- **Vectorization opportunities** — contiguous arrays of primitives → SIMD-friendly. Flag which loops could autovectorize with the new layout.

Each analyst returns its proposal as structured output.

### 4. Synthesize (Agent)

A **synthesis agent** receives all analyst proposals and:

1. **Resolves conflicts** — two analysts proposed different canonical types for overlapping data? Pick one, justify.
2. **Cross-type access patterns** — functions that touch multiple types. Ensure their proposals are compatible.
3. **Builds the unified restructure plan** — ordered list of transforms with dependencies.
4. **Computes estimated impact**:
   - Memory footprint: before vs after (bytes)
   - Cache lines per iteration: before vs after (per hot loop)
   - Elements per cache line: before vs after
   - Padding waste eliminated (bytes)

### 5. Report (HTML)

Write a self-contained HTML report to the OS temp directory. See [HTML-REPORT.md](HTML-REPORT.md) for the full format spec.

The report contains:

1. **Type map** — all types, sizes, padding, wasted bytes. Before/after side by side.
2. **Semantic overlap graph** — Mermaid diagram showing which types overlap and the proposed canonical type.
3. **Access pattern heatmap** — which functions touch which fields. Hot fields highlighted.
4. **Proposed layout** — new SoA structures, canonical types, hot/cold split. Code blocks showing before/after type definitions.
5. **Estimated impact** — cache lines per iteration, memory footprint delta, padding eliminated.
6. **Level 3 option** — flat buffer alternative shown in a collapsible section. Not default. Shown for user consideration.
7. **Top recommendation** — which transform to apply first and why.

Open the report for the user. Ask: **"Which transforms do you want to apply? All / select specific ones."**

### 6. Rewrite (Workflow Fan-out)

On user confirmation, launch **one rewrite agent per type** (or per transform group). Each receives:

- The confirmed proposal for its type
- All affected function signatures
- The language-specific strategy

Each agent:
1. Rewrites the type definition
2. Updates all functions that access the type
3. Updates all call sites
4. Adds any necessary imports (SoA crate, arena crate, etc.)

### 7. Verify (Agent)

A **verify agent** checks:

1. Compilation succeeds (or the user can compile manually)
2. No broken references — every old type usage is accounted for
3. No semantic changes — the data transformations produce the same results
4. Report any manual fixups needed (e.g. serialization code, FFI boundaries, public API changes)

## Language-Specific Notes

### Rust
- `soa_derive` generates SoA types but has ergonomic costs: no `Deref`/`Index` to return references. For full control, parallel `Vec`s.
- `slotmap`/`generational-arena` for index-based arenas with stale-key protection.
- Ownership makes SoA harder — `Vec<(A,B)>` → `(Vec<A>, Vec<B>)` breaks `&self` patterns. Analyst agents must account for borrow checker constraints.
- Prefer `enum` + `match` over `Box<dyn Trait>` in hot paths.

### Zig
- `std.MultiArrayList` is first-class SoA. Use it.
- `NodeIndex = enum(u32)` for typed indices.
- `packed struct` for bit-level packing.
- Allocator is always caller-provided — restructured types follow the same discipline.

### C
- Manual parallel arrays. Macro-based SoA generation if the codebase uses it.
- `uint32_t` indices into `malloc`'d arrays.
- `union` + tag `enum` for encoding.
- `_Alignas` and `__attribute__((packed))` for layout control.

### C++
- Template SoA wrappers or parallel `std::vector`s.
- `std::variant` + `std::visit` over virtual dispatch in hot loops.
- `[[no_unique_address]]` for empty base optimization.
- Beware: inheritance hierarchies resist flattening. May need to break class hierarchy first.
