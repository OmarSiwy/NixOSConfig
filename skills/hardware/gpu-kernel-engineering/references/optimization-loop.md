# Profile-Driven Optimization Loop

Never optimize a GPU kernel by guessing. The hardware has too many failure modes that look alike from the source. Measure, find the binding constraint, fix that one thing, measure again.

## The loop

1. **Establish a correct baseline** with a CPU/reference oracle and a timing harness (warm up first; time many iterations; exclude one-time allocation).
2. **Classify the kernel: memory-bound or compute-bound.** Read achieved memory bandwidth and compute throughput from the profiler. If you are near peak bandwidth but far from peak FLOPs, you are memory-bound (the common case) — optimize data movement. If the reverse, optimize the instruction mix.
3. **Fix the binding constraint, then re-measure.** Changing anything else first is wasted effort.
4. **Stop when you are near the relevant roof** (see roofline below) or when further gains are not worth the complexity.

## Metrics worth reading

- **Achieved occupancy** vs theoretical — a large gap suggests load imbalance, divergence, or tail effects, not a placement problem.
- **Achieved DRAM bandwidth** as a fraction of peak — the headline number for memory-bound kernels. Low bandwidth with high transaction counts means uncoalesced access.
- **Global load/store efficiency** — fraction of bytes fetched that were actually used. Low efficiency = uncoalesced or over-fetching access pattern.
- **Local memory traffic** — should be zero or near it. Nonzero means register spilling (see memory-model.md).
- **Shared memory bank conflicts** — directly reported; nonzero means pad your tiles.
- **Warp execution efficiency / divergence** — low values mean threads in a warp take different branches; restructure to keep a warp on one path.

## Roofline thinking

Plot attainable performance against arithmetic intensity (FLOPs per byte moved). A kernel sits under two roofs: the memory-bandwidth roof (slanted) and the compute roof (flat). Where your kernel's arithmetic intensity lands tells you which roof you are under and therefore what to optimize:

- **Low intensity (under the bandwidth roof):** you are memory-bound. Raise intensity by reusing data on-chip (tiling), improving coalescing, or fusing kernels to avoid round-trips to global memory.
- **High intensity (under the compute roof):** you are compute-bound. Now instruction-level work matters — use faster math where precision allows, reduce redundant computation, improve ILP.

Most real kernels start memory-bound. That is why this skill puts memory placement and coalescing before instruction-level tuning: moving the kernel rightward on the roofline (more reuse, less traffic) is usually the biggest available win.

## Common findings and their fixes

- High DRAM traffic, low efficiency → uncoalesced access → switch AoS to SoA, fix indexing.
- Nonzero local memory → register spill → reduce live registers, set launch bounds.
- Bank-conflict counter nonzero → pad shared-memory tiles.
- Low occupancy with no spills → block size too small or too large; tune to a multiple of warp/wavefront size.
- Transfer time dominates total → pin host memory, overlap with streams, batch small copies.
