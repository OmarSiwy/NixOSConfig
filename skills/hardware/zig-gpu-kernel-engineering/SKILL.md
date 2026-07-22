---
name: zig-gpu-kernel-engineering
description: Write GPU kernels in Zig using std.gpu and Zig's native GPU backends (SPIR-V for Vulkan and OpenCL, NVPTX for CUDA, AMDGCN for AMD), plus the pragmatic C-interop path that calls existing CUDA or HIP from Zig. Use when the user writes, ports, reviews, or builds GPU code in Zig; mentions std.gpu, addrspace, callconv(.kernel) or callconv(.spirv_kernel), workgroup_id, global_invocation_id, executionMode or local_size, the spirv32/spirv64/nvptx64/amdgcn targets, zig build-obj -ofmt=spirv, or wraps CUDA/HIP via @cImport or the cudaz library. This is the Zig sibling of gpu-kernel-engineering, which it relies on for the hardware-level reasoning (memory hierarchy, coalescing, occupancy, warps and wavefronts) that is identical across languages.
---

# Zig GPU Kernel Engineering

Zig can emit GPU code directly — no CUDA/HIP toolchain required — by compiling to **SPIR-V** (Vulkan, OpenCL), **NVPTX** (CUDA), or **AMDGCN** (AMD). The `std.gpu` module supplies the kernel-side builtins and decorations.

**The hardware does not change because the language did.** Memory placement, coalescing, shared-memory bank conflicts, occupancy, and warp/wavefront behavior work exactly as in the `gpu-kernel-engineering` skill. Read that skill for the *why* of any performance decision. This skill covers only *how to express it in Zig*. Do not re-derive the hardware model here; defer to the sibling.

**Maturity caveat.** Zig's native GPU support is experimental and moves fast. Calling-convention tags, target triples, `-mcpu` feature names, and the exact `std.gpu` symbols change between Zig versions. Before relying on any specific spelling below, confirm it against the installed toolchain: run `zig version` and read `lib/std/gpu.zig` in that toolchain. Treat this skill's API names as a starting point to verify, not gospel.

## Step 1 — Pick the path

Two honest options; choose deliberately.

1. **Native Zig kernels** — write the kernel in Zig, compile to SPIR-V / PTX / AMDGCN. Best when you want a single language and no vendor C toolchain. The tradeoff is maturity: the SPIR-V backend passes roughly half of Zig's behavior tests under baseline Vulkan and more under OpenCL, so expect rough edges and validate aggressively.
2. **C-interop** — keep proven CUDA/HIP kernels (or libraries like cuBLAS), and use Zig only for the host side via `@cImport`, or use the `cudaz` library for grid/block/thread launches. Best when you need mature kernels *now* and want Zig's build system and ergonomics around them. See `references/c-interop.md`.

Mixing is fine: native Zig for new kernels, C-interop for the parts that must be fast and proven today.

## Step 2 — Write the kernel (native path)

A kernel is just an exported function with a kernel calling convention, compiled freestanding (no libc).

```zig
const gpu = @import("std").gpu;

export fn addOne(in: [*]addrspace(.global) const f32,
                 out: [*]addrspace(.global) f32) callconv(.spirv_kernel) void {
    const i = gpu.global_invocation_id[0]; // x index across the whole grid
    out[i] = in[i] + 1.0;
}

comptime {
    // Set the workgroup (block) size for this entry point.
    gpu.executionMode(addOne, .{ .local_size = .{ .x = 64, .y = 1, .z = 1 } });
}
```

Key pieces, all from `std.gpu` (full list in `references/std-gpu-reference.md`):

- **Thread/grid indices** are extern input variables, each a `@Vector(3, u32)`:
  `global_invocation_id`, `local_invocation_id`, `workgroup_id`, `workgroup_size`, `num_workgroups`. Index `[0]/[1]/[2]` for x/y/z. (Builtins `@workGroupId`, `@workItemId`, `@workGroupSize` also exist.)
- **Calling convention** marks the entry point: `callconv(.spirv_kernel)` for SPIR-V compute, `callconv(.kernel)` for PTX/AMDGCN. (Graphics stages use `.spirv_fragment` / `.spirv_vertex`.) Verify the exact tag for your Zig version.
- **Workgroup size** is declared with `gpu.executionMode(entry, .{ .local_size = .{ .x, .y, .z } })`.
- **Buffer bindings** (Vulkan): `gpu.binding(ptr, set, bind)`; vertex/fragment I/O linkage: `gpu.location(ptr, loc)`.

