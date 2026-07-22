# Efficient Programs — Reference

Extended details for cache math, SIMD layout, and optimization checklists.

## Cache Line Math

- Cache line: 64 bytes on x86/ARM (check with `getconf LEVEL1_DCACHE_LINESIZE`)
- L1 data cache: typically 32-48 KB per core (8-12 hot structs of 4 KB each)
- Working set rule: if hot data fits in L1, you're compute-bound. If not, you're memory-bound

### Struct Packing Example

```rust
// 24 bytes — wastes space in hot loop if only x,y used
struct Entity { x: f32, y: f32, hp: u32, name: [u8; 12] }

// Split hot/cold: hot path touches only 8 bytes per entity
struct EntityPos { x: f32, y: f32 }           // 8 bytes — 8 fit per cache line
struct EntityMeta { hp: u32, name: [u8; 12] }  // cold, accessed rarely
```

64 bytes / 8 bytes = 8 positions per cache line vs 2.6 full entities per line.
That's 3x more useful data per L1 load in the movement loop.

## SIMD Layout Requirements

SIMD operates on contiguous lanes of the same type:
- SSE: 128-bit = 4x f32
- AVX2: 256-bit = 8x f32
- AVX-512: 512-bit = 16x f32
- NEON (ARM): 128-bit = 4x f32

**SoA is mandatory for auto-vectorization.** Compilers cannot vectorize AoS
because fields of different entities are not contiguous.

```rust
// Compiler CAN auto-vectorize this (SoA):
for i in 0..n { out_x[i] = pos_x[i] + vel_x[i] * dt; }

// Compiler CANNOT vectorize this (AoS):
for i in 0..n { entities[i].x += entities[i].vx * dt; }
// Fields x and vx are stride-separated, not contiguous
```

### Alignment for SIMD Loads

```rust
// Aligned allocation for AVX2 (32-byte alignment)
#[repr(C, align(32))]
struct AlignedF32x8([f32; 8]);

// In Zig:
const positions = @as([*]align(32) f32, @alignCast(raw_ptr));
```

Unaligned SIMD loads work on modern x86 but cost ~1 extra cycle per load.
On older hardware or ARM, unaligned loads may fault or be 2-10x slower.

## Branch Prediction Details

Modern CPUs predict with ~97% accuracy for regular patterns.
Cost of misprediction: 15-20 cycles (pipeline flush).

### When to Go Branchless

Profile first. Branchless helps when:
- Branch is in a tight inner loop (>10M iterations)
- Branch is data-dependent (random true/false)
- Branch misprediction shows in perf counters (`perf stat -e branch-misses`)

```rust
// Branchy (bad if unpredictable):
fn abs_val(x: i32) -> i32 { if x < 0 { -x } else { x } }

// Branchless:
fn abs_val(x: i32) -> i32 {
    let mask = x >> 31; // arithmetic shift: all 1s if negative, all 0s if positive
    (x ^ mask) - mask
}
```

Don't go branchless on code that runs <1000 times — readability wins.

## Prefetching

Hardware prefetcher detects sequential and strided access automatically.
It does NOT help with:
- Pointer chasing (linked lists, trees)
- Random index access (hash tables)
- Access patterns with stride > 2 KB (exceeds prefetcher's detection window)

Software prefetch hint (use sparingly, measure always):
```rust
// Rust (nightly): core::arch::x86_64::_mm_prefetch
// Zig: @prefetch(ptr, .{ .locality = 3 })
// C: __builtin_prefetch(ptr, 0, 3)
```

Prefetch 2-4 iterations ahead in pointer-chasing loops. More than that pollutes L1.

## Amdahl's Law Quick Table

| Fraction of runtime | 2x speedup | 10x speedup | Infinite speedup |
|---------------------|------------|-------------|------------------|
| 90%                 | 1.8x total | 5.3x total  | 10x total        |
| 50%                 | 1.3x total | 1.8x total  | 2x total         |
| 10%                 | 1.05x total| 1.1x total  | 1.1x total       |

Never optimize the 10% path. Find the 90% path first.

## Optimization Decision Tree

```
Is it slow?
├── No → Stop. Ship it.
└── Yes → Profile it.
    ├── Compute-bound (high IPC, low cache misses)
    │   ├── Reduce work: algorithmic improvement
    │   ├── SIMD: convert to SoA, align data
    │   └── Branchless: eliminate unpredictable branches
    ├── Memory-bound (low IPC, high cache misses)
    │   ├── Shrink hot struct: split hot/cold fields
    │   ├── SoA layout: pack accessed fields contiguously
    │   ├── Sequential access: arrays > linked structures
    │   └── Prefetch: software hints for pointer-chasing
    └── Contention-bound (scales poorly with threads)
        ├── False sharing: pad atomics to cache line
        ├── Lock granularity: per-bucket > global
        └── Lock-free: atomic ops where contention is narrow
```
