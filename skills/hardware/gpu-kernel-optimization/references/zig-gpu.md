# GPU Programming in Zig — state of master, mid-2026

Status snapshot of Zig master (post-0.16, heading to 0.17). Zig's GPU support moves fast and broke API twice in the last year, so **verify identifiers against the installed compiler's `lib/std/spirv.zig` and langref before shipping** — treat this file as the map, not the territory. Zig development now lives on Codeberg (`codeberg.org/ziglang/zig`); file GPU bugs there.

## Current status (June 2026 devlog, "SPIR-V Backend Progress")

- The self-hosted **SPIR-V backend** is usable for real shaders and compute kernels: ~49% of Zig behavior tests pass on `spirv64-vulkan`, ~75% on the OpenCL target. Many remaining failures are tests that don't make sense on a GPU anyway. Expect rough edges; validate everything.
- **`std.gpu` was renamed to `std.spirv`.** Any code or tutorial using `std.gpu` is stale.
- **`@SpirvType` builtin** (merged June 2026) expresses SPIR-V-only types: `.sampler`, `.image`, `.sampled_image`, `.runtime_array`. This unblocked textures/UBOs that previously needed inline assembly.
- **Execution modes moved to the calling convention.** Workgroup size, fragment depth assumptions, mesh limits, etc. are declared in `callconv(...)`. `std.gpu.executionMode()` is gone and the assembler now *rejects* manual `OpExecutionMode`, `OpCapability`, and `OpExtension` — capabilities are derived from the `-mcpu` feature set instead.
- New `spirv_task` and `spirv_mesh` calling conventions for mesh shading.
- `.spv` files are now object files: compile multiple `.zig` files (or foreign `.spv` objects) and the SPIR-V linker stitches them into one module.
- SPIR-V codegen is now multi-threaded, with `dedup_types` and `prune_unused` passes back.

## Four routes to the GPU

| Route | Target triple | Backend | Consumed by |
|---|---|---|---|
| Vulkan compute/graphics | `spirv64-vulkan-none` | self-hosted (`-fno-llvm`) | Vulkan (`vkCreateShaderModule`) |
| OpenCL kernels | `spirv64-opencl-none` | self-hosted (`-fno-llvm`) | OpenCL 2.x+ / clspv-style runtimes |
| NVIDIA native | `nvptx64-cuda-none` | LLVM → PTX | CUDA driver API (`cuModuleLoadData`) |
| AMD native | `amdgcn-amdhsa-none` | LLVM → code object | HIP/HSA (`hipModuleLoad`) |

Build invocations:

```sh
# SPIR-V for Vulkan (feature flags drive OpCapability):
zig build-obj -target spirv64-vulkan-none -mcpu vulkan_v1_2+int64 \
  -ofmt=spirv -fno-llvm -O ReleaseFast kernel.zig

# SPIR-V for OpenCL (Kernel+Addresses capabilities: pointer arithmetic allowed):
zig build-obj -target spirv64-opencl-none -mcpu opencl_v2+int64 \
  -ofmt=spirv -fno-llvm -O ReleaseFast kernel.zig

# PTX for NVIDIA (pick the real SM, e.g. sm_86):
zig build-lib -dynamic -target nvptx64-cuda-none -mcpu sm_86 \
  -femit-asm -fno-emit-bin -fno-ubsan-rt -O ReleaseFast kernel.zig

# AMDGCN code object (pick the real arch, e.g. gfx1100):
zig build-lib -dynamic -target amdgcn-amdhsa-none -mcpu gfx1100 \
  -fno-compiler-rt -O ReleaseFast kernel.zig
```

Always `-O ReleaseFast` (or ReleaseSmall) for anything you benchmark; Debug GPU code is not a baseline.

## Entry points and execution modes

Kernel entry points are `export fn` with a GPU calling convention. On SPIR-V the workgroup size lives **in the callconv**:

```zig
// Compute kernel, 8×8×1 workgroup:
export fn comp() callconv(.{ .spirv_kernel = .{ .x = 8, .y = 8, .z = 1 } }) void {}

// Graphics stages:
export fn vert() callconv(.spirv_vertex) void {}
export fn frag() callconv(.{ .spirv_fragment = .{ .depth_assumption = .greater } }) void {}

// Mesh shading:
export fn task() callconv(.{ .spirv_task = .{ .x = 1, .y = 1, .z = 1 } }) void {}
export fn mesh() callconv(.{ .spirv_mesh = .{
    .stage_output = .output_lines, .max_primitives = 1, .max_vertices = 2,
} }) void {}
```

On the LLVM routes (PTX/AMDGCN), kernels use `callconv(.kernel)`, and thread indices come from builtins: `@workItemId(dim)`, `@workGroupId(dim)`, `@workGroupSize(dim)` (verify names in the installed langref).

## Address spaces = the memory hierarchy

