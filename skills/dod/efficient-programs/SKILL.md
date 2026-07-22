---
name: efficient-programs
description: >
  Write hardware-efficient code using semantic compression, cache-aware data layout,
  and measurement-driven optimization. Use when writing performance-sensitive code,
  designing APIs or abstractions, choosing data layouts (AoS vs SoA), writing SIMD
  or multithreaded code, optimizing hot loops, or when user mentions cache, latency,
  branch prediction, prefetching, or Pikus/Muratori.
---

# Efficient Programs

Principles from Pikus (The Art of Writing Efficient Programs) and Muratori (Semantic Compression).

## When to Use

- Designing an API or abstraction boundary
- Choosing struct layout or container strategy
- Writing or optimizing a hot loop
- Adding multithreading to shared data
- User asks about performance, cache behavior, or data-oriented design
- Any code touching hardware interfaces (sensors, timers, PWM)

## Core Principles

### 1. Semantic Compression (Muratori)

Write the **usage code first** — the code you wish existed. Then extract repeated
patterns into functions bottom-up. Never design an API top-down.

```rust
// STEP 1: Write the usage you want
let img = load_png("input.png");
let gray = to_grayscale(&img);
let edges = detect_edges(&gray, 1.4);
save_png(&edges, "output.png");

// STEP 2: Only now implement load_png, to_grayscale, etc.
// STEP 3: If detect_edges and to_grayscale share a per-pixel loop, compress into one
```

The right abstraction eliminates **actual** repetition, not hypothetical repetition.
If a pattern appears once, inline it. Twice, watch it. Three times, compress.

### 2. Anti-Flow-Control-Inversion

The caller owns the loop. Push data, don't pull. Never force the user into a callback/visitor/framework.

```rust
// BAD: library owns the loop (pull/callback)
parser.on_token(|tok| { /* trapped inside library's control flow */ });

// GOOD: caller owns the loop (push/iterator)
for tok in parser.tokens(&input) {
    // caller decides control flow
}
```

### 3. Measure First, Optimize the Bottleneck

Never optimize without a profile. Amdahl's Law: speeding up 5% of runtime by 10x
saves 4.5% total. Find the 80% first.

**Workflow:**
1. Profile the real workload (not a microbenchmark)
2. Identify the top-1 hotspot
3. Check: is it compute-bound, memory-bound, or branch-bound?
4. Apply the matching fix from sections below
5. Re-measure. Stop when the goal is met

### 4. Cache Hierarchy — Know the Costs

| Access | Latency | Relative |
|--------|---------|----------|
| L1     | ~1 ns   | 1x       |
| L2     | ~3 ns   | 3x       |
| L3     | ~10 ns  | 10x      |
| RAM    | ~100 ns | 100x     |

**Rules:**
- Keep hot data under 32-64 KB (L1). Split cold fields out of hot structs
- Sequential access gets HW prefetch free. Random access pays full latency
- Align to 64-byte cache lines for SIMD and to avoid false sharing

### 5. Branch Prediction

- Predictable branches (always-true guards) are nearly free
- Data-dependent branches in tight loops kill throughput
- Convert to branchless where it matters: `x = cond * a + (!cond) * b`
- Sort data to make branches predictable when branchless isn't possible

### 6. SoA for SIMD, AoS for Pointer-Chasing

```rust
// BAD for SIMD: Array of Structs
struct Particle { x: f32, y: f32, z: f32, mass: f32 }
let particles: Vec<Particle>; // x,y,z,mass,x,y,z,mass,...

// GOOD for SIMD: Struct of Arrays
struct Particles { x: Vec<f32>, y: Vec<f32>, z: Vec<f32>, mass: Vec<f32> }
// x,x,x,x,... y,y,y,y,... → SIMD loads 4/8/16 at once
```

**Tension with ergonomics:** SoA is harder to use for single-element access.
Use SoA for batch processing, AoS when you access all fields of one item together.
DOD says: let the access pattern decide, not the "object".

### 7. False Sharing

```rust
// BAD: counters on same cache line, threads thrash each other
struct Counters { a: AtomicU64, b: AtomicU64 } // likely same 64-byte line

// GOOD: pad to separate cache lines
#[repr(C, align(64))]
struct PaddedCounter(AtomicU64);
struct Counters { a: PaddedCounter, b: PaddedCounter }
```

### 8. Calibration Principle

Real hardware drifts from spec. When code interfaces with physical devices
(PWM, sensors, timers), expose a calibration parameter — don't hardcode the
theoretical value.

```rust
// BAD: assumes perfect 50Hz PWM
let period_us = 20_000;

// GOOD: tunable, because real oscillators drift
let period_us = config.pwm_period_us; // default 20_000, field-adjustable
// ponytail: calibration knob — real PCA9685 runs ~2-3% fast
```

## Anti-Patterns

### Premature Abstraction
```rust
// BAD: trait + impl for one type, "just in case"
trait Processor { fn process(&self, data: &[u8]) -> Vec<u8>; }
struct JsonProcessor;
impl Processor for JsonProcessor { /* only impl ever */ }

// GOOD: just a function until you have two implementations
fn process_json(data: &[u8]) -> Vec<u8> { /* ... */ }
```

### Iterator Abuse in Hot Paths
```python
# BAD: allocates intermediate lists
result = list(map(transform, filter(predicate, big_list)))

# GOOD: single pass, no intermediates
result = [transform(x) for x in big_list if predicate(x)]
# BETTER if hot: pre-allocate and index loop (measure to confirm)
```

### Ignoring Access Pattern
```rust
// BAD: HashMap for 16 items (cache-hostile, hash overhead > scan)
let lookup: HashMap<u8, Value> = /* 16 entries */;

// GOOD: flat array or sorted Vec + binary_search for small N
let lookup: [(u8, Value); 16] = /* ... */; // fits in L1, linear scan wins
// ponytail: switch to HashMap when N > ~64 and profile confirms
```

## Verify (Zero-Cost Is Checked, Not Assumed)

On any hot path, read the generated assembly or benchmark. For SIMD, confirm vector instructions were emitted — autovectorization is easy to assume and easy to lose (a branch, a non-contiguous access, a float reduction each silently kill it). Don't model the world; model the transformation.

## Quick Reference

```
Need an abstraction?  → Write usage first, compress repeated patterns bottom-up
API shape?            → Caller owns the loop. Return iterator, not callback
Optimize?             → Profile → top hotspot → compute/memory/branch? → targeted fix
Struct layout?        → Batch SIMD ops: SoA. Single-element access: AoS. Mixed: hybrid
Small collection?     → Flat array beats HashMap under ~64 elements
Multithreaded data?   → Pad atomics to 64-byte alignment. Check for false sharing
Physical interface?   → Add calibration parameter, never hardcode spec values
One implementation?   → Function, not trait/interface. Compress when pattern repeats 3x
```

See [REFERENCE.md](REFERENCE.md) for extended cache math and SIMD intrinsics cheat sheet.
