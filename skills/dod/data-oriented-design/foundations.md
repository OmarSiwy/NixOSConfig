# Foundations: Data-Oriented Design, Negative-Overhead Abstraction, and API Design

This is the theory document. It is language-agnostic. The companion documents
(rust.md, zig.md) show how to realize each idea in a specific language. Read this
first; it defines the vocabulary the other two assume.

The three bodies of work covered here are usually presented as rivals. They are not.
Data-oriented design tells you to design from the data. Negative-overhead abstraction
tells you that clean structure need not cost anything at runtime if the compiler can
see through it. Muratori's API work tells you to expose the data and the primitives and
let convenience sit on top. All three converge on the same posture: **transparent data,
primitives first, abstraction discovered by compression, decisions verified by
measurement.**

---

## Part I — Data-Oriented Design (Mike Acton, Andrew Kelley)

### The thesis

> The purpose of all programs, and all parts of those programs, is to transform data
> from one form to another.

This is Acton's first principle, and it is the hinge for everything else. It is not a
performance claim; it is an ontological one. A function, a module, and a whole service
are all, at bottom, a mapping from input bytes to output bytes. If you describe a unit
of code and cannot state what data goes in and what data comes out, you do not yet
understand it. (Brooks said the same thing decades earlier: _show me your tables and I
won't usually need your flowcharts._)

### Acton's principles, in full

The epistemics — how you come to understand a problem:

- The purpose of all programs is to transform data. (P1)
- If you don't understand the data, you don't understand the problem. (P2)
- Conversely, understand the problem by understanding the data. (P3)
- Different problems require different solutions. (P4)
- If you have different data, you have a different problem. (P5)
- Everything is a data problem — including usability, maintenance, debuggability. (P8)
- Solving problems you probably don't have creates problems you definitely do. (P9)

The cost model — you cannot reason about a solution without reasoning about the machine:

- If you don't understand the cost of solving the problem, you don't understand the
  problem. (P6)
- If you don't understand the hardware, you can't reason about the cost. (P7)
- Latency and throughput are the same only in sequential systems. (P10)
- Software does not run in a magic aether; it runs on hardware. (P11)

The rules of thumb:

- **Where there is one, there are many.** Look on the time axis. You will almost never
  process exactly one of a thing; design for the collection. (ROT1)
- The more context you have, the better the solution. Don't throw away data you need.
  (ROT2)
- Non-uniform access (NUMA) extends backward through I/O and pre-built data all the way
  to original source creation. (ROT3)

### The three lies

Acton names three industry assumptions that pull people away from the data:

1. **Software is a platform.** The hardware is the platform. The cache hierarchy, the
   line size, the memory latency — those are the ground truth your abstractions sit on.
2. **Code should be designed around a model of the world.** Modeling the world via
   `IS-A` hierarchies confuses what is easy to _say_ in English with what is efficient
   to _compute_. A `Cat IS-A Animal` taxonomy tells you nothing about how to lay bytes
   out for the transformation you actually run.
3. **Code is more important than data.** If the purpose of code is to transform data,
   then data is primary and code is the mechanism.

### The hardware reality you are designing against

A modern CPU core can execute on the order of hundreds of instructions in the time it
takes to service a single main-memory cache miss. The dominant cost in most data-heavy
loops is therefore not arithmetic — it is waiting for memory. Two consequences:

- Data you touch together should live together (spatial locality). A cache line is
  fetched whole; if half of it is fields you don't read this pass, you've wasted half
  your bandwidth.
- Predictable, linear access lets the hardware prefetcher and the compiler's
  vectorizer work. Pointer-chasing and unpredictable branches defeat both.

### Kelley's practical playbook

Andrew Kelley applied DOD to the Zig compiler and reduced its memory footprint and
cache pressure substantially. His summary is "use less memory, go fast." The concrete
moves, each of which has a direct realization in both companion documents:

1. **Indices instead of pointers.** A pointer is 8 bytes and pins lifetime/aliasing. An
   index into an array is often a `u32` (or smaller), halving the footprint and letting
   you relocate the backing storage freely. Pointers become positions in an arena.
2. **Store booleans (and other rare fields) out of band.** A single `bool` in a struct
   frequently costs far more than one bit once padding is accounted for. Hot fields stay
   in the main array; rare/cold fields move to a side table keyed by index.
3. **Eliminate padding with struct-of-arrays.** Reordering fields removes some padding;
   splitting a struct into one array per field (SoA) removes inter-field padding
   entirely and lets a pass over a single field stream contiguously.
4. **Encodings instead of polymorphism.** Rather than a vtable per element, store a
   small tag (an enum) plus a compact payload, and branch on the tag at the top of the
   loop — or better, bucket by tag so each loop is monomorphic.
5. **Shrink the element.** Smaller structs mean more elements per cache line, which
   often unlocks autovectorization for free.

### Array-of-Structs vs Struct-of-Arrays, stated precisely

```
AoS:  [ {pos,vel,color,flags}, {pos,vel,color,flags}, ... ]   // one element contiguous
SoA:  pos[]  vel[]  color[]  flags[]                          // one field contiguous
```

- **SoA wins** when a pass reads a _subset_ of fields across _many_ elements
  (integrate position from velocity; sum one column). It minimizes cache-line waste and
  vectorizes. This is the same reason analytical databases (OLAP) are columnar.
- **AoS wins** when a pass reads _most/all_ fields of _one_ element at a time
  (serialize a record; an update where the fields are mutually dependent), because the
  whole element is in one line.

The rule is Acton's, not a slogan: **look at the data, look at the process, make the
layout fit the access pattern.** SoA is not "better"; it is better _for column-wise
access_.

### DOD as a design method, not just an optimization

Because every module is "a large function that transforms input data into output
data," DOD gives you a decomposition rule: **group data that is used together; separate
data that is not.** Module boundaries fall where data is stable enough to form an API.
This is a design discipline that pays off in modifiability and testability even when
performance is not the goal — the data flow _is_ the architecture.

---

## Part II — Negative-Overhead Abstraction ("Clean Code," reconsidered)

### The false dichotomy

The usual framing pits "clean, abstracted code" against "fast code." That framing is
the error. The right question is never _whether_ to abstract but _whether the optimizer
can see through the abstraction you chose._ When it can, the abstraction is **zero-cost**
(erased entirely) or **negative-cost** (it compiles to something better than the obvious
hand-written version).

### Definitions

- **Zero-cost (Stroustrup):** what you don't use, you don't pay for; and what you do
  use, you couldn't reasonably hand-code any better.
- **Operational test:** a zero-cost abstraction compiles to the best implementation a
  competent programmer would have written using the low-level primitives directly. It
  must not introduce costs that could be avoided by _not_ using it.
- **Negative-cost:** the abstraction carries an invariant the compiler can exploit
  (e.g. an iterator knows its length, so per-element bounds checks are elided and the
  loop vectorizes), producing machine code _faster_ than naive primitive-level code a
  person would typically write.

### What is genuinely valuable in "Clean Code"

Robert C. Martin's book contains durable, local craft that survives the performance
critique completely intact:

- **Meaningful names** and intention-revealing code, so comments rarely need to explain
  _what_.
- **Cohesion**: a function/module should do one conceptual thing, so you can hold it in
  your head. (Cohesion — not a line count.)
- **Clear, explicit error handling** as a first-class concern.
- **Clean boundaries** between your code and third-party code.

Most importantly, the book contains an idea that is _directly_ data-oriented and is
usually overlooked: the **data/object anti-symmetry** (Chapter 6). Martin distinguishes

- **objects**, which hide their data behind abstractions and expose behavior, from
- **data structures**, which expose their data and have essentially no behavior.

and observes the trade-off: procedural code over _data structures_ makes it easy to add
new operations without touching the structures, while object-oriented code makes it
easy to add new types without touching existing operations. DOD lives almost entirely
in Martin's "data structure" quadrant: transparent data, with transformations written
as free functions over it. So the book itself tells you when to reach for plain,
transparent data — exactly DOD's posture — rather than for an object. The Law of
Demeter and the advice against hybrid structures point the same way: don't grow
behavior on the things that are really just data.

### Where "Clean Code" misleads if applied as dogma

The prescriptions that draw fire are the ones that fight either the optimizer or the
data:

- **"Functions must be very small."** Past the point of cohesion, fragmentation hides
  the data flow and scatters a transformation across call sites, making it harder for
  both the reader and the optimizer to see the whole loop. Size should follow one
  coherent transformation, not a target line count.
- **"Prefer polymorphism to conditionals."** A `match`/`switch` over a small closed set
  is usually clearer _and_ faster than dynamic dispatch; virtual dispatch in a hot loop
  is a vtable indirection per element that blocks inlining and vectorization. Reach for
  runtime polymorphism only when the set of cases is genuinely open at runtime — and
  even then, prefer _bucketing by type_ (DOD) over per-element dispatch.
- **"Encapsulate everything."** Reflexive getters/setters around fields with no
  invariant add friction and zero safety, and they make the SoA/transparent-data
  transformation harder.

### The synthesis

The target is the intersection: abstractions that are **clean** (good names, cohesive,
honest error handling), **transparent to the optimizer** (monomorphized generics,
inlined iterators, compile-time computation, zero-sized type markers), and **aligned
with the data** (transparent structures, batch-shaped). In a language with
monomorphization and aggressive inlining, "clean," "expressive," and "optimal" are very
often the _same_ source code, not points on a trade-off curve.

### The discipline that keeps this honest

Zero-cost is a goal, not a guarantee. A newtype can occasionally defeat
autovectorization; dynamic dispatch and atomic reference counting introduce real
indirection; a missed inline turns a "free" combinator into a function call. Therefore:
**on any path that matters, verify** — read the generated assembly (e.g. on godbolt) or
benchmark the abstraction against the primitive. Claims of zero cost are checked, not
assumed.

---

## Part III — API Design (Casey Muratori)

### Origin and stance

Muratori's API principles come from designing and maintaining Granny 3D, a licensed
animation runtime that shipped in thousands of titles over more than a decade. The
context matters: a _reusable component_ (his term, vs. a "layer"/"leaf" technology) is
one that integrates deep inside someone else's architecture with non-trivial feedback.
That is the hardest case, and it forces a discipline most APIs skip.

### Method: write the usage code first

Before implementing anything, write the code you _wish_ you could call. The API is then
defined by the call site, not by the implementer's mental model. This is the single
highest-leverage practice, and it composes with semantic compression (below): you write
concrete usage, then compress.

### The five characteristics (the evaluation framework)

For any component boundary between caller A and component B, evaluate:

1. **Granularity — "A or BC."** Can an operation be split into smaller steps that give
   the caller more control? An API offered only at coarse grain traps callers who need
   to intervene in the middle.
2. **Redundancy — "A or B."** Are there multiple paths to the same result, and is the
   _common_ path short? (This is the "diagonal, not orthogonal" idea — for a frequent
   operation you want the direct route, not a forced Manhattan walk through primitives.)
3. **Coupling — "A implies B."** Does using one part force you to take on another
   (a type, an allocator, a subsystem)? Minimize implied dependencies.
4. **Retention — "A mirrors B."** Does the component force the caller to mirror or hold
   state/data structures on its behalf? Forced retention couples the caller's data
   layout to the library's — anathema to DOD.
5. **Flow control — "A invokes B."** Who calls whom? A library that calls _you_ (owns
   the loop, the lifecycle) is far more invasive than one you call.

### The design rules that follow

- **Every non-atomic function should be expressible via two to four more granular
  functions.** Provide the coarse convenience call, but build it on the fine-grained
  ones and expose those too. Never trap the caller in only the high-level path.
- **Data that has no clear reason to be opaque should be transparent** — in
  construction, access, and I/O. (Directly DOD-compatible: transparent data can be laid
  out SoA, serialized directly, inspected.)
- **Use of the component's resource management is optional.** The caller can supply
  memory/files/strings. (Directly DOD-compatible: caller-owned arenas.)
- **Use of the component's file format is optional;** full runtime source is available.

### Memory and lifetime belong to the caller

Take an allocator / output buffer as a parameter instead of allocating behind the
caller's back. This is the same discipline Zig enforces by passing `Allocator`
everywhere and Rust enforces through ownership — and it is what makes a component usable
inside an arena, on the stack, or in a hot loop without forking it.

### Build by compression, not speculation (semantic compression)

The architecture should _emerge_. Write the concrete code first; then act like a
compressor on your own source — factor out the patterns that have genuinely repeated,
and only those. A little duplication is cheaper than the wrong abstraction; two blocks
that merely look alike but evolve differently were never the same thing. Abstractions
discovered by compression are tight, used in many places, and map to real structure —
which is exactly the kind of abstraction a compiler also optimizes well.

---

## Coda — why the three are one posture

- DOD says: **understand and design from the data**; layout follows access pattern.
- Negative-overhead abstraction says: **you can keep clean structure for free** when the
  abstraction is transparent to the compiler — so don't pay the OOP tax, and don't fear
  the abstraction either.
- Muratori says: **expose the data and the primitives**, keep the common path short,
  let the caller own memory, and grow abstractions by compression.

Transparent data, primitives first, convenience layered on top, abstraction by
compression, every performance claim measured. The companion documents implement this
in Zig and in Rust.

---

# Operational dimensions

The three pillars above concern _structure_ — how you shape data, abstraction, and
interfaces. The four dimensions below concern _operation_: how memory is obtained, how
work is parallelized, how invariants are made unbreakable, and how the data layout
finally pays off as vectorized throughput. Each is realized concretely in rust.md and
zig.md.

## Part IV — Memory and allocation strategy

The single largest avoidable cost in most data-heavy programs is calling the
general-purpose allocator on a hot path. A general allocator must be correct for every
size, alignment, lifetime, and thread — that generality is exactly the overhead DOD
tells you to avoid. The lever is to **match allocator lifetime to data lifetime** and
stop treating "the heap" as one undifferentiated thing.

**Allocation as an explicit dependency.** The cleanest discipline (Zig enforces it, and
it is good practice anywhere) is to treat the allocator as a parameter, not a global.
The code that _uses_ memory should not silently decide _how_ it is obtained; the caller
chooses the strategy. This is the same idea as Muratori's "resource management is
optional" and his Retention/Coupling characteristics.

The common strategies, from most to least specialized:

- **Arena / region.** Allocate freely; free everything at once when a _phase_ ends
  (a frame, a request, a parse). Individual frees are no-ops. This collapses lifetime
  management to a single `reset`/`deinit` and is often dramatically faster than
  per-object free. Ideal when many objects share a lifetime.
- **Pool / freelist.** Fixed-size slots reused in place. O(1) acquire/release, no
  fragmentation, stable addresses. Ideal for many same-typed objects with individual
  lifetimes (the index-arena idea from DOD).
- **Bump / linear.** A pointer that only moves forward. The fastest possible
  allocation; usually the mechanism _inside_ an arena.
- **Fixed / stack buffer.** A buffer of known size, no heap at all — for hot paths,
  embedded, and bounded work. Allocation cannot fail except by exhausting the buffer.

**The principles, independent of language:**

- Reserve capacity up front; a loop that grows a collection element-by-element pays
  repeated reallocation and copying. Amortize it with one up-front reservation.
- Don't allocate in the hot loop. Allocate once outside it and reuse the storage
  (clear-and-reuse retains capacity).
- The caller owns memory and lifetime wherever feasible — it is what makes a routine
  usable in an arena, on the stack, or in a tight loop without being rewritten.

## Part V — Concurrency and parallelism

These are different problems (Pike's distinction): **concurrency** is _structuring_ a
program as independent tasks; **parallelism** is _executing_ work simultaneously on
multiple cores. A design can be concurrent without being parallel, and vice versa.

- **Data parallelism** is the DOD payoff: the same transformation applied to disjoint
  partitions of an array, with no inter-element dependencies. This is "embarrassingly
  parallel" and scales nearly linearly. SoA layout makes the partitions clean.
- **Task parallelism** runs heterogeneous units of work concurrently; it needs
  coordination and is where most concurrency bugs live.

The governing rule is **partition, don't share.** Give each worker a disjoint slice it
owns exclusively; then no synchronization is needed on the data itself. Reach for shared
mutable state (locks, atomics) only for the irreducible coordination that remains.

Two hazards to design against:

- **Data races are undefined behavior**, not merely bugs — two threads touching the
  same location with at least one writing, without synchronization. The strongest tools
  prevent them _at compile time_ (see Part VI; Rust's `Send`/`Sync` is exactly this).
- **False sharing**: two threads writing _different_ variables that happen to live on
  the same cache line, forcing the line to ping-pong between cores. The fix is to pad or
  separate hot per-thread data onto distinct lines.

When you must synchronize, the ladder runs locks → lock-free structures → raw atomics
with explicit memory ordering, in increasing order of performance and of difficulty to
get right. And Amdahl's law caps the payoff: the serial fraction bounds the maximum
speedup, so measure where the time actually goes before parallelizing.

## Part VI — Type-driven design: make illegal states unrepresentable

The correctness counterpart to everything above. The thesis (Yaron Minsky): choose
representations such that an invalid value _cannot be constructed_, so whole classes of
bugs become compile errors rather than runtime checks.

- **Parse, don't validate** (Alexis King). Do validation once, at the boundary, and
  have it _return a refined type_ that carries the proof of validity. Downstream code
  accepts only the refined type, so it never re-checks and never sees invalid data.
  Validation that returns a `bool` throws away the information it just learned; parsing
  keeps it in the type.
- **Encode invariants in types.** Prefer a sum type (enum/tagged union) over a struct of
  flags whose combinations are mostly illegal. Use distinct newtypes for IDs, units, and
  indices so they can't be confused or arithmetic-abused. Use non-empty / non-zero types
  where zero or empty is meaningless.
- **This is "encapsulate invariants, not data" turned into compile-time guarantees.**
  Once data is parsed into the right type, defensive checks downstream disappear.

The payoff is often _negative cost_: a non-zero integer type lets the compiler use the
zero bit pattern as a niche, so an "optional non-zero integer" is the same size as the
integer — you get the safety _and_ a smaller representation. Tight, correct
representations are frequently also the smallest ones, which is exactly what DOD wants.

## Part VII — Data parallelism and SIMD

SIMD — one instruction operating on many lanes at once — is the literal cash-out of
struct-of-arrays. A contiguous column of values is exactly what loads into a vector
register; AoS, by contrast, interleaves fields the vector unit doesn't want.

- **Autovectorization** is the compiler doing this for you. It fires when the loop is
  simple, operates on contiguous data, is light on branches, has no loop-carried
  dependency it can't reassociate, and (crucially for floating point) is _allowed_ to
  reassociate. SoA + small elements + no early-exit branch is the recipe that lets it
  trigger.
- **Explicit SIMD** (vector types or intrinsics) is what you reach for when
  autovectorization won't fire — typically because of branches, gathers, or float
  reassociation the compiler won't perform without permission.
- **The float caveat.** IEEE 754 makes addition non-associative, so a compiler bound to
  strict semantics cannot reorder a float reduction into vector lanes without explicit
  fast-math permission or explicit SIMD. Integer code does not have this problem.

To make a kernel vectorizable: lay data out SoA, remove branches from the inner loop
(use masks / branchless selects), align the data, and process in chunks of the vector
width with a scalar remainder. And measure the emitted instructions — SIMD is the most
over-claimed optimization in practice; confirm the vector ops are actually there.