`addrspace` is how the playbook's memory hierarchy is spelled in Zig. This is the core of writing non-bottlenecked kernels here:

| Zig addrspace | Meaning | Playbook role |
|---|---|---|
| `.global` | device DRAM | the bandwidth ceiling; coalesce and vectorize accesses |
| `.shared` | workgroup/LDS memory | tiling target; watch bank conflicts |
| `.constant` | uniform/read-only | broadcast data, descriptors |
| `.input` / `.output` | shader interface | vertex/fragment IO, builtins |
| `.local` / function-local | registers (until spilled) | accumulators, ILP |

Vulkan caveat: SPIR-V for Vulkan has **no generic address space** (`OpPtrCastToGeneric` is unsupported), so pointers must carry the right `addrspace` explicitly and unannotated pointers are treated as function-local; generic-pointer-style Zig code that compiles fine for OpenCL will not fly on the Vulkan target. OpenCL guarantees the `Kernel` and `Addresses` capabilities, so pointer arithmetic and casts work there.

## Bindings, buffers, and SPIR-V-only types

Resources are declared with `@extern` plus a decoration; opaque GPU types come from `@SpirvType`:

```zig
const Image = @SpirvType(.{ .image = .{
    .usage = .{ .sampled = u32 },
    .format = .unknown,
    .dim = .@"2d",
    .depth = .unknown,
    .arrayed = false,
    .multisampled = false,
    .access = .unknown,
} });
const SampledImage = @SpirvType(.{ .sampled_image = Image });
const Floats = @SpirvType(.{ .runtime_array = f32 }); // has indexing and .len

const sampled_image = @extern(*addrspace(.constant) const SampledImage, .{
    .name = "sampled_image",
    .decoration = .{ .descriptor = .{ .set = 0, .binding = 1 } },
});
```

Invocation-ID builtins (global/local invocation id, workgroup id, etc.) live in `std.spirv` as extern input globals — read `lib/std/spirv.zig` in the exact compiler in use for the current names, since this module was renamed and reshuffled recently.

## What does NOT work on the GPU targets

- Effectively **freestanding**: no allocator, no `std.Io`, no OS. Kernels are pure functions over buffers. Design host-side; the kernel only computes.
- No recursion, and comptime is your friend for specialization (tile sizes, unroll factors as `comptime` parameters — this replaces C++ templates in CUDA-style tuning).
- Error unions, panics, and safety checks are limited/absent on GPU; build ReleaseFast and validate on the host.
- Half the behavior-test surface still fails on `spirv64-vulkan` — if the compiler crashes or emits invalid SPIR-V, minimize and report on Codeberg rather than fighting it.

## Host side

Zig compiles the kernel; a runtime must launch it:

- **Vulkan**: `vulkan-zig` (Snektron) — create a compute pipeline from the emitted `.spv`.
- **OpenCL**: `opencl-zig` (Snektron) — idiomatic bindings, Zig errors/allocators; loads SPIR-V via `clCreateProgramWithIL`.
- **CUDA**: link `libcuda` and use the driver API — `cuModuleLoadData` on the emitted PTX, `cuLaunchKernel`.
- **HIP/HSA**: `hipModuleLoad` on the amdgcn code object.
- Reference end-to-end project: `snektron/shallenge` (Zig kernels + host). For a large production-scale example of Zig→SPIR-V compute (LLM inference on Vulkan), see `zolotukhin/zinc`.

## Verification loop (do this every time)

1. `spirv-val kernel.spv` — must pass; Zig-generated modules occasionally don't, which is a compiler bug to report, not to ship.
2. `spirv-dis kernel.spv` — eyeball the storage classes and workgroup size; confirm loads from `.global` are what you intended (this is how you catch accidental function-local copies killing coalescing).
3. For PTX: read the emitted `.s` — check for `ld.global.v4` (vectorized loads happened), register count, and absence of `local` spills.
4. Then apply SKILL.md Step 4: measure against the speed of light.

## Mapping the playbook to Zig

- Coalescing/vectorized loads → index buffers by invocation id with unit stride; load `@Vector(4, f32)` from `.global` pointers.
- Tiling → `var tile: [TY][TX + 1]f32 addrspace(.shared)` declared at global scope (shared memory is module-level, not stack); the `+1` pads away bank conflicts.
- ILP → `inline for` unrolling with multiple accumulator variables.
- Specialization → `comptime` tile/unroll parameters; generate one entry point per configuration and pick host-side.
- Workgroup sizing → the `.spirv_kernel = .{ .x, .y, .z }` callconv (SPIR-V) or launch config (PTX/HIP); keep x a multiple of 32 (NVIDIA) / 64 (AMD wavefront).
- Tensor cores → not exposed through Zig builtins yet on the SPIR-V route; on Vulkan you'd need cooperative-matrix, which is not yet reachable — if the kernel is matmul-shaped and compute-bound, say so and flag that a Zig kernel will cap at the vector-FMA roofline today.
