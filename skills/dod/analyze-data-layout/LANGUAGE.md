# Language

Shared vocabulary for every suggestion this skill makes. Use these terms exactly — don't substitute vague synonyms. Consistent language prevents drift between the scout, analyst, synthesis, and rewrite agents.

## Data Layout Terms

**Type map**
A catalog of every type in the analyzed scope: fields, sizes, alignment, padding, total footprint. The starting point for all analysis.
_Avoid_: schema, model, shape (too vague).

**Semantic overlap**
Two or more types that represent the same or superset/subset real-world data. `Point(x,y)` is structurally contained in `Rect(x,y,w,h)`. If both are used in the same system, data is duplicated and access patterns fragment.
_Avoid_: redundancy (too broad — covers field-level, not type-level), duplication (implies copy, not structural overlap).

**Canonical type**
The single unified type chosen to replace semantically overlapping types. At Level 2: a concrete struct that subsumes the others. At Level 3: a flat buffer where each former type becomes an offset range.
_Avoid_: base type (implies inheritance), common type (too vague).

**Access pattern**
Which fields of a type are read or written, by which functions, how often, and in what order. The access pattern determines every layout decision — AoS vs SoA, hot/cold split, field ordering.
_Avoid_: usage (too vague), read pattern (ignores writes).

**Hot field**
A field accessed in the majority of passes over the collection. Hot fields live in the main array, packed tight for cache efficiency.

**Cold field**
A field accessed rarely — error paths, debug info, metadata. Cold fields move to a side table indexed by the element's position, keeping hot arrays lean.

**Side table**
A secondary data structure holding cold fields, keyed by the same index as the main array. Consulted only on cold paths.
_Avoid_: secondary storage, overflow table.

**Cache line utilization**
The fraction of bytes in a fetched cache line (typically 64B) that the current pass actually reads. AoS with many unused fields → low utilization. SoA for the fields you need → high utilization.

**Padding**
Bytes inserted by the compiler between fields to satisfy alignment requirements. Wasted memory and wasted cache space. Eliminated by field reordering (largest-alignment first) or SoA layout.

## Layout Patterns

**AoS (Array of Structs)**
`[{a,b,c}, {a,b,c}, ...]` — one element contiguous. Optimal when every pass reads all fields of one element.

**SoA (Struct of Arrays)**
`a[], b[], c[]` — one field contiguous across all elements. Optimal when passes read a subset of fields across many elements. Minimizes cache-line waste and enables autovectorization.

**Hybrid**
SoA for hot fields, AoS for tightly-coupled field groups. The practical middle ground when some functions need all fields and others need a subset.

**Flat buffer**
A single contiguous allocation (e.g. `[]u8` or `Vec<u8>`) where all data lives. Types become offset ranges into the buffer. Maximum cache control, maximum API disruption. Level 3 — suggested, not default.

## Restructure Levels

**Level 1 — Reorder**
Reorder fields within existing types to eliminate padding. No API change. Always safe, always worth doing.

**Level 2 — Unify + Split** (default action)
Unify semantically overlapping types into a canonical type. Split types into SoA. Move cold fields to side tables. Moderate API change — callers update type names and field access patterns.

**Level 3 — Flatten** (suggested as option)
Collapse all related types into a flat buffer with index offsets. Maximum DOD. Significant API change — everything becomes indices into arrays of primitives.

## Measurement Terms

**Elements per cache line**
How many elements of a type fit in one 64-byte cache line. Smaller structs → more elements → fewer cache misses per iteration.

**Memory footprint**
Total bytes allocated for all instances of a type. Before vs after comparison shows the savings.

**Vectorization opportunity**
A contiguous array of a primitive type (f32, u32, etc.) that a SIMD loop could process N-at-a-time. SoA unlocks this; AoS with mixed types blocks it.

## Principles (from THEORY.md)

These are not restated here — see [../principles/THEORY.md](../principles/THEORY.md) for the full treatment. The key ones this skill applies:

- **The purpose of all programs is to transform data.** (Acton P1)
- **Where there is one, there are many.** Design for the collection. (Acton ROT1)
- **Look at the data, look at the process, make the layout fit the access pattern.** SoA is not "better"; it is better for column-wise access.
- **Semantic compression** — grow abstractions by compressing repeated concrete code, not by speculating.
- **On any hot path, verify** — read the assembly, benchmark, don't assume.

## Relationships

- A **type map** entry describes one type's layout.
- **Semantic overlap** connects type map entries that represent the same data.
- A **canonical type** replaces a set of overlapping entries.
- **Access patterns** determine the **hot/cold split** and **AoS/SoA** decision for each entry.
- **Cache line utilization** measures the quality of the layout given the access pattern.
- **Restructure levels** describe increasing aggressiveness of the transform.