## Step 3 — Memory placement IS address spaces

In Zig, you place data on the GPU by annotating pointers with `addrspace(...)`. This is the direct analog of CUDA/HIP memory spaces — so use the placement *decisions* from `gpu-kernel-engineering`'s memory table, and just spell them in Zig:

| Hardware space (sibling skill) | Zig `addrspace` | Notes |
|---|---|---|
| Global DRAM / HBM | `.global` | Large device buffers; keep access coalesced. |
| Shared memory / LDS | `.shared` | Per-workgroup scratch; the basis of tiling. Pad to avoid bank conflicts. |
| Constant / uniform | `.constant` (or `.uniform`) | Read-only broadcast data. |
| Registers / per-thread | `.function` / `.local` (default for locals) | Plain locals; watch register pressure and spills. |
| Shader I/O | `.input` / `.output` | Graphics-stage linkage via `gpu.location`. |

**The single biggest Zig-specific gotcha: the generic address space.** Most Zig code assumes pointers are generic, but Vulkan SPIR-V does not support casting to the generic space (`OpPtrCastToGeneric`), so the backend currently treats unannotated pointers as `.function` (per-thread local) memory. If you mean global or shared memory, you **must** annotate the pointer's address space explicitly, or your data silently lands in the wrong place. OpenCL is more permissive (it guarantees the Kernel and Addresses capabilities, allowing pointer arithmetic and casts), so the same source can behave differently across SPIR-V environments. Details in `references/std-gpu-reference.md`.

## Step 4 — Build for the target

The self-hosted SPIR-V backend uses `-fno-llvm`; PTX and AMDGCN go through LLVM. Substitute your GPU model for `<gpu-model>`.

```bash
# SPIR-V (Vulkan)
zig build-obj -target spirv64-vulkan-none -mcpu vulkan_v1_2+int64 -ofmt=spirv -fno-llvm kernel.zig
# SPIR-V (OpenCL)
zig build-obj -target spirv64-opencl-none -mcpu opencl_v2+int64 -ofmt=spirv -fno-llvm kernel.zig
# NVPTX (CUDA)
zig build-lib -dynamic -target nvptx64-cuda-none -mcpu <gpu-model> -femit-asm -fno-emit-bin -fno-ubsan-rt kernel.zig
# AMDGCN (AMD)
zig build-lib -dynamic -target amdgcn-amdhsa-none -mcpu <gpu-model> -fno-compiler-rt kernel.zig
```

SPIR-V `.spv` modules are self-contained — no separate link step. Full explanation of targets, features, and which host runtime consumes each artifact is in `references/targets-and-build.md`.

## Step 5 — Run it from the host

The compiled kernel still needs a host program to launch it:
- **SPIR-V** → consumed by Vulkan (`vkCreateShaderModule`) or OpenCL (`clCreateProgramWithIL`), or WebGPU.
- **PTX** → loaded via the CUDA Driver API (`cuModuleLoadData` / `cuLaunchKernel`) or the `cudaz` library.
- **AMDGCN** → loaded via the HIP/HSA runtime.

You can write that host code in Zig too, importing the runtime headers with `@cImport`. See `references/c-interop.md`.

## Review checklist (Zig specifics)

- Is every device pointer's `addrspace` annotated, so nothing falls back to `.function` by accident?
- Does the entry point use the right kernel calling convention for the target, and is the workgroup size set via `executionMode`?
- For Vulkan, have you avoided generic-address-space casts the backend cannot lower?
- Did you validate the SPIR-V (`spirv-val`) and check numerics against a CPU reference on the actual target?
- For the hardware-level review (coalescing, bank conflicts, occupancy, warp/wavefront size), run the checklist in `gpu-kernel-engineering` — it applies unchanged.

## Reference files

- `references/std-gpu-reference.md` — The `std.gpu` symbols (index builtins, `location`, `binding`, `ExecutionMode`), calling conventions, the address-space model and the Vulkan generic-pointer caveat, with a worked compute kernel.
- `references/targets-and-build.md` — The four target triples, `-mcpu`/feature flags, self-hosted SPIR-V vs LLVM backends, output formats, and which host runtime consumes each artifact.
- `references/c-interop.md` — Calling CUDA/HIP from Zig via `@cImport`, `build.zig` integration, compiling `.cu` with nvcc alongside Zig, and the `cudaz` library.
