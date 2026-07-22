# std.gpu Reference and the Address-Space Model

Synthesized from Zig's `lib/std/gpu.zig` (master). Symbol names and calling conventions are version-sensitive — confirm against the `lib/std/gpu.zig` in your installed toolchain.

## Contents
1. Compute index builtins
2. Graphics-stage builtins (for completeness)
3. Decorations: location and binding
4. ExecutionMode and workgroup size
5. Calling conventions
6. Address spaces and the generic-pointer caveat
7. Worked compute kernel

## 1. Compute index builtins

`std.gpu` exposes the SIMT indices as extern input variables. The three-dimensional ones are `@Vector(3, u32)`; index `[0]`, `[1]`, `[2]` for x, y, z:

- `global_invocation_id` — this invocation's index across the entire dispatch (the usual "which element am I" value).
- `local_invocation_id` — index within the workgroup.
- `workgroup_id` — which workgroup this invocation belongs to.
- `workgroup_size` — the workgroup dimensions.
- `num_workgroups` — number of workgroups in the dispatch.

Equivalent compiler builtins exist (`@workGroupId`, `@workItemId`, `@workGroupSize`); the `std.gpu` extern vars are the convenient, named route. The mapping to CUDA/HIP is direct: `global_invocation_id` ≈ `blockIdx*blockDim + threadIdx`, `local_invocation_id` ≈ `threadIdx`, `workgroup_id` ≈ `blockIdx`, `workgroup_size` ≈ `blockDim`.

## 2. Graphics-stage builtins (for completeness)

For shader (not compute) work, `std.gpu` also provides `position_in`/`position_out` (`@Vector(4, f32)`), `point_size_in`/`point_size_out`, `frag_coord`, `point_coord`, `frag_depth`, `invocation_id`, `vertex_index`, and `instance_index`. Most GPGPU work uses the compute builtins in section 1; these matter only if you are writing vertex/fragment stages.

## 3. Decorations: location and binding

- `gpu.location(comptime ptr, comptime loc: u32)` — emits `OpDecorate Location`, forming linkage for `.input`/`.output` address-space variables (vertex/fragment I/O).
- `gpu.binding(comptime ptr, comptime set: u32, comptime bind: u32)` — emits `OpDecorate DescriptorSet` + `Binding`, how a Vulkan compute kernel reaches its storage buffers. The `set`/`bind` pair must match what the host binds in its descriptor set layout.

Both are implemented as inline SPIR-V `asm volatile` decorations and take comptime arguments.

## 4. ExecutionMode and workgroup size

`gpu.executionMode(comptime entry_point, comptime mode: ExecutionMode)` declares the mode an entry point runs in. The compute-relevant variant is:

```zig
gpu.executionMode(myKernel, .{ .local_size = .{ .x = 64, .y = 1, .z = 1 } });
```

`local_size` requires the entry point to use the `.spirv_kernel` calling convention (the function enforces this at comptime). Other modes (`origin_upper_left`, `depth_replacing`, etc.) require `.spirv_fragment` and are graphics-only. Choose `local_size` the way you choose a CUDA block size: a multiple of the warp/wavefront size, tuned for occupancy (see `gpu-kernel-engineering`).

## 5. Calling conventions

The entry-point calling convention selects the GPU code path:

- `.spirv_kernel` — SPIR-V compute entry point (pairs with `local_size`).
- `.spirv_fragment`, `.spirv_vertex` — SPIR-V graphics stages.
- `.kernel` — the generic GPU kernel convention used when lowering to PTX/AMDGCN.

These tags have shifted across Zig versions (older code used a single `callconv(.kernel)` that lowered per target). Verify the spelling your toolchain expects.

## 6. Address spaces and the generic-pointer caveat

`addrspace(...)` is how you place data in the memory hierarchy. The placement decisions are the same as CUDA/HIP (see the sibling skill's memory table); the Zig spelling:

- `.global` — device-global memory (DRAM/HBM). Large buffers.
- `.shared` — per-workgroup shared memory / LDS. Tiling scratch.
- `.constant` / `.uniform` — read-only broadcast data.
- `.function` / `.local` — per-invocation private memory; the default for ordinary locals.
- `.input` / `.output` — shader-stage I/O linkage.

**The caveat that bites:** ordinary Zig assumes pointers live in the generic address space. Vulkan SPIR-V lacks support for casting into the generic space, so the backend currently assumes unannotated pointers are `.function` (per-invocation local) memory. Practical consequences:

- Always annotate device-buffer pointers with their real address space. An unannotated `[*]f32` parameter is not automatically global memory.
- OpenCL is more permissive (it guarantees the Kernel and Addresses capabilities, so pointer arithmetic and casts work), so the same kernel may compile and run differently between `spirv64-vulkan` and `spirv64-opencl`. Test on the environment you actually ship.

## 7. Worked compute kernel

A vector add over global buffers, Vulkan-style binding:

```zig
const std = @import("std");
const gpu = std.gpu;

export fn vecAdd(
    a: [*]addrspace(.global) const f32,
    b: [*]addrspace(.global) const f32,
    c: [*]addrspace(.global) f32,
) callconv(.spirv_kernel) void {
    const i = gpu.global_invocation_id[0];
    c[i] = a[i] + b[i];
}

comptime {
    gpu.binding(@as(*const anyopaque, @ptrCast(&vecAdd)), 0, 0); // illustrative; bind real buffer vars
    gpu.executionMode(vecAdd, .{ .local_size = .{ .x = 256, .y = 1, .z = 1 } });
}
```

The binding call is illustrative — in real code you decorate the actual buffer variables, matching the host's descriptor set/binding numbers. Keep `a`, `b`, `c` accesses coalesced (consecutive invocations touch consecutive addresses), exactly as the sibling skill prescribes.
