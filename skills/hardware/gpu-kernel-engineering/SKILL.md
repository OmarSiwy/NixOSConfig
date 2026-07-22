---
name: gpu-kernel-engineering
description: Write fast, correct GPU kernels in CUDA and HIP with disciplined memory placement (registers, shared/LDS, constant, global), memory coalescing, occupancy tuning, and host-device transfer strategy. Use when the user writes, reviews, ports, or optimizes GPU code or kernels; mentions CUDA, HIP, ROCm, nvcc, hipcc, __global__ or __device__ kernels, shared memory, warps or wavefronts, occupancy, coalescing, bank conflicts, pinned or unified memory; asks why a kernel is slow or how to place data on the GPU; or ports kernels between NVIDIA and AMD and chooses block and grid dimensions.
---

# GPU Kernel Engineering (CUDA + HIP)

GPU performance is dominated by **where data lives and how it moves**, not by arithmetic. Most slow kernels are slow because of bad memory placement, uncoalesced access, or wasted launches — not because the math is heavy. Optimize the memory hierarchy first, the launch second, the instruction mix last.

This skill applies to both CUDA (NVIDIA) and HIP (AMD ROCm). HIP mirrors CUDA almost one-to-one at the API and language level, so the same reasoning transfers; the genuine differences are called out explicitly because getting them wrong silently breaks correctness or halves performance. See `references/cuda-hip-portability.md`.

## Work in this order

Do not jump to micro-optimizations. Follow the hierarchy, because each level can erase the gains of the one below it.

1. **Be correct first.** A fast wrong kernel is worthless. Get a naive version passing a CPU reference, then optimize against that oracle.
2. **Decide data placement.** Map every input, output, and intermediate to a memory space (the heart of this skill — see below).
3. **Make global access coalesced.** Adjacent threads must touch adjacent addresses. This is usually the single biggest lever.
4. **Cut redundant global traffic** with shared memory / LDS tiling when data is reused within a block.
5. **Tune the launch** (block size, grid size, occupancy) only after the access pattern is good.
6. **Profile, then optimize the actual bottleneck.** Never guess. See `references/optimization-loop.md`.

## Memory placement: the core decision

For each piece of data, ask "who reads it, how often, and is it shared?" Then place it. Getting this table right is most of the performance.

| Data characteristic | Place it in | Why |
|---|---|---|
| Per-thread scratch, hot, small | Registers (just local vars) | Fastest. But over-using them spills to local memory (slow). |
| Reused by many threads in a block | Shared memory (`__shared__`) / LDS | ~100x lower latency than global; the basis of tiling. |
| Read-only, broadcast to all threads | Constant memory (`__constant__`) | Cached + broadcast: one fetch serves a whole warp. |
| Large, streamed once | Global memory | The only place big arrays fit; make access coalesced. |
| Read-only, 2D spatial locality | Texture / `__ldg` read-only path | Hardware caching tuned for spatial reuse. |
| Accidental register spill | Local memory (avoid!) | Lives in global DRAM despite the name — a silent perf cliff. |

Two rules that catch most mistakes:

- **Watch register pressure.** If a kernel uses too many registers per thread, the compiler spills to "local" memory (really global), and occupancy collapses. Check the register count and tune with launch bounds. Details in `references/memory-model.md`.
- **Pad shared memory to avoid bank conflicts.** Shared memory has 32 banks; if threads in a warp hit the same bank, accesses serialize. The classic fix for a tile is to declare it one column wider, e.g. `tile[32][33]`. Explained in `references/memory-model.md`.

## Coalescing: the second-biggest lever

A warp issues memory transactions in 32/64/128-byte segments. If the 32 (NVIDIA) or 32/64 (AMD wavefront) threads in a warp read consecutive, aligned addresses, the hardware serves them in the fewest transactions. Scattered access multiplies transaction count and wastes bandwidth.

Practical consequences:
- Prefer **Structure-of-Arrays over Array-of-Structures.** `x[i], y[i], z[i]` coalesces; `p[i].x` strides over the struct and does not.
- Index global arrays so the **fastest-varying thread index maps to the fastest-varying memory dimension** (typically `threadIdx.x`).
- Align allocations and row pitches; use pitched allocations for 2D data.

## Host-device transfers

The PCIe/Infinity-Fabric link is often the real bottleneck in end-to-end time. Treat transfers as first-class:

- Use **pinned (page-locked) host memory** (`cudaHostAlloc` / `hipHostMalloc`) for transfers — it enables true async DMA and roughly doubles bandwidth versus pageable memory.
- **Overlap copy and compute with streams**: split work into chunks, copy chunk N+1 while computing chunk N.
- **Unified / managed memory** (`cudaMallocManaged` / `hipMallocManaged`) simplifies code but can hide expensive page migration; prefetch (`cudaMemPrefetchAsync`) and add access hints when you use it.
- Batch many small transfers into one large transfer; per-call launch and copy overhead dominates for tiny payloads.

## The portability gotcha that bites everyone

**Warp size is 32 on NVIDIA but the wavefront is 64 on AMD CDNA (and 32 or 64 on RDNA).** Any code that hard-codes 32 — shuffle masks, warp-reduction strides, `__ballot` widths, shared-memory sizing per warp — breaks or underperforms on AMD. Never hard-code the warp size; query it (`warpSize`) or template on it. Full mapping table and build/flag differences in `references/cuda-hip-portability.md`.

## When writing or reviewing a kernel, check

- Is every global access coalesced for the warp/wavefront?
- Is reused data staged in shared memory / LDS instead of re-read from global?
- Is register usage low enough to keep occupancy up, with no silent local-memory spills?
- Are shared-memory tiles padded against bank conflicts?
- Are transfers pinned and overlapped, and are tiny transfers batched?
- Is there any hard-coded `32` that should be `warpSize`?
- Is the block size a multiple of the warp/wavefront size?

## Reference files

Read the one matching the current task; do not load all three preemptively.

- `references/memory-model.md` — Deep dive on each memory space, occupancy math, register spilling, bank conflicts, and shared-memory tiling patterns.
- `references/cuda-hip-portability.md` — CUDA↔HIP API and keyword mapping, warp/wavefront differences, `hipcc`/`nvcc` build flags, and porting workflow (`hipify`).
- `references/optimization-loop.md` — The profile-driven optimization loop, which metrics to read (occupancy, achieved bandwidth, memory vs compute bound), and roofline thinking.
