---
name: gpu-kernel-optimization
description: Write GPU kernels that hit the hardware roofline instead of a hidden bottleneck. Use whenever the user wants a compute kernel or shader written, ported, or reviewed (CUDA, HIP, OpenCL, Vulkan/SPIR-V, Metal, WGSL, Triton), whenever GPU code is slow and they ask why or how to make it faster — even if they never say "kernel", e.g. "my matmul/reduction/simulation is slow on the GPU" — and whenever they want GPU or kernel programming in Zig (SPIR-V, PTX, AMDGCN targets; read references/zig-gpu.md first for that branch).
---

# GPU Kernel Optimization

Never optimize blind. Every kernel is pinned against one **ceiling** at a time — memory bandwidth, compute throughput, latency, or launch overhead — and work spent pushing on the wrong ceiling is wasted. The discipline: **name the bottleneck, compute the speed of light, close the gap.** Run these steps in order for every kernel you write or fix.

## Step 1 — Name the bottleneck

Place the kernel on the **roofline** before writing or changing a line of code:

- **Arithmetic intensity (AI)** = useful ops ÷ bytes that must cross DRAM (count each byte once per unavoidable trip, not per access).
- **Ridge point** = peak throughput ÷ peak bandwidth for the target GPU (order of 10–100 FLOP/byte on modern discrete GPUs; look up the actual card's specs when known).
- AI < ridge → **memory-bound**. AI > ridge → **compute-bound**.
- Override the roofline in two cases: the grid is too small to fill the machine, or dependent memory chases (pointer walks, tiny tiles) dominate → **latency-bound**. Kernel runtimes are ~µs-scale or the timeline is mostly gaps → **overhead-bound**.

If profiler data is available (Nsight Compute, rocprof, RGP, Xcode GPU tools), trust measured SOL%/utilization over the paper estimate.

**Done when:** the bottleneck is named as exactly one of {memory, compute, latency, overhead}, with the AI arithmetic (or profiler counters) shown — not asserted from vibes.

## Step 2 — Compute the speed of light

State the best physically possible time before optimizing, so "fast" has a number:

- Memory-bound: `bytes moved ÷ peak bandwidth`.
- Compute-bound: `ops ÷ peak throughput` — in the *right* units (FMA counts as 2 FLOPs; tensor/matrix cores have their own peak, often 8–16× the vector FMA peak; integer and transcendental ops have theirs).
- Latency/overhead-bound: the floor is filling the machine or amortizing launches, not a bandwidth number — state the parallelism or batching needed instead.

**Done when:** a concrete target (µs/ms, or GB/s / TFLOP/s to sustain) is written down.

## Step 3 — Apply the playbook for that bottleneck

Optimize only against the named ceiling. Consult the matching playbook section below; also sweep the Hazards list, which applies to every kernel.

**Done when:** the kernel is written and every playbook item for the named bottleneck is either applied or explicitly ruled out with a reason.

## Step 4 — Verify against the speed of light

Measure (or, without hardware, estimate from the memory traffic and op counts of the final code) and compare to Step 2. Report the fraction of speed of light achieved.

- ≥ ~80% of the roofline for memory-bound, ≥ ~70% for compute-bound: done.
- Below that: the bottleneck has usually *moved* — return to Step 1 and re-classify; do not keep polishing the old ceiling.
- Always pair the perf claim with a correctness check against a reference implementation (bitwise for integer, tolerance for float).

**Done when:** fraction-of-roofline is reported and the correctness check passes.

---

## Playbook

### Memory-bound — spend every byte once, and spend it wide

- **Coalescing first.** Adjacent lanes in a warp/wavefront must touch adjacent addresses. Prefer SoA over AoS for lane-indexed data; make the fastest-varying index the thread index.
- **Vectorize loads/stores** — 128-bit accesses (`float4`, `@Vector(4, f32)`) cut instruction count and fill the bus.
- **Raise AI with tiling**: stage reused data in shared/workgroup memory or registers (blocked matmul, stencil halos). Reuse is the only way to move right on the roofline.
- **Fuse kernels** that pass intermediates through DRAM; keep data in registers across the fused stages.
- **Route read-only, broadcast data** through constant/read-only caches; avoid strided and random access patterns or restructure the layout (padding, Morton/tiled layouts) so they become sequential.

### Compute-bound — feed the widest pipes

- Use **FMA** everywhere contractions allow; use **tensor/matrix cores** (WMMA/MFMA/cooperative matrix) for anything matmul-shaped — the vector-FMA roofline is not the real roofline if matrix units exist.
- **Lower precision** where the algorithm tolerates it (fp16/bf16/fp8/int8 with fp32 accumulate).
- **ILP:** unroll and keep 2–4 independent accumulators so the FMA pipeline never stalls on a dependent chain.
- **Kill divergence**: sort/compact work so warps take uniform branches; make short branches branchless.
- Use fast-math intrinsics (`__expf`, rsqrt) when tolerance allows; transcendentals run on a narrow SFU pipe.

### Latency-bound — give the machine enough in flight

- **Occupancy is a means, not a score.** Find what caps it (registers per thread, shared memory per block, block size) and buy back only enough occupancy to hide latency — dropping registers to spill point is a loss.
- Add parallelism when the grid is small: **grid-stride loops**, split-K / split-reduction, batching independent problems into one launch.
- **Double-buffer / async copies** (`cp.async`, pipelines) so loads for tile *n+1* overlap compute on tile *n*.
- Break dependent load chains; prefetch by index instead of chasing pointers.

### Overhead-bound — stop paying per-launch and per-transfer taxes

- Fuse or batch tiny kernels; use CUDA/HIP **graphs** or persistent kernels for launch-dominated pipelines.
- Eliminate hidden host↔device syncs (implicit `cudaMemcpy` syncs, per-iteration readbacks); use **pinned memory** and async copies on streams/queues that overlap compute.
- Keep data resident on the GPU across the whole pipeline; transfer once in, once out.

### Hazards — check on every kernel

- **Shared memory bank conflicts**: pad the leading dimension (e.g. `[TILE][TILE+1]`) or swizzle.
- **Atomics contention**: privatize per-block/per-warp, then tree-reduce; never funnel a whole grid into one counter.
- **Register spilling**: watch registers-per-thread; spills turn a compute kernel memory-bound.
- **Misaligned or partial cache-line access**: align structures to the vector width you load.
- **Block size**: multiples of the warp/wavefront size (32/64); 128–256 is the sane default to tune from.

---

## Zig branch

If the kernel is to be written in Zig or built with Zig's GPU targets, read `references/zig-gpu.md` **before writing any code**. The Zig GPU toolchain changes month to month (the file pins the state of master as of mid-2026: `std.spirv`, `@SpirvType`, calling-convention execution modes, build invocations per target) and code written from stale memory of `std.gpu` will not compile. The playbook above still governs the optimization; the reference file only maps it onto Zig.
